import 'package:cloud_firestore/cloud_firestore.dart';

import '../../listas/domain/detalles.dart';
import '../domain/fechas_repository.dart';

/// Fechas en Firestore: `clubs/{clubId}/fechas`.
///
/// Cada documento: `titulo`, `fecha` (timestamp), `anual`, `emoji`,
/// `contarAnios` y `creadaPor` {uid, nombre, foto}.
class FirestoreFechasRepository implements FechasRepository {
  FirestoreFechasRepository(
    this.db, {
    required this.clubId,
    required this.autor,
  });

  final FirebaseFirestore db;
  final String clubId;

  /// Quién usa la app (null antes de iniciar sesión).
  final Autor? Function() autor;

  CollectionReference<Map<String, dynamic>> get _col =>
      db.collection('clubs').doc(clubId).collection('fechas');

  static Object? _convertir(Object? v) => switch (v) {
    Timestamp t => t.toDate(),
    Map m => {for (final e in m.entries) '${e.key}': _convertir(e.value)},
    _ => v,
  };

  @override
  DateTime hoy() => DateTime.now();

  @override
  Stream<List<FechaImportante>> watch() => _col.snapshots().map(
    (snap) => ordenarPorCercania([
      for (final doc in snap.docs)
        FechaImportante.fromMap(
          doc.id,
          (_convertir(doc.data()) as Map).cast<String, Object?>(),
        ),
    ], hoy()),
  );

  @override
  Future<void> add(NuevaFecha fecha) =>
      _col.add({...fecha.toMap(), 'creadaPor': ?autor()?.toMap()});

  @override
  Future<void> update(String id, NuevaFecha fecha) =>
      _col.doc(id).update(fecha.toMap());

  @override
  Future<void> delete(String id) => _col.doc(id).delete();
}
