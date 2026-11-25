import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../../domain/item_lista.dart';

/// Elige una foto (cámara o galería) y devuelve sus bytes; null si se canceló.
typedef SelectorBytes = Future<Uint8List?> Function(ImageSource origen);

/// Reduce una foto hasta [maxBytesFoto]; null si no se pudo.
typedef ReductorFoto = Future<Uint8List?> Function(Uint8List bytes);

/// Selector real con image_picker: ya comprime a JPEG de 1600 px y calidad 75.
Future<Uint8List?> seleccionarConImagePicker(ImageSource origen) async {
  final archivo = await ImagePicker().pickImage(
    source: origen,
    maxWidth: 1600,
    maxHeight: 1600,
    imageQuality: 75,
  );
  return archivo?.readAsBytes();
}

/// Si la foto pesa más de [maxBytesFoto], la vuelve a codificar como JPEG más
/// pequeño (en otro isolate, para no trabar la interfaz). Devuelve null si no
/// es una imagen reconocible o si ni así baja del límite.
Future<Uint8List?> reducirFoto(Uint8List bytes) async {
  if (bytes.length <= maxBytesFoto) return bytes;
  // Revisión rápida del encabezado: si no es una imagen, ni lo intentamos.
  if (!_pareceImagen(bytes)) return null;
  return compute(_reducirEnIsolate, bytes);
}

/// JPEG, PNG, WebP o GIF según los primeros bytes.
bool _pareceImagen(Uint8List b) {
  bool empieza(List<int> firma, [int desde = 0]) {
    if (b.length < desde + firma.length) return false;
    for (var i = 0; i < firma.length; i++) {
      if (b[desde + i] != firma[i]) return false;
    }
    return true;
  }

  return empieza(const [0xFF, 0xD8, 0xFF]) ||
      empieza(const [0x89, 0x50, 0x4E, 0x47]) ||
      (empieza('RIFF'.codeUnits) && empieza('WEBP'.codeUnits, 8)) ||
      empieza('GIF8'.codeUnits);
}

Uint8List? _reducirEnIsolate(Uint8List bytes) {
  final decodificada = img.decodeImage(bytes);
  if (decodificada == null) return null;
  final original = img.bakeOrientation(decodificada);
  for (final lado in const [1600, 1280, 1024, 800, 640]) {
    final ladoMayor = original.width > original.height
        ? original.width
        : original.height;
    final imagen = ladoMayor <= lado
        ? original
        : original.width >= original.height
        ? img.copyResize(original, width: lado)
        : img.copyResize(original, height: lado);
    for (final calidad in const [75, 60]) {
      final jpg = img.encodeJpg(imagen, quality: calidad);
      if (jpg.length <= maxBytesFoto) return jpg;
    }
  }
  return null;
}
