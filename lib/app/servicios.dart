import '../features/michis/data/local_michi_repository.dart';
import '../features/michis/domain/michi.dart';
import '../features/recuerdos/data/local_recuerdo_repository.dart';
import '../features/recuerdos/domain/recuerdo.dart';
import '../features/sonidos/data/servicio_sonidos_audioplayers.dart';
import '../features/sonidos/domain/servicio_sonidos.dart';

/// Contenedor sencillo de dependencias compartidas por toda la app.
///
/// Cada funcionalidad recibe sus repositorios por constructor (para poder
/// probarla con datos falsos); aquí se crean las implementaciones reales una
/// sola vez.
class AppServicios {
  AppServicios._();

  static final AppServicios instancia = AppServicios._();

  final MichiRepository michis = LocalMichiRepository();
  final RecuerdoRepository recuerdos = LocalRecuerdoRepository();

  /// Efectos de sonido. `late` para que el audio solo se prepare la primera
  /// vez que alguien lo usa (las pruebas que no lo tocan no lo inicializan).
  late final ServicioSonidos sonidos = ServicioSonidosAudioplayers()..cargar();
}
