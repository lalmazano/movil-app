/// Última versión publicada, en Firestore `config/version`. La escribe
/// GitHub Actions al publicar (ver `.github/workflows/publicar.yml`).
class VersionApp {
  const VersionApp({
    required this.version,
    required this.build,
    required this.url,
    this.notas = '',
    this.obligatoria = false,
    this.sha256,
  });

  /// Nombre visible, p. ej. "1.2.0".
  final String version;

  /// Número de compilación (versionCode de Android); se compara con el
  /// instalado.
  final int build;

  /// Dónde descargar el APK.
  final String url;

  /// Novedades de la versión.
  final String notas;

  /// Si es true no se puede seguir usando la app sin actualizar.
  final bool obligatoria;

  /// Para verificar que el APK descargado no esté dañado.
  final String? sha256;

  static VersionApp? fromMap(Map<String, Object?>? map) {
    final build = (map?['build'] as num?)?.toInt();
    final url = map?['url'];
    if (map == null || build == null || url is! String || url.isEmpty) {
      return null;
    }
    return VersionApp(
      version: (map['version'] as String?) ?? '$build',
      build: build,
      url: url,
      notas: (map['notas'] as String?) ?? '',
      obligatoria: (map['obligatoria'] as bool?) ?? false,
      sha256: map['sha256'] as String?,
    );
  }
}
