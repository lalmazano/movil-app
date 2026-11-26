import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/version_app.dart';

/// Error que se muestra tal cual al usuario.
class ActualizacionException implements Exception {
  const ActualizacionException(this.mensaje);

  final String mensaje;

  @override
  String toString() => mensaje;
}

const _canal = MethodChannel('club.frijol/instalador');

/// Descarga el APK guardado en Firestore por partes
/// (`apk/{build}/partes/{000…}`, campo `datos`), verifica su SHA-256, lo
/// guarda en la caché y abre el instalador de Android. Emite el progreso
/// de 0 a 100.
Stream<double> instalarDesdeFirestore(
  VersionApp version, {
  FirebaseFirestore? db,
}) async* {
  final firestore = db ?? FirebaseFirestore.instance;

  // Sin el permiso "Instalar apps desconocidas" no tiene caso descargar.
  if (await _canal.invokeMethod<bool>('puedeInstalar') != true) {
    await _canal.invokeMethod<void>('abrirPermiso');
    throw const ActualizacionException(
      'Activa "Permitir de esta fuente" para El Club del Frijol y vuelve a '
      'tocar Actualizar.',
    );
  }

  final partes = firestore
      .collection('apk')
      .doc('${version.build}')
      .collection('partes');
  final bytes = BytesBuilder(copy: false);
  for (var i = 0; i < version.partes; i++) {
    final DocumentSnapshot<Map<String, dynamic>> doc;
    try {
      doc = await partes
          .doc(i.toString().padLeft(3, '0'))
          .get(const GetOptions(source: Source.server));
    } on FirebaseException catch (e) {
      throw ActualizacionException(
        'No se pudo descargar la actualización (${e.code}). Revisa tu '
        'conexión e intenta de nuevo.',
      );
    }
    final datos = doc.data()?['datos'];
    if (datos is! Blob) {
      throw const ActualizacionException(
        'La actualización está incompleta. Intenta más tarde.',
      );
    }
    bytes.add(datos.bytes);
    yield (i + 1) / version.partes * 95;
  }

  final apk = bytes.takeBytes();
  if (version.sha256 != null &&
      sha256.convert(apk).toString() != version.sha256) {
    throw const ActualizacionException(
      'El archivo descargado está dañado. Intenta de nuevo.',
    );
  }

  final carpeta = Directory('${(await getTemporaryDirectory()).path}/apk');
  await carpeta.create(recursive: true);
  final archivo = File('${carpeta.path}/club-del-frijol.apk');
  await archivo.writeAsBytes(apk, flush: true);
  yield 98;

  try {
    await _canal.invokeMethod<void>('instalar', {'ruta': archivo.path});
  } on PlatformException catch (e) {
    throw ActualizacionException(
      'No se pudo abrir el instalador: ${e.message}',
    );
  }
  yield 100;
}
