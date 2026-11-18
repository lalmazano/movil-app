// ARCHIVO PROVISIONAL.
//
// Se reemplaza automáticamente al ejecutar, en la raíz del proyecto:
//
//   dart pub global activate flutterfire_cli
//   flutterfire configure
//
// Mientras no exista la configuración real, la app funciona en "modo local"
// (los datos no se guardan en la nube).
import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => throw UnsupportedError(
    'Firebase no está configurado. Ejecuta `flutterfire configure`.',
  );
}
