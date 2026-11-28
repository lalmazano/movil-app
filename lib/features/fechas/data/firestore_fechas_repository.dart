import 'package:cloud_firestore/cloud_firestore.dart';

import '../../listas/domain/detalles.dart';
import '../domain/fechas_repository.dart';

/// Fechas en Firestore: `clubs/{clubId}/fechas`.
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
}
