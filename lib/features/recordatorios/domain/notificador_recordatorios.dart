import 'recordatorio.dart';

/// Una notificación lista para entregarse al sistema.
class NotificacionProgramada {
  const NotificacionProgramada({
    required this.id,
    required this.titulo,
    required this.cuerpo,
    required this.fecha,
    required this.repeticion,
  });

  final int id;
  final String titulo;
  final String cuerpo;

  /// Primera vez que debe sonar (hora local).
  final DateTime fecha;
  final Repeticion repeticion;
}

/// Programa y cancela notificaciones locales. La implementación real usa
/// `flutter_local_notifications`; en pruebas se usa una falsa.
abstract interface class NotificadorRecordatorios {
  /// Pide permiso para mostrar notificaciones (Android 13+ / iOS).
  /// Devuelve false si el usuario lo negó.
  Future<bool> solicitarPermiso();

  Future<void> programar(NotificacionProgramada notificacion);

  Future<void> cancelar(int id);
}

/// Notificador que no hace nada (web o cuando las notificaciones fallan).
class NotificadorNulo implements NotificadorRecordatorios {
  const NotificadorNulo();

  @override
  Future<bool> solicitarPermiso() async => false;

  @override
  Future<void> programar(NotificacionProgramada notificacion) async {}

  @override
  Future<void> cancelar(int id) async {}
}
