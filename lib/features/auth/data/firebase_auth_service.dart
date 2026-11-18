import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../domain/auth_service.dart';

/// Inicio de sesión con Google a través de Firebase Auth.
///
/// En Android el id de cliente web se toma de `google-services.json`
/// (recurso `default_web_client_id`).
class FirebaseAuthService implements AuthService {
  FirebaseAuthService(this._auth, this._google, this._db);

  final FirebaseAuth _auth;
  final GoogleSignIn _google;
  final FirebaseFirestore _db;

  static Future<FirebaseAuthService> crear() async {
    final google = GoogleSignIn.instance;
    await google.initialize();
    return FirebaseAuthService(
      FirebaseAuth.instance,
      google,
      FirebaseFirestore.instance,
    );
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
  Future<bool> asegurarRegistro() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final ref = _db.collection('usuarios').doc(user.uid);
    try {
      if ((await ref.get()).exists) return true;
    } on FirebaseException catch (e) {
      // Sin conexión: se deja pasar y Firestore usará la copia local.
      if (e.code == 'unavailable') return true;
      rethrow;
    }
    final config = await _db.collection('config').doc('app').get();
    if (config.data()?['registroAbierto'] == false) return false;
    try {
      await ref.set({
        'nombre': user.displayName,
        'correo': user.email,
        'creadoEn': FieldValue.serverTimestamp(),
      });
      return true;
    } on FirebaseException catch (e) {
      // Las reglas rechazan el registro si se cerró.
      if (e.code == 'permission-denied') return false;
      rethrow;
    }
  }

  @override
  Future<void> salir() async {
    await _google.signOut();
    await _auth.signOut();
  }
}
