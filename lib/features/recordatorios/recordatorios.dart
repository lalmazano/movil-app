import 'package:flutter/foundation.dart';

import '../../app/servicios.dart';
import 'data/local_recordatorio_repository.dart';
import 'data/notificador_local.dart';
import 'domain/notificador_recordatorios.dart';
import 'domain/servicio_recordatorios.dart';

/// Servicio de recordatorios con las implementaciones reales (una sola
/// instancia para toda la app).
final ServicioRecordatorios servicioRecordatorios = ServicioRecordatorios(
  repository: LocalRecordatorioRepository(),
  notificador: kIsWeb
      ? const NotificadorNulo()
      : NotificadorLocal.instancia as NotificadorRecordatorios,
  michis: AppServicios.instancia.michis,
);

/// Prepara las notificaciones y reprograma los recordatorios guardados.
///
/// Llamar desde `main()` después de `WidgetsFlutterBinding.ensureInitialized()`.
/// Nunca lanza excepciones y no hace nada en web.
Future<void> inicializarRecordatorios() async {
  if (kIsWeb) return;
  try {
    final listo = await NotificadorLocal.instancia.inicializar().timeout(
      const Duration(seconds: 5),
      onTimeout: () => false,
    );
    if (!listo) return;
    await servicioRecordatorios.sincronizarTodos().timeout(
      const Duration(seconds: 5),
    );
  } catch (e) {
    debugPrint('Recordatorios: inicio fallido: $e');
  }
}
