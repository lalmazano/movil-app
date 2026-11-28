import 'package:cloud_firestore/cloud_firestore.dart';

import '../../listas/domain/detalles.dart';
import '../domain/musica_repository.dart';

class FirestoreMusicaRepository implements MusicaRepository {
  FirestoreMusicaRepository(
    this.db, {
    required this.clubId,
    required this.autor,
  });

  final FirebaseFirestore db;
  final String clubId;
  final Autor? Function() autor;

  DocumentReference<Map<String, dynamic>> get _club =>
      db.collection('clubs').doc(clubId);

  @override
  Autor? get autorActual => autor();

  static DateTime? _fecha(Object? v) => v is Timestamp ? v.toDate() : null;

  @override
  Stream<List<CancionPlaylist>> watchPlaylist() =>
      _club.collection('playlist').snapshots().map((snap) {
        final lista = [
          for (final d in snap.docs)
            if (Cancion.fromMap(d.data()['cancion']) case final c?)
              CancionPlaylist(
                id: d.id,
                cancion: c,
                agregadaEn: _fecha(d.data()['agregadaEn']) ?? DateTime.now(),
                agregadaPor: Autor.fromMap(d.data()['agregadaPor']),
                corazones: {
                  for (final MapEntry(:key, :value)
                      in ((d.data()['corazones'] as Map?) ?? const {}).entries)
                    if (value == true) '$key',
                },
              ),
        ]..sort((a, b) => b.agregadaEn.compareTo(a.agregadaEn));
        return lista;
      });

  @override
  Future<bool> agregar(Cancion cancion) async {
    final yo = autor();
    if (yo == null) throw StateError('Inicia sesión para agregar canciones.');
    // La misma canción pudo encontrarse en el otro catálogo.
    final actuales = await _club.collection('playlist').get();
    if (actuales.docs.any(
      (d) => Cancion.fromMap(d.data()['cancion'])?.huella == cancion.huella,
    )) {
      return false;
    }
    final ref = _club.collection('playlist').doc(cancion.clave);
    return db.runTransaction((tx) async {
      if ((await tx.get(ref)).exists) return false;
      tx.set(ref, {
        'cancion': cancion.toMap(),
        'agregadaPor': yo.toMap(),
        'agregadaEn': FieldValue.serverTimestamp(),
        'corazones': <String, bool>{},
      });
      return true;
    });
  }

  @override
  Future<void> quitar(String id) =>
      _club.collection('playlist').doc(id).delete();

  @override
  Future<void> alternarCorazon(String id) async {
    final yo = autor();
    if (yo == null) return;
    final ref = _club.collection('playlist').doc(id);
    await db.runTransaction((tx) async {
      final doc = await tx.get(ref);
      final tiene = (doc.data()?['corazones'] as Map?)?[yo.uid] == true;
      tx.update(ref, {
        'corazones.${yo.uid}': tiene ? FieldValue.delete() : true,
      });
    });
  }

  @override
  Stream<List<RecordAdivina>> watchRecords() => _club
      .collection('adivina')
      .snapshots()
      .map(
        (snap) => [
          for (final d in snap.docs)
            if (Autor.fromMap(d.data()['autor']) case final a?)
              RecordAdivina(
                autor: a,
                mejor: (d.data()['mejor'] as num?)?.toInt() ?? 0,
                partidas: (d.data()['partidas'] as num?)?.toInt() ?? 0,
                ultimaEn: _fecha(d.data()['ultimaEn']),
              ),
        ]..sort((a, b) => b.mejor.compareTo(a.mejor)),
      );

  @override
  Future<void> guardarPartida(int aciertos) async {
    final yo = autor();
    if (yo == null) return;
    final ref = _club.collection('adivina').doc(yo.uid);
    await db.runTransaction((tx) async {
      final doc = await tx.get(ref);
      final mejor = (doc.data()?['mejor'] as num?)?.toInt() ?? 0;
      final partidas = (doc.data()?['partidas'] as num?)?.toInt() ?? 0;
      tx.set(ref, {
        'autor': yo.toMap(),
        'mejor': aciertos > mejor ? aciertos : mejor,
        'partidas': partidas + 1,
        'ultimaEn': FieldValue.serverTimestamp(),
      });
    });
  }
}
