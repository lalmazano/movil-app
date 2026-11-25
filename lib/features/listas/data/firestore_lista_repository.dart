import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/config_club.dart';
import 'datos_iniciales.dart';
import '../domain/item_lista.dart';

/// Guarda las listas en Cloud Firestore:
/// `clubs/{clubId}/{peliculas|deseos|planes}/{itemId}`.
///
/// Firestore guarda una copia local, así que la app funciona sin internet y
/// sincroniza los cambios cuando vuelve la conexión.
class FirestoreListaRepository implements ListaRepository {
  FirestoreListaRepository(
    this._db, {
    required this.clubId,
    Autor? Function()? autor,
  }) : _autor = autor ?? (() => null);

  final FirebaseFirestore _db;
  final String clubId;
  final Autor? Function() _autor;

  @override
  Autor? get autorActual => _autor();

  /// Convierte los Timestamp (también anidados) a DateTime.
  static Object? _fechas(Object? v) => switch (v) {
    Timestamp t => t.toDate(),
    Map m => {for (final e in m.entries) '${e.key}': _fechas(e.value)},
    List l => [for (final e in l) _fechas(e)],
    _ => v,
  };

  static ItemLista _item(DocumentSnapshot<Map<String, dynamic>> doc) =>
      ItemLista.fromMap(
        doc.id,
        (_fechas(doc.data() ?? const {}) as Map).cast<String, Object?>(),
      );

  CollectionReference<Map<String, dynamic>> _col(TipoLista tipo) =>
      _db.collection('clubs').doc(clubId).collection(tipo.coleccion);

  @override
  bool get enLaNube => true;

  @override
  Future<void> inicializar() async {
    final errores = <String>[];

    // 1. Configuración: crea el documento o solo las banderas que falten,
    //    todas en true. Nunca cambia las que ya existen.
    final config = _db.collection('config').doc('app');
    try {
      await _db.runTransaction((tx) async {
        final actual = await tx.get(config);
        final faltantes = {
          for (final b in ConfigClub.banderas)
            if (!(actual.data()?.containsKey(b) ?? false)) b: true,
        };
        if (faltantes.isEmpty) return;
        if (actual.exists) {
          tx.update(config, faltantes);
        } else {
          tx.set(config, faltantes);
        }
      });
    } catch (e) {
      errores.add('config/app: ${_mensaje(e)}');
    }

    // 2. Categorías de cada lista (si no existen), con las de la app.
    for (final tipo in TipoLista.values) {
      final ref = _categorias(tipo);
      try {
        await _db.runTransaction((tx) async {
          if ((await tx.get(ref)).exists) return;
          tx.set(ref, {'nombres': tipo.categorias});
        });
      } catch (e) {
        errores.add('categorias/${tipo.coleccion}: ${_mensaje(e)}');
      }
    }

    // 3. Club + datos iniciales, todo junto: o se crea todo o nada, y solo
    //    un teléfono lo hace aunque entren los dos a la vez.
    final club = _db.collection('clubs').doc(clubId);
    try {
      await _db.runTransaction((tx) async {
        if ((await tx.get(club)).exists) return;
        tx.set(club, {
          'nombre': 'El Club del Frijol',
          'creadoEn': FieldValue.serverTimestamp(),
        });
        final base = DateTime.now().millisecondsSinceEpoch;
        var i = 0;
        for (final MapEntry(key: tipo, value: items)
            in datosIniciales.entries) {
          for (final item in items) {
            tx.set(_col(tipo).doc(), {
              ..._nuevo(item),
              // Orden estable: cada elemento 1 ms después del anterior.
              'creadoEn': Timestamp.fromMillisecondsSinceEpoch(base + i++),
            });
          }
        }
      });
    } catch (e) {
      errores.add('clubs/$clubId: ${_mensaje(e)}');
    }

    if (errores.isNotEmpty) throw InicializacionException(errores);
  }

  static String _mensaje(Object e) =>
      e is FirebaseException ? '${e.code} — ${e.message}' : '$e';

  DocumentReference<Map<String, dynamic>> _categorias(TipoLista tipo) =>
      _db.collection('categorias').doc(tipo.coleccion);

  @override
  Stream<List<String>> watchCategorias(TipoLista tipo) =>
      _categorias(tipo).snapshots().map((doc) {
        final nombres = [
          for (final n in (doc.data()?['nombres'] as List?) ?? const [])
            if (n is String && n.trim().isNotEmpty) n.trim(),
        ];
        return nombres.isEmpty ? tipo.categorias : nombres;
      });

  @override
  Stream<ConfigClub> watchConfig() => _db
      .collection('config')
      .doc('app')
      .snapshots()
      .map(
        (doc) => ConfigClub.fromMap(
          (_fechas(doc.data()) as Map?)?.cast<String, Object?>(),
        ),
      );

  @override
  Stream<List<ItemLista>> watch(TipoLista tipo) =>
      _col(tipo)
          .orderBy('creadoEn')
          .snapshots()
          .map((snap) => [for (final doc in snap.docs) _item(doc)]);

  Map<String, Object?> _nuevo(NuevoItem item, {InfoPelicula? pelicula}) => {
    'titulo': item.titulo,
    'categoria': item.categoria,
    'nota': item.nota,
    'hecho': false,
    'creadoEn': FieldValue.serverTimestamp(),
    'hechoEn': null,
    'creadoPor': ?_autor()?.toMap(),
    'pelicula': ?pelicula?.toMap(),
  };

  @override
  Future<void> add(TipoLista tipo, NuevoItem item, {InfoPelicula? pelicula}) =>
      _col(tipo).add(_nuevo(item, pelicula: pelicula));

  @override
  Future<void> addMany(TipoLista tipo, List<NuevoItem> items) async {
    // Un lote de Firestore admite hasta 500 escrituras.
    for (var i = 0; i < items.length; i += 450) {
      final lote = _db.batch();
      for (final item in items.skip(i).take(450)) {
        lote.set(_col(tipo).doc(), _nuevo(item));
      }
      await lote.commit();
    }
  }

  @override
  Future<void> update(TipoLista tipo, ItemLista item) => _col(tipo)
      .doc(item.id)
      .update({
        'titulo': item.titulo,
        'categoria': item.categoria,
        'nota': item.nota,
        'pelicula': item.pelicula?.toMap(),
      });

  @override
  Future<void> setHecho(TipoLista tipo, String id, bool hecho) =>
      _col(tipo).doc(id).update({
        'hecho': hecho,
        'hechoEn': hecho ? FieldValue.serverTimestamp() : null,
        'hechoPor': hecho ? _autor()?.toMap() : null,
      });

  @override
  Future<void> calificar(
    TipoLista tipo,
    String id,
    Calificacion calificacion,
  ) => _col(tipo).doc(id).update({
    'calificaciones.${calificacion.autor.uid}': {
      ...calificacion.toMap(),
      'fecha': FieldValue.serverTimestamp(),
    },
  });

  @override
  Future<void> delete(TipoLista tipo, String id) async {
    final ref = _col(tipo).doc(id);
    final fotos = await ref.collection('fotos').get();
    final lote = _db.batch();
    for (final f in fotos.docs) {
      lote.delete(f.reference);
    }
    lote.delete(ref);
    await lote.commit();
  }

  @override
  Stream<ItemLista?> watchItem(TipoLista tipo, String id) =>
      _col(tipo)
          .doc(id)
          .snapshots()
          .map((doc) => doc.exists ? _item(doc) : null);

  @override
  Stream<List<FotoItem>> watchFotos(TipoLista tipo, String id) =>
      _col(tipo)
          .doc(id)
          .collection('fotos')
          .orderBy('creadoEn')
          .snapshots()
          .map(
            (snap) => [
              for (final doc in snap.docs)
                if (doc.data()['datos'] case final Blob datos)
                  FotoItem(
                    id: doc.id,
                    bytes: datos.bytes,
                    creadoEn:
                        (doc.data()['creadoEn'] as Timestamp?)?.toDate() ??
                        DateTime.now(),
                    autor: Autor.fromMap(doc.data()['autor']),
                  ),
            ],
          );

  @override
  Future<void> agregarFoto(TipoLista tipo, String id, Uint8List bytes) {
    if (bytes.length > maxBytesFoto) {
      throw ArgumentError('La foto pesa más de $maxBytesFoto bytes');
    }
    final ref = _col(tipo).doc(id);
    return (_db.batch()
          ..set(ref.collection('fotos').doc(), {
            'datos': Blob(bytes),
            'creadoEn': FieldValue.serverTimestamp(),
            'autor': ?_autor()?.toMap(),
          })
          ..update(ref, {'fotos': FieldValue.increment(1)}))
        .commit();
  }

  @override
  Future<void> borrarFoto(TipoLista tipo, String id, String fotoId) {
    final ref = _col(tipo).doc(id);
    return (_db.batch()
          ..delete(ref.collection('fotos').doc(fotoId))
          ..update(ref, {'fotos': FieldValue.increment(-1)}))
        .commit();
  }

  @override
  Future<String?> tmdbApiKey() async {
    final doc = await _db.collection('config').doc('tmdb').get();
    final key = doc.data()?['apiKey'];
    return key is String && key.trim().isNotEmpty ? key.trim() : null;
  }
}

/// No se pudo crear parte de la estructura inicial del club.
class InicializacionException implements Exception {
  const InicializacionException(this.errores);

  final List<String> errores;

  @override
  String toString() => errores.join('\n');
}
