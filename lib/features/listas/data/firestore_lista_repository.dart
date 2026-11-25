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
  FirestoreListaRepository(this._db, {required this.clubId});

  final FirebaseFirestore _db;
  final String clubId;

  CollectionReference<Map<String, dynamic>> _col(TipoLista tipo) =>
      _db.collection('clubs').doc(clubId).collection(tipo.coleccion);

  @override
  bool get enLaNube => true;

  @override
  Future<void> inicializar() async {
    final errores = <String>[];

    // 1. Configuración por defecto (si no existe).
    final config = _db.collection('config').doc('app');
    try {
      await _db.runTransaction((tx) async {
        if ((await tx.get(config)).exists) return;
        tx.set(config, {
          'peliculas': true,
          'deseos': true,
          'planes': true,
          'registroAbierto': true,
        });
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
      .map((doc) => ConfigClub.fromMap(doc.data()));

  @override
  Stream<List<ItemLista>> watch(TipoLista tipo) =>
      _col(tipo)
          .orderBy('creadoEn')
          .snapshots()
          .map(
            (snap) => [
              for (final doc in snap.docs)
                ItemLista.fromMap(doc.id, {
                  for (final e in doc.data().entries)
                    e.key: e.value is Timestamp
                        ? (e.value as Timestamp).toDate()
                        : e.value,
                }),
            ],
          );

  Map<String, Object?> _nuevo(NuevoItem item) => {
    'titulo': item.titulo,
    'categoria': item.categoria,
    'nota': item.nota,
    'hecho': false,
    'creadoEn': FieldValue.serverTimestamp(),
    'hechoEn': null,
  };

  @override
  Future<void> add(TipoLista tipo, NuevoItem item) =>
      _col(tipo).add(_nuevo(item));

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
      });

  @override
  Future<void> setHecho(TipoLista tipo, String id, bool hecho) => _col(tipo)
      .doc(id)
      .update({
        'hecho': hecho,
        'hechoEn': hecho ? FieldValue.serverTimestamp() : null,
      });

  @override
  Future<void> delete(TipoLista tipo, String id) => _col(tipo).doc(id).delete();
}

/// No se pudo crear parte de la estructura inicial del club.
class InicializacionException implements Exception {
  const InicializacionException(this.errores);

  final List<String> errores;

  @override
  String toString() => errores.join('\n');
}
