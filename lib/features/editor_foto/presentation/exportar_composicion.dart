import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import '../../../core/storage/json_store.dart';

/// Ancho aproximado (en píxeles) de la imagen exportada.
const double anchoExportacion = 1080;

/// Renderiza [lienzo] a PNG de ~[ancho] px y lo guarda en [dir] como
/// `michi_editado_<id>.png`. Devuelve la ruta del archivo creado.
Future<String> exportarComposicion(
  RenderRepaintBoundary lienzo,
  Directory dir, {
  double ancho = anchoExportacion,
}) async {
  final pixelRatio = lienzo.size.width > 0 ? ancho / lienzo.size.width : 1.0;
  final imagen = await lienzo.toImage(pixelRatio: pixelRatio);
  try {
    final datos = await imagen.toByteData(format: ui.ImageByteFormat.png);
    if (datos == null) {
      throw StateError('No se pudo codificar la imagen');
    }
    if (!await dir.exists()) await dir.create(recursive: true);
    final archivo = File(
      '${dir.path}${Platform.pathSeparator}michi_editado_${nuevoId()}.png',
    );
    await archivo.writeAsBytes(datos.buffer.asUint8List(), flush: true);
    return archivo.path;
  } finally {
    imagen.dispose();
  }
}
