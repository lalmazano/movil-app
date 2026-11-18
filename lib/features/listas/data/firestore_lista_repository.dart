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
    final config = _db.collection('config').doc('app');
    final club = _db.collection('clubs').doc(clubId);
    // La transacción garantiza que solo un teléfono crea los datos iniciales.
    final clubNuevo = await _db.runTransaction((tx) async {
      final configSnap = await tx.get(config);
      final clubSnap = await tx.get(club);
      if (!configSnap.exists) {
        tx.set(config, {
          'peliculas': true,
          'deseos': true,
          'planes': true,
          'registroAbierto': true,
        });
      }
      if (clubSnap.exists) return false;
      tx.set(club, {
        'nombre': 'El Club del Frijol',
        'creadoEn': FieldValue.serverTimestamp(),
      });
      return true;
    });
    if (!clubNuevo) return;

    final lote = _db.batch();
    final base = DateTime.now().millisecondsSinceEpoch;
    var i = 0;
    for (final MapEntry(key: tipo, value: items) in datosIniciales.entries) {
      for (final item in items) {
        lote.set(_col(tipo).doc(), {
          ..._nuevo(item),
          // Orden estable: cada elemento un milisegundo después del anterior.
          'creadoEn': Timestamp.fromMillisecondsSinceEpoch(base + i++),
        });
      }
    }
    await lote.commit();
  }

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
