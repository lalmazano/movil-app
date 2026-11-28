import 'package:cloud_firestore/cloud_firestore.dart';

import '../../listas/domain/detalles.dart';
import '../domain/preguntas_repository.dart';

/// Preguntas en Firestore: `clubs/{clubId}/preguntas`.
class FirestorePreguntasRepository implements PreguntasRepository {
  FirestorePreguntasRepository(
    this.db, {
    required this.clubId,
    required this.autor,
  });

  final FirebaseFirestore db;
  final String clubId;

  /// Quién usa la app (null antes de iniciar sesión).
  final Autor? Function() autor;
}
