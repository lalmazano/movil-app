import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/app_constants.dart';
import '../features/listas/data/firestore_lista_repository.dart';
import '../features/listas/data/memoria_lista_repository.dart';
import '../features/listas/domain/item_lista.dart';
import '../firebase_options.dart';

/// Conecta con Firebase (Firestore + sesión anónima). Si Firebase aún no está
/// configurado o falla, usa un repositorio local en memoria.
Future<ListaRepository> crearRepositorio() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) await auth.signInAnonymously();
    return FirestoreListaRepository(
      FirebaseFirestore.instance,
      clubId: AppConstants.clubId,
    );
  } catch (e) {
    debugPrint('Firebase no disponible, usando modo local: $e');
    return MemoriaListaRepository();
  }
}
