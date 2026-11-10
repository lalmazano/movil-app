import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';

import '../domain/recuerdo.dart';
import '../domain/recuerdo_acciones.dart';

/// Implementación real con `gal` (galería) y `share_plus` (compartir).
class DispositivoRecuerdoAcciones implements RecuerdoAcciones {
  const DispositivoRecuerdoAcciones();

  static const album = 'Michis';

  @override
  Future<void> guardarEnGaleria(Recuerdo recuerdo) async {
    if (!await Gal.hasAccess(toAlbum: true) &&
        !await Gal.requestAccess(toAlbum: true)) {
      throw const PermisoGaleriaDenegado();
    }
    try {
      await Gal.putImage(recuerdo.imagePath, album: album);
    } on GalException catch (e) {
      if (e.type == GalExceptionType.accessDenied) {
        throw const PermisoGaleriaDenegado();
      }
      rethrow;
    }
  }

  @override
  Future<void> compartir(Recuerdo recuerdo) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(recuerdo.imagePath)],
        text: textoParaCompartir(recuerdo),
      ),
    );
  }
}
