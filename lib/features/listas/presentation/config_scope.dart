import 'dart:async';

import 'package:flutter/material.dart';

import '../domain/config_club.dart';
import '../domain/item_lista.dart';

/// Escucha `config/app` y la pone a disposición de toda la app
/// ([ConfigClubScope.of]). Si la lectura falla (p. ej. antes de iniciar
/// sesión) usa los valores por defecto y vuelve a intentar.
class ConfigClubProvider extends StatefulWidget {
  const ConfigClubProvider({
    super.key,
    required this.repository,
    required this.child,
  });

  final ListaRepository repository;
  final Widget child;

  @override
  State<ConfigClubProvider> createState() => _ConfigClubProviderState();
}

class _ConfigClubProviderState extends State<ConfigClubProvider> {
  ConfigClub _config = const ConfigClub();
  StreamSubscription<ConfigClub>? _sub;
  Timer? _reintento;

  @override
  void initState() {
    super.initState();
    _escuchar();
  }

  void _escuchar() {
    _sub?.cancel();
    _sub = widget.repository.watchConfig().listen(
      (c) {
        if (mounted) setState(() => _config = c);
      },
      onError: (Object _) {
        _sub?.cancel();
        _reintento?.cancel();
        _reintento = Timer(const Duration(seconds: 3), _escuchar);
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    _reintento?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ConfigClubScope(config: _config, child: widget.child);
}

/// Configuración actual del club para los widgets de abajo.
class ConfigClubScope extends InheritedWidget {
  const ConfigClubScope({
    super.key,
    required this.config,
    required super.child,
  });

  final ConfigClub config;

  /// Sin proveedor (p. ej. en pruebas de un widget suelto) todo vale `true`.
  static ConfigClub of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ConfigClubScope>()?.config ??
      const ConfigClub();

  @override
  bool updateShouldNotify(ConfigClubScope oldWidget) =>
      oldWidget.config != config;
}
