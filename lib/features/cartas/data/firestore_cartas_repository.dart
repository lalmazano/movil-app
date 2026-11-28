import 'package:cloud_firestore/cloud_firestore.dart';

import '../../listas/domain/detalles.dart';
import '../domain/cartas_repository.dart';

/// Cartas en Firestore: `clubs/{clubId}/cartas`.
class FirestoreCartasRepository implements CartasRepository {
  FirestoreCartasRepository(
    this.db, {
    required this.clubId,
    required this.autor,
  });

  final FirebaseFirestore db;
  final String clubId;

  /// Quién usa la app (null antes de iniciar sesión).
  final Autor? Function() autor;
}
