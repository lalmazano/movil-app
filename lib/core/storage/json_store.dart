import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Carpeta base donde la app guarda sus datos. Se puede reemplazar en pruebas.
typedef BaseDir = Future<Directory> Function();

/// Guarda una lista de objetos JSON en un archivo dentro de la carpeta privada
/// de la app: `<documentos>/<carpeta>/<archivo>.json`.
///
/// Patrón común para los repositorios locales de todas las funcionalidades.
class JsonStore {
  JsonStore({required this.carpeta, required this.archivo, BaseDir? baseDir})
    : _baseDir = baseDir ?? getApplicationDocumentsDirectory;

  final String carpeta;
  final String archivo;
  final BaseDir _baseDir;
  Directory? _dir;

  /// Carpeta de la funcionalidad (se crea si no existe). Útil para guardar
  /// archivos adicionales, como fotos.
  Future<Directory> directorio() async {
    final base = await _baseDir();
    return _dir ??= await Directory('${base.path}/$carpeta')
        .create(recursive: true);
  }

  Future<File> _file() async =>
      File('${(await directorio()).path}/$archivo.json');

  Future<List<Map<String, dynamic>>> leer() async {
    final f = await _file();
    if (!await f.exists()) return [];
    final datos = jsonDecode(await f.readAsString()) as List<dynamic>;
    return datos.cast<Map<String, dynamic>>();
  }

  Future<void> escribir(List<Map<String, dynamic>> datos) async {
    await (await _file()).writeAsString(jsonEncode(datos), flush: true);
  }
}

/// Id único simple basado en la hora.
String nuevoId() => DateTime.now().microsecondsSinceEpoch.toString();
