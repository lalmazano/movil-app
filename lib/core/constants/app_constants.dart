/// Constantes globales de la aplicación.
abstract final class AppConstants {
  static const String appName = 'El Club del Frijol';
  static const String appVersion = '1.0.0';

  /// Documento de Firestore donde vive el club (`clubs/{clubId}`).
  /// Todos los teléfonos con este mismo id comparten las listas.
  static const String clubId = 'club-del-frijol';

  /// Icono de la app (también se usa como logo dentro de la app).
  static const String logoAsset = 'assets/icon/app_icon.png';
}
