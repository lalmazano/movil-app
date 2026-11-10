import 'package:flutter/material.dart';

import '../../features/home/presentation/home_page.dart';
import '../widgets/not_found_page.dart';

/// Nombres de rutas de la aplicación.
abstract final class AppRoutes {
  static const String home = '/';
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
      default:
        return MaterialPageRoute(
          builder: (_) => const NotFoundPage(),
          settings: settings,
        );
    }
  }
}
