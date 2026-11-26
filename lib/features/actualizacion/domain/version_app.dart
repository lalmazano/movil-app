/// Última versión publicada, en Firestore `config/version`. La escribe
/// GitHub Actions al publicar (ver `.github/workflows/publicar.yml`).
///
/// El APK vive en Firestore partido en [partes] documentos
/// (`apk/{build}/partes/{000…}`), porque Firebase Hosting gratuito no
/// permite archivos .apk.
class VersionApp {
  const VersionApp({
    required this.version,
    required this.build,
    required this.partes,
    this.notas = '',
    this.obligatoria = false,
    this.sha256,
  });

  /// Nombre visible, p. ej. "1.2.0".
  final String version;

  /// Número de compilación (versionCode de Android); se compara con el
  /// instalado.
  final int build;

  /// En cuántos documentos está partido el APK.
  final int partes;

  /// Novedades de la versión.
  final String notas;

  /// Si es true no se puede seguir usando la app sin actualizar.
  final bool obligatoria;

  /// Para verificar que el APK descargado no esté dañado.
  final String? sha256;

  static VersionApp? fromMap(Map<String, Object?>? map) {
    final build = (map?['build'] as num?)?.toInt();
    final partes = (map?['partes'] as num?)?.toInt() ?? 0;
    if (map == null || build == null || partes < 1) return null;
    return VersionApp(
      version: (map['version'] as String?) ?? '$build',
      build: build,
      partes: partes,
      notas: (map['notas'] as String?) ?? '',
      obligatoria: (map['obligatoria'] as bool?) ?? false,
      sha256: map['sha256'] as String?,
    );
  }
}
