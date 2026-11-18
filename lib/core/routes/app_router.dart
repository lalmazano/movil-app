import 'package:flutter/material.dart';

import '../../features/auth/domain/auth_service.dart';
import '../../features/auth/presentation/auth_gate.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/listas/domain/item_lista.dart';
import '../../features/listas/presentation/lista_page.dart';
import '../widgets/not_found_page.dart';

/// Nombres de rutas de la aplicación.
abstract final class AppRoutes {
  static const String home = '/';

  /// Recibe un [TipoLista] como argumento.
  static const String lista = '/lista';
}

/// Generador de rutas centralizado.
class AppRouter {
  const AppRouter(this.repository, {this.auth});

  final ListaRepository repository;
  final AuthService? auth;

  Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final args = settings.arguments;
    return MaterialPageRoute(
      settings: settings,
      builder: (_) => switch (settings.name) {
        AppRoutes.home => switch (auth) {
          null => HomePage(repository: repository),
          final auth => AuthGate(
            auth: auth,
            child: HomePage(repository: repository, auth: auth),
          ),
        },
        AppRoutes.lista when args is TipoLista => ListaPage(
          tipo: args,
          repository: repository,
        ),
        _ => const NotFoundPage(),
      },
    );
  }
}
