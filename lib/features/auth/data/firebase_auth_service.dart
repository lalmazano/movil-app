import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../domain/auth_service.dart';

/// Inicio de sesión con Google a través de Firebase Auth.
///
/// En Android el id de cliente web se toma de `google-services.json`
/// (recurso `default_web_client_id`).
class FirebaseAuthService implements AuthService {
  FirebaseAuthService(this._auth, this._google);

  final FirebaseAuth _auth;
  final GoogleSignIn _google;

  static Future<FirebaseAuthService> crear() async {
    final google = GoogleSignIn.instance;
    await google.initialize();
    return FirebaseAuthService(FirebaseAuth.instance, google);
  }

  static Usuario? _aUsuario(User? u) => u == null || u.isAnonymous
      ? null
      : Usuario(
          id: u.uid,
          nombre: u.displayName,
          correo: u.email,
          fotoUrl: u.photoURL,
        );

  @override
  Usuario? get actual => _aUsuario(_auth.currentUser);

  @override
  Stream<Usuario?> get cambios => _auth.authStateChanges().map(_aUsuario);

  @override
  Future<bool> entrarConGoogle() async {
    final GoogleSignInAccount cuenta;
    try {
      cuenta = await _google.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return false;
      rethrow;
    }
    final credencial = GoogleAuthProvider.credential(
      idToken: cuenta.authentication.idToken,
    );
    await _auth.signInWithCredential(credencial);
    return true;
  }

  @override
  Future<void> salir() async {
    await _google.signOut();
    await _auth.signOut();
  }
}
