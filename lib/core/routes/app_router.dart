import 'package:flutter/material.dart';

import '../../features/home/presentation/home_page.dart';
import '../../features/listas/domain/item_lista.dart';
import '../../features/listas/presentation/lista_page.dart';
import '../../features/recuerdos/data/local_recuerdo_repository.dart';
import '../../features/recuerdos/presentation/recuerdos_page.dart';
import '../widgets/not_found_page.dart';

/// Nombres de rutas de la aplicación.
abstract final class AppRoutes {
  static const String home = '/';
  static const String recuerdos = '/recuerdos';

  /// Recibe un [TipoLista] como argumento.
  static const String lista = '/lista';
}

/// Generador de rutas centralizado.
class AppRouter {
  const AppRouter(this.repository);

  final ListaRepository repository;

  Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final args = settings.arguments;
    return MaterialPageRoute(
      settings: settings,
      builder: (_) => switch (settings.name) {
        AppRoutes.home => HomePage(repository: repository),
        AppRoutes.lista when args is TipoLista => ListaPage(
          tipo: args,
          repository: repository,
        ),
        AppRoutes.recuerdos => RecuerdosPage(
          repository: LocalRecuerdoRepository(),
        ),
        _ => const NotFoundPage(),
      },
    );
  }
}
