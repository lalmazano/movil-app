import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../domain/notificador_recordatorios.dart';
import '../domain/recordatorio.dart';

/// Notificaciones reales con `flutter_local_notifications`.
///
/// Se inicializa una sola vez (de forma perezosa si hace falta). Si algo
/// falla, o en web, todas las operaciones se vuelven no-ops para que la app
/// nunca se caiga por culpa de las notificaciones.
class NotificadorLocal implements NotificadorRecordatorios {
  NotificadorLocal._();

  static final NotificadorLocal instancia = NotificadorLocal._();

  final _plugin = FlutterLocalNotificationsPlugin();
  Future<bool>? _inicio;

  static const _detalles = NotificationDetails(
    android: AndroidNotificationDetails(
      'recordatorios_michi',
      'Recordatorios michi',
      channelDescription: 'Comida, arenero, vacunas y otros cuidados 🐾',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  /// Prepara zona horaria y plugin. Devuelve true si quedó listo.
  Future<bool> inicializar() => _inicio ??= _inicializar();

  Future<bool> _inicializar() async {
    if (kIsWeb) return false;
    try {
      tz_data.initializeTimeZones();
      try {
        final zona = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(zona.identifier));
      } catch (e) {
        // Sin zona: las fechas de una vez siguen siendo correctas porque se
        // convierten por instante; las repeticiones podrían desfasarse.
        debugPrint('Recordatorios: zona horaria desconocida ($e)');
      }
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      return true;
    } catch (e) {
      debugPrint(
        'Recordatorios: no se pudieron iniciar las notificaciones: $e',
      );
      return false;
    }
  }

  @override
  Future<bool> solicitarPermiso() async {
    if (!await inicializar()) return false;
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) {
        return await ios.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }
    } catch (e) {
      debugPrint('Recordatorios: permiso no disponible: $e');
    }
    return false;
  }

  @override
  Future<void> programar(NotificacionProgramada n) async {
    if (!await inicializar()) return;
    final f = n.fecha;
    var fecha = tz.TZDateTime(
      tz.local,
      f.year,
      f.month,
      f.day,
      f.hour,
      f.minute,
    );
    if (n.repeticion == Repeticion.unaVez) {
      fecha = tz.TZDateTime.from(f, tz.local);
    }
    try {
      await _plugin.zonedSchedule(
        id: n.id,
        scheduledDate: fecha,
        notificationDetails: _detalles,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: n.titulo,
        body: n.cuerpo,
        matchDateTimeComponents: switch (n.repeticion) {
          Repeticion.unaVez => null,
          Repeticion.diario => DateTimeComponents.time,
          Repeticion.semanal => DateTimeComponents.dayOfWeekAndTime,
          Repeticion.mensual => DateTimeComponents.dayOfMonthAndTime,
        },
      );
    } catch (e) {
      debugPrint('Recordatorios: no se pudo programar ${n.id}: $e');
    }
  }

  @override
  Future<void> cancelar(int id) async {
    if (!await inicializar()) return;
    try {
      await _plugin.cancel(id: id);
    } catch (e) {
      debugPrint('Recordatorios: no se pudo cancelar $id: $e');
    }
  }
}
