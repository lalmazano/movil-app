import 'dart:math';

import 'package:flutter/material.dart';

import '../../../app/secciones.dart';
import '../../../app/servicios.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/widgets/paw_background.dart';
import '../../michis/domain/michi.dart';
import '../../michis/presentation/widgets/michi_avatar.dart';
import '../../sonidos/domain/servicio_sonidos.dart';
import '../../sonidos/presentation/boton_sonido.dart';
import '../data/local_michi_fact_repository.dart';
import '../domain/michi_fact.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    this.repository = const LocalMichiFactRepository(),
    this.michiRepository,
    this.sonidos,
    this.hoy,
  });

  final MichiFactRepository repository;

  /// Michis de la casa. Por defecto `AppServicios.instancia.michis`.
  final MichiRepository? michiRepository;

  /// Efectos de sonido. Por defecto `AppServicios.instancia.sonidos`.
  final ServicioSonidos? sonidos;

  /// Fecha de hoy (para pruebas). Por defecto `DateTime.now()`.
  final DateTime? hoy;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _michis = ['🐱', '😺', '😸', '😻', '😽', '😹', '🐈', '🐈‍⬛'];

  final _random = Random();
  int _michiIndex = 0;
  int _caricias = 0;
  MichiFact? _fact;
  List<Michi> _misMichis = const [];

  ServicioSonidos get _sonidos =>
      widget.sonidos ?? AppServicios.instancia.sonidos;

  MichiRepository get _michiRepository =>
      widget.michiRepository ?? AppServicios.instancia.michis;

  @override
  void initState() {
    super.initState();
    _cargarMichis();
  }

  Future<void> _cargarMichis() async {
    try {
      final michis = await _michiRepository.getAll();
      if (mounted) setState(() => _misMichis = michis);
    } catch (_) {
      // Sin almacenamiento disponible: se saluda de forma genérica.
    }
  }

  Future<void> _ir(String ruta) async {
    await Navigator.of(context).pushNamed(ruta);
    await _cargarMichis();
  }

  String get _saludo => switch (_misMichis.length) {
    0 => '¡Miau! Bienvenido',
    1 => '¡Miau, ${_misMichis.single.nombre} te saluda!',
    final n => 'Tus $n michis te saludan',
  };

  void _acariciar() {
    setState(() {
      _caricias++;
      _michiIndex = (_michiIndex + 1) % _michis.length;
    });
    _sonidos.maullar();
    if (_caricias % 5 == 0) _sonidos.ronronear();
  }

  void _nuevoDato() {
    final facts = widget.repository.getAll();
    setState(() => _fact = facts[_random.nextInt(facts.length)]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('🐾 ${AppConstants.appName} 🐾'),
        actions: [BotonSonido(sonidos: _sonidos)],
      ),
      body: PawBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                GestureDetector(
                  key: const Key('michi-interactivo'),
                  onTap: _acariciar,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, anim) =>
                        ScaleTransition(scale: anim, child: child),
                    child: CircleAvatar(
                      key: ValueKey(_michiIndex),
                      radius: 72,
                      backgroundColor: theme.colorScheme.secondary.withValues(
                        alpha: 0.35,
                      ),
                      child: Text(
                        _michis[_michiIndex],
                        style: const TextStyle(fontSize: 80),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _saludo,
                  textAlign: TextAlign.center,
                  style: textTheme.headlineMedium,
                ),
                if (_misMichis.length > 1) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      for (final m in _misMichis)
                        Tooltip(
                          message: m.nombre,
                          child: MichiAvatar.de(m, radius: 18),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  _caricias == 0
                      ? 'Toca al michi para acariciarlo'
                      : 'Caricias: $_caricias ${'❤' * min(_caricias, 5)}',
                  style: textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                ..._avisosMichis(theme),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text('Dato michi', style: textTheme.titleLarge),
                        const SizedBox(height: 8),
                        Text(
                          _fact?.text ?? 'Pide un dato curioso sobre gatos.',
                          textAlign: TextAlign.center,
                          style: textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _nuevoDato,
                          icon: const Icon(Icons.pets),
                          label: const Text('Otro dato'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final seccion in secciones)
                      FilledButton.tonalIcon(
                        onPressed: () => _ir(seccion.ruta),
                        icon: Icon(seccion.icono),
                        label: Text(seccion.titulo),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Banner de cumpleaños o invitación a registrar al primer michi.
  List<Widget> _avisosMichis(ThemeData theme) {
    final textTheme = theme.textTheme;
    if (_misMichis.isEmpty) {
      return [
        Card(
          color: Color.alphaBlend(
            theme.colorScheme.secondary.withValues(alpha: 0.25),
            theme.colorScheme.surface,
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  '¿Aún no registras a tu michi? 🐱',
                  textAlign: TextAlign.center,
                  style: textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => _ir(AppRoutes.michis),
                  icon: const Icon(Icons.add),
                  label: const Text('Crear su perfil'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
      ];
    }
    final hoy = widget.hoy ?? DateTime.now();
    return [
      for (final m in _misMichis.where((m) => m.esCumpleanos(hoy))) ...[
        Card(
          color: theme.colorScheme.secondary.withValues(alpha: 0.35),
          child: ListTile(
            leading: const Text('🎂', style: TextStyle(fontSize: 32)),
            title: Text('¡Hoy es el cumpleaños de ${m.nombre}!'),
            subtitle: Text(_textoCumple(m.edad(hoy))),
          ),
        ),
        const SizedBox(height: 16),
      ],
    ];
  }

  String _textoCumple(int? anios) => switch (anios) {
    null || 0 => '¡Dale muchos mimos! 🎉',
    1 => 'Cumple 1 añito 🎉',
    final n => 'Cumple $n años 🎉',
  };
}
