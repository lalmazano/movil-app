import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/paw_background.dart';
import '../../sonidos/domain/servicio_sonidos.dart';
import '../../sonidos/presentation/boton_sonido.dart';
import '../domain/juego_presa.dart';

/// Juego para que el gato persiga una presa por la pantalla.
///
/// Primero la persona elige presa y velocidad; luego la pantalla pasa a modo
/// inmersivo. Para salir hay que mantener presionado el botón "salir", así el
/// michi no termina el juego por accidente.
class JuegoPage extends StatefulWidget {
  const JuegoPage({super.key, required this.sonidos, this.random});

  final ServicioSonidos sonidos;

  /// Para pruebas: hace el movimiento reproducible.
  final Random? random;

  @override
  State<JuegoPage> createState() => _JuegoPageState();
}

class _Destello {
  _Destello(this.centro, this.inicio);

  final Offset centro;
  final Duration inicio;
}

class _JuegoPageState extends State<JuegoPage>
    with SingleTickerProviderStateMixin {
  static const _duracionDestello = Duration(milliseconds: 700);
  static const _fondo = Color(0xFF15100E);

  late final Ticker _ticker = createTicker(_tick);
  TipoPresa _tipo = TipoPresa.raton;
  VelocidadPresa _velocidad = VelocidadPresa.normal;
  bool _jugando = false;
  JuegoPresa? _juego;
  Duration _ultimo = Duration.zero;
  Duration _ahora = Duration.zero;
  final List<_Destello> _destellos = [];
  int _puntuacionFinal = 0;

  @override
  void dispose() {
    _ticker.dispose();
    if (_jugando) _restaurarSistema();
    super.dispose();
  }

  void _restaurarSistema() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  void _empezar() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    setState(() {
      _jugando = true;
      _juego = null; // se crea al conocer el tamaño de la pantalla
      _destellos.clear();
      _ultimo = Duration.zero;
      _ahora = Duration.zero;
    });
    _ticker.start();
  }

  void _terminar() {
    _ticker.stop();
    _restaurarSistema();
    setState(() {
      _puntuacionFinal = _juego?.atrapadas ?? 0;
      _jugando = false;
      _juego = null;
    });
  }

  void _tick(Duration transcurrido) {
    final dt = (transcurrido - _ultimo).inMicroseconds / 1e6;
    _ultimo = transcurrido;
    _ahora = transcurrido;
    _juego?.actualizar(dt);
    _destellos.removeWhere((d) => _ahora - d.inicio > _duracionDestello);
    setState(() {});
  }

  void _alTocar(PointerDownEvent evento) {
    final juego = _juego;
    if (juego == null) return;
    final donde = juego.posicion;
    if (juego.intentarAtrapar(evento.localPosition)) {
      widget.sonidos.pop();
      HapticFeedback.lightImpact();
      setState(() => _destellos.add(_Destello(donde, _ahora)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Mientras se juega, "atrás" no hace nada: se sale con pulsación larga.
      canPop: !_jugando,
      child: _jugando ? _construirJuego() : _construirMenu(context),
    );
  }

  Widget _construirMenu(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Juego para michi'),
        actions: [BotonSonido(sonidos: widget.sonidos)],
      ),
      body: PawBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(_tipo.emoji, style: const TextStyle(fontSize: 72)),
                const SizedBox(height: 8),
                Text(
                  'Pon el teléfono en el suelo y deja que tu michi cace.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyLarge,
                ),
                if (_puntuacionFinal > 0) ...[
                  const SizedBox(height: 12),
                  Text(
                    '¡Tu michi atrapó $_puntuacionFinal! 🏆',
                    style: textTheme.titleMedium,
                  ),
                ],
                const SizedBox(height: 24),
                Text('¿Qué va a perseguir?', style: textTheme.titleMedium),
                const SizedBox(height: 8),
                SegmentedButton<TipoPresa>(
                  segments: [
                    for (final t in TipoPresa.values)
                      ButtonSegment(
                        value: t,
                        label: Text('${t.emoji} ${t.nombre}'),
                      ),
                  ],
                  selected: {_tipo},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => setState(() => _tipo = s.first),
                ),
                const SizedBox(height: 20),
                Text('Velocidad', style: textTheme.titleMedium),
                const SizedBox(height: 8),
                SegmentedButton<VelocidadPresa>(
                  segments: [
                    for (final v in VelocidadPresa.values)
                      ButtonSegment(value: v, label: Text(v.nombre)),
                  ],
                  selected: {_velocidad},
                  onSelectionChanged: (s) =>
                      setState(() => _velocidad = s.first),
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: _empezar,
                  icon: const Icon(Icons.pets),
                  label: const Text('¡A jugar!'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _construirJuego() {
    return Scaffold(
      backgroundColor: _fondo,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final area = constraints.biggest;
          final juego = _juego ??= JuegoPresa(
            area: area,
            velocidad: _velocidad,
            random: widget.random,
          );
          juego.redimensionar(area);
          return Stack(
            fit: StackFit.expand,
            children: [
              Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: _alTocar,
                child: const SizedBox.expand(),
              ),
              for (final d in _destellos) _construirDestello(d),
              Positioned(
                left: juego.posicion.dx - juego.radio,
                top: juego.posicion.dy - juego.radio,
                width: juego.radio * 2,
                height: juego.radio * 2,
                child: IgnorePointer(child: _construirPresa(juego)),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        '¡Atrapadas: ${juego.atrapadas}!',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: SafeArea(child: _BotonSalir(onSalir: _terminar)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _construirPresa(JuegoPresa juego) {
    if (_tipo == TipoPresa.laser) {
      return Center(
        key: const Key('presa'),
        child: Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFFF2D2D),
            boxShadow: [
              BoxShadow(
                color: Color(0xAAFF2D2D),
                blurRadius: 18,
                spreadRadius: 6,
              ),
            ],
          ),
        ),
      );
    }
    // Los emojis miran a la izquierda: se voltean al ir a la derecha y se
    // balancean un poco para que parezcan vivos.
    final dir = juego.direccion;
    final balanceo = juego.enPausa
        ? 0.0
        : sin(_ahora.inMilliseconds / 70) * 0.15;
    return Transform(
      key: const Key('presa'),
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..rotateZ(balanceo)
        ..scaleByDouble(dir.dx > 0 ? -1.0 : 1.0, 1.0, 1.0, 1.0),
      child: FittedBox(
        child: Text(_tipo.emoji, style: const TextStyle(fontSize: 56)),
      ),
    );
  }

  Widget _construirDestello(_Destello d) {
    final p =
        ((_ahora - d.inicio).inMicroseconds / _duracionDestello.inMicroseconds)
            .clamp(0.0, 1.0);
    const n = 8;
    return Positioned.fill(
      child: IgnorePointer(
        child: Opacity(
          opacity: 1 - p,
          child: Stack(
            children: [
              for (var i = 0; i < n; i++)
                Positioned(
                  left: d.centro.dx + cos(2 * pi * i / n) * 80 * p - 14,
                  top: d.centro.dy + sin(2 * pi * i / n) * 80 * p - 14,
                  child: Text(
                    i.isEven ? '✨' : '🐾',
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Botón discreto que solo responde a una pulsación larga.
class _BotonSalir extends StatelessWidget {
  const _BotonSalir({required this.onSalir});

  final VoidCallback onSalir;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const Key('salir-juego'),
      onLongPress: onSalir,
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.logout, size: 16, color: MichiColors.rosa),
            SizedBox(width: 4),
            Text(
              'Mantén para salir',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
