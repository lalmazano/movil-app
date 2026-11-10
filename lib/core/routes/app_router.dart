import 'package:flutter/material.dart';

import '../../features/home/presentation/home_page.dart';
import '../../app/servicios.dart';
import '../../features/juego/presentation/juego_page.dart';
import '../../features/recuerdos/presentation/recuerdos_page.dart';
import '../../features/peso/presentation/peso_page.dart';
import '../../features/logros/presentation/logros_page.dart';
import '../../features/recordatorios/presentation/recordatorios_page.dart';
import '../../features/recordatorios/recordatorios.dart';
import '../../features/salud/data/local_salud_repository.dart';
import '../../features/salud/presentation/salud_page.dart';
import '../widgets/not_found_page.dart';

/// Nombres de rutas de la aplicación.
abstract final class AppRoutes {
  static const String home = '/';
  static const String recuerdos = '/recuerdos';
  static const String peso = '/peso';
  static const String logros = '/logros';
  static const String juego = '/juego';
  static const String recordatorios = '/recordatorios';
  static const String salud = '/salud';
}

/// Generador de rutas centralizado.
abstract final class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.home:
        return MaterialPageRoute(
          builder: (_) => const HomePage(),
          settings: settings,
        );
      case AppRoutes.recuerdos:
        return MaterialPageRoute(
          builder: (_) =>
              RecuerdosPage(repository: AppServicios.instancia.recuerdos),
          settings: settings,
        );
      case AppRoutes.peso:
        return MaterialPageRoute(
          builder: (_) => PesoPage(
            michis: AppServicios.instancia.michis,
            pesos: AppServicios.instancia.peso,
          ),
          settings: settings,
        );
      case AppRoutes.logros:
        return MaterialPageRoute(
          builder: (_) => LogrosPage(
            michis: AppServicios.instancia.michis,
            recuerdos: AppServicios.instancia.recuerdos,
            pesos: AppServicios.instancia.peso,
          ),
          settings: settings,
        );
      case AppRoutes.juego:
        return MaterialPageRoute(
          builder: (_) => JuegoPage(sonidos: AppServicios.instancia.sonidos),
          settings: settings,
        );
      case AppRoutes.recordatorios:
        return MaterialPageRoute(
          builder: (_) => RecordatoriosPage(servicio: servicioRecordatorios),
          settings: settings,
        );
      case AppRoutes.salud:
        return MaterialPageRoute(
          builder: (_) => SaludPage(
            repository: LocalSaludRepository(),
            michis: AppServicios.instancia.michis,
            recordatorios: servicioRecordatorios,
          ),
          settings: settings,
        );
      default:
        return MaterialPageRoute(
          builder: (_) => const NotFoundPage(),
          settings: settings,
        );
    }
  }
}
