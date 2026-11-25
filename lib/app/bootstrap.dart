import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/app_constants.dart';
import '../features/auth/data/firebase_auth_service.dart';
import '../features/auth/domain/auth_service.dart';
import '../features/listas/data/firestore_lista_repository.dart';
import '../features/listas/data/memoria_lista_repository.dart';
import '../features/listas/domain/item_lista.dart';
import '../firebase_options.dart';

/// Lo que la app necesita para arrancar.
typedef Servicios = ({ListaRepository repository, AuthService? auth});

/// Conecta con Firebase (Firestore + inicio de sesión con Google). Si Firebase
/// aún no está configurado o falla, usa un repositorio local sin sesión.
Future<Servicios> crearServicios() async {
  try {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      // Android toma la configuración de android/app/google-services.json.
      await Firebase.initializeApp();
    } else {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    return (
      repository: FirestoreListaRepository(
        FirebaseFirestore.instance,
        clubId: AppConstants.clubId,
        autor: () => switch (FirebaseAuth.instance.currentUser) {
          final u? => Autor(
            uid: u.uid,
            nombre: u.displayName,
            fotoUrl: u.photoURL,
          ),
          null => null,
        },
      ),
      auth: await FirebaseAuthService.crear(),
    );
  } catch (e) {
    debugPrint('Firebase no disponible, usando modo local: $e');
    return (repository: MemoriaListaRepository(), auth: null);
  }
}
