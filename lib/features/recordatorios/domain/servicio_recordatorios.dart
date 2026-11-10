import '../../michis/domain/michi.dart';
import 'notificador_recordatorios.dart';
import 'recordatorio.dart';

/// Reloj inyectable (para pruebas).
typedef Reloj = DateTime Function();

/// Une el repositorio con las notificaciones: cada vez que un recordatorio
/// se guarda, se apaga o se borra, su notificación se reprograma o cancela.
class ServicioRecordatorios {
  ServicioRecordatorios({
    required this.repository,
    required this.notificador,
    required this.michis,
    Reloj? reloj,
  }) : reloj = reloj ?? DateTime.now;

  final RecordatorioRepository repository;
  final NotificadorRecordatorios notificador;
  final MichiRepository michis;
  final Reloj reloj;

  Future<List<Recordatorio>> getAll() => repository.getAll();

  /// Guarda (crea o edita) y reprograma su notificación.
  Future<void> guardar(Recordatorio r) async {
    await repository.guardar(r);
    if (r.activo) await notificador.solicitarPermiso();
    await _sincronizar(r, await _nombres());
  }

  /// Enciende o apaga un recordatorio.
  Future<Recordatorio> alternar(Recordatorio r, bool activo) async {
    final nuevo = r.copyWith(activo: activo);
    await guardar(nuevo);
    return nuevo;
  }

  Future<void> eliminar(Recordatorio r) async {
    await repository.delete(r.id);
    await notificador.cancelar(r.idNotificacion);
  }

  /// Vuelve a programar todos (al abrir la app, por si cambió la zona horaria
  /// o se reinstaló).
  Future<void> sincronizarTodos() async {
    final nombres = await _nombres();
    for (final r in await repository.getAll()) {
      await _sincronizar(r, nombres);
    }
  }

  Future<Map<String, String>> _nombres() async {
    try {
      return {for (final m in await michis.getAll()) m.id: m.nombre};
    } catch (_) {
      return const {};
    }
  }

  /// Notificación que corresponde a [r] ahora mismo, o null si no debe sonar.
  NotificacionProgramada? notificacionPara(
    Recordatorio r, {
    String? nombreMichi,
  }) {
    if (!r.activo) return null;
    final proxima = r.proximaOcurrencia(reloj());
    if (proxima == null) return null;
    final texto = textoNotificacion(r, nombreMichi: nombreMichi);
    return NotificacionProgramada(
      id: r.idNotificacion,
      titulo: texto.titulo,
      cuerpo: texto.cuerpo,
      fecha: proxima,
      repeticion: r.repeticion,
    );
  }

  Future<void> _sincronizar(Recordatorio r, Map<String, String> nombres) async {
    await notificador.cancelar(r.idNotificacion);
    final n = notificacionPara(r, nombreMichi: nombres[r.michiId]);
    if (n != null) await notificador.programar(n);
  }
}
