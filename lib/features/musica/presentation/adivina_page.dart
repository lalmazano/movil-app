import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/widgets/paw_background.dart';
import '../../listas/presentation/config_scope.dart';
import '../../listas/presentation/widgets/huellitas.dart';
import '../domain/adivina_juego.dart';
import '../domain/musica_repository.dart';
import 'reproductor.dart';
import 'widgets_musica.dart';

enum _Fase { intro, ronda, fin }

/// Juego "❓ Adivina la canción": suena un fragmento de 10 s de una canción
/// de la playlist y hay que elegir el título entre 4 opciones.
class AdivinaPage extends StatefulWidget {
  const AdivinaPage({super.key, required this.musica, this.random});

  final MusicaRepository musica;

  /// Para pruebas deterministas.
  final Random? random;

  @override
  State<AdivinaPage> createState() => _AdivinaPageState();
}

class _AdivinaPageState extends State<AdivinaPage>
    with SingleTickerProviderStateMixin {
  late final _clip = AnimationController(
    vsync: this,
    duration: AdivinaJuego.duracionFragmento,
  );
  late final Random _azar = widget.random ?? Random();
  final _reloj = Stopwatch();

  StreamSubscription<List<CancionPlaylist>>? _subPlaylist;
  StreamSubscription<List<RecordAdivina>>? _subRecords;
  List<Cancion>? _canciones;
  List<RecordAdivina> _records = const [];

  _Fase _fase = _Fase.intro;
  PartidaAdivina? _partida;
  int _indice = 0;
  String? _elegida;
  bool _rapida = false;
  int? _recordAnterior;
  bool _nuevoRecord = false;

  Reproductor get _r => Reproductor.instancia;

  @override
  void initState() {
    super.initState();
    _subPlaylist = widget.musica.watchPlaylist().listen(
      (l) => setState(() => _canciones = [for (final c in l) c.cancion]),
      onError: (Object e) {
        debugPrint('No se pudo leer la playlist: $e');
        if (mounted) setState(() => _canciones = const []);
      },
    );
    _subRecords = widget.musica.watchRecords().listen(
      (l) => setState(() => _records = l),
      onError: (Object e) => debugPrint('No se pudieron leer récords: $e'),
    );
  }

  @override
  void dispose() {
    _subPlaylist?.cancel();
    _subRecords?.cancel();
    _clip.dispose();
    unawaited(_r.detener());
    super.dispose();
  }

  RecordAdivina? get _miRecord {
    final uid = widget.musica.autorActual?.uid ?? 'local';
    for (final r in _records) {
      if (r.autor.uid == uid) return r;
    }
    return null;
  }

  RondaAdivina get _ronda => _partida!.rondas[_indice];

  void _jugar() {
    final rondas = AdivinaJuego.crearRondas(_canciones ?? [], random: _azar);
    if (rondas.isEmpty) return;
    setState(() {
      _partida = PartidaAdivina(rondas);
      _indice = 0;
      _elegida = null;
      _recordAnterior = _miRecord?.mejor;
      _nuevoRecord = false;
      _fase = _Fase.ronda;
    });
    _sonar(reiniciarTiempo: true);
  }

  /// Toca el fragmento de la ronda actual desde el principio.
  Future<void> _sonar({bool reiniciarTiempo = false}) async {
    final ronda = _ronda;
    if (reiniciarTiempo) {
      _reloj
        ..reset()
        ..start();
    }
    _clip.forward(from: 0);
    await _r.detener();
    if (!mounted || _fase != _Fase.ronda || _ronda != ronda) return;
    await _r.alternar(ronda.cancion, desde: ronda.inicio, hasta: ronda.fin);
  }

  void _responder(String opcion) {
    if (_elegida != null) return;
    _reloj.stop();
    final antes = _partida!.puntos;
    _partida!.responder(opcion, tiempo: _reloj.elapsed);
    setState(() {
      _elegida = opcion;
      _rapida = _partida!.puntos - antes > 1;
    });
  }

  Future<void> _siguiente() async {
    final partida = _partida!;
    if (_indice + 1 < partida.rondas.length) {
      setState(() {
        _indice++;
        _elegida = null;
      });
      await _sonar(reiniciarTiempo: true);
      return;
    }
    _clip.stop();
    unawaited(_r.detener());
    setState(() {
      _fase = _Fase.fin;
      _nuevoRecord = AdivinaJuego.esNuevoRecord(
        partida.aciertos,
        _recordAnterior,
      );
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.musica.guardarPartida(partida.aciertos);
    } catch (e) {
      debugPrint('No se pudo guardar la partida: $e');
      messenger.showSnackBar(
        const SnackBar(content: Text('No se pudo guardar la partida')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final activo = ConfigClubScope.of(context).adivina;
    return Scaffold(
      appBar: AppBar(title: const Text('❓ Adivina la canción')),
      body: PawBackground(
        child: SafeArea(
          child: !activo
              ? const _Mensaje('El juego está desactivado 💤')
              : switch (_fase) {
                  _Fase.intro => _intro(context),
                  _Fase.ronda => _vistaRonda(context),
                  _Fase.fin => _final(context),
                },
        ),
      ),
    );
  }

  Widget _intro(BuildContext context) {
    final canciones = _canciones;
    if (canciones == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final textTheme = Theme.of(context).textTheme;
    final rondas = AdivinaJuego.rondasPosibles(canciones);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Center(child: Text('🎧', style: TextStyle(fontSize: 72))),
        const SizedBox(height: 8),
        Text(
          'Suena un pedacito de 10 segundos de una canción de su playlist. '
          '¿Cuál es?',
          textAlign: TextAlign.center,
          style: textTheme.bodyLarge,
        ),
        if (rondas > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '$rondas rondas · ⚡ punto extra si respondes en menos de 5 s',
              textAlign: TextAlign.center,
              style: textTheme.bodySmall,
            ),
          ),
        const SizedBox(height: 20),
        if (_records.isNotEmpty) ...[
          Text('🏆 Récords', style: textTheme.titleMedium),
          const SizedBox(height: 4),
          Card(
            child: Column(
              children: [
                for (final r in _records)
                  ListTile(
                    dense: true,
                    leading: AvatarAutor(autor: r.autor, radio: 16),
                    title: Text(r.autor.nombreCorto),
                    subtitle: Text(
                      r.partidas == 1 ? '1 partida' : '${r.partidas} partidas',
                    ),
                    trailing: Text(
                      rondas > 0 ? '${r.mejor}/$rondas' : '${r.mejor}',
                      style: textTheme.titleMedium,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        if (rondas == 0)
          Text(
            'Necesitan al menos ${AdivinaJuego.minimoCanciones} canciones '
            '(con muestra) en la playlist para jugar 🎶',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium,
          )
        else
          Center(
            child: FilledButton.icon(
              key: const Key('adivina-jugar'),
              onPressed: _jugar,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Jugar'),
            ),
          ),
      ],
    );
  }

  Widget _vistaRonda(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final partida = _partida!;
    final ronda = _ronda;
    final elegida = _elegida;
    final respondida = elegida != null;
    final ultima = _indice + 1 == partida.rondas.length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      children: [
        Row(
          children: [
            Text(
              'Ronda ${_indice + 1} de ${partida.rondas.length}',
              style: textTheme.labelLarge,
            ),
            const Spacer(),
            Text('✅ ${partida.aciertos}', style: textTheme.labelLarge),
          ],
        ),
        const SizedBox(height: 12),
        if (!respondida)
          _Escuchando(clip: _clip, onRepetir: _sonar)
        else
          _Revelada(
            cancion: ronda.cancion,
            acierto: ronda.esCorrecta(elegida),
            rapida: _rapida,
          ),
        const SizedBox(height: 16),
        for (final (i, opcion) in ronda.opciones.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _BotonOpcion(
              key: ValueKey('opcion-$i'),
              texto: opcion,
              estado: !respondida
                  ? null
                  : ronda.esCorrecta(opcion)
                  ? true
                  : opcion == elegida
                  ? false
                  : null,
              onPressed: respondida ? null : () => _responder(opcion),
              scheme: scheme,
            ),
          ),
        if (respondida)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Center(
              child: FilledButton.icon(
                key: const Key('adivina-siguiente'),
                onPressed: _siguiente,
                icon: Icon(ultima ? Icons.emoji_events : Icons.arrow_forward),
                label: Text(ultima ? 'Ver resultado' : 'Siguiente'),
              ),
            ),
          ),
      ],
    );
  }

  Widget _final(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final partida = _partida!;
    final total = partida.rondas.length;
    final aciertos = partida.aciertos;
    final mensaje = aciertos == total
        ? '¡Perfecto! Oído de frijol dorado 🫘✨'
        : aciertos >= total / 2
        ? '¡Muy bien! 🎶'
        : aciertos == 0
        ? 'Uy… a escuchar más la playlist 🙈'
        : 'Nada mal, la próxima sale mejor 💪';
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Center(
          child: Text(
            _nuevoRecord ? '🏆' : '🎧',
            style: const TextStyle(fontSize: 72),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$aciertos de $total',
          textAlign: TextAlign.center,
          style: textTheme.displaySmall,
        ),
        if (partida.rapidas > 0)
          Text(
            '⚡ ${partida.rapidas} '
            '${partida.rapidas == 1 ? 'respuesta rápida' : 'respuestas rápidas'}'
            ' · ${partida.puntos} puntos',
            textAlign: TextAlign.center,
            style: textTheme.bodySmall,
          ),
        const SizedBox(height: 12),
        if (_nuevoRecord)
          Text(
            '¡Nuevo récord! 🎉',
            textAlign: TextAlign.center,
            style: textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        Text(mensaje, textAlign: TextAlign.center, style: textTheme.bodyLarge),
        const SizedBox(height: 24),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              key: const Key('adivina-otra-vez'),
              onPressed: _jugar,
              icon: const Icon(Icons.replay),
              label: const Text('Jugar otra vez'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Salir'),
            ),
          ],
        ),
      ],
    );
  }
}

/// 🎧 grande que late mientras suena el fragmento, con barra de avance.
class _Escuchando extends StatelessWidget {
  const _Escuchando({required this.clip, required this.onRepetir});

  final AnimationController clip;
  final VoidCallback onRepetir;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        SizedBox(
          height: 140,
          child: AnimatedBuilder(
            animation: clip,
            builder: (context, _) {
              final latido = clip.isAnimating
                  ? 1 + 0.12 * sin(clip.value * 2 * pi * 10).abs()
                  : 1.0;
              return Transform.scale(
                scale: latido,
                child: const Center(
                  child: Text('🎧', style: TextStyle(fontSize: 88)),
                ),
              );
            },
          ),
        ),
        AnimatedBuilder(
          animation: clip,
          builder: (context, _) => ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(value: clip.value, minHeight: 8),
          ),
        ),
        const SizedBox(height: 4),
        Text('¿Qué canción es?', style: textTheme.titleMedium),
        TextButton.icon(
          key: const Key('adivina-repetir'),
          onPressed: onRepetir,
          icon: const Icon(Icons.replay),
          label: const Text('Volver a escuchar'),
        ),
      ],
    );
  }
}

/// Después de responder: ✅/❌ con portada, título y artista.
class _Revelada extends StatelessWidget {
  const _Revelada({
    required this.cancion,
    required this.acierto,
    required this.rapida,
  });

  final Cancion cancion;
  final bool acierto;
  final bool rapida;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        Text(
          acierto ? (rapida ? '✅ ¡Correcto! ⚡ +1' : '✅ ¡Correcto!') : '❌ Nop',
          style: textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        PortadaCancion(cancion: cancion, lado: 120),
        const SizedBox(height: 8),
        Text(
          cancion.titulo,
          key: const Key('adivina-titulo'),
          textAlign: TextAlign.center,
          style: textTheme.titleMedium,
        ),
        Text(
          cancion.artista,
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _BotonOpcion extends StatelessWidget {
  const _BotonOpcion({
    super.key,
    required this.texto,
    required this.estado,
    required this.onPressed,
    required this.scheme,
  });

  final String texto;

  /// true = correcta, false = la que elegí mal, null = neutra.
  final bool? estado;
  final VoidCallback? onPressed;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final (fondo, frente) = switch (estado) {
      true => (Colors.green.shade100, Colors.green.shade900),
      false => (scheme.errorContainer, scheme.onErrorContainer),
      null => (null, null),
    };
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        backgroundColor: fondo,
        disabledBackgroundColor: fondo,
        foregroundColor: frente,
        disabledForegroundColor: frente,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              texto,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
          if (estado != null) Text(estado! ? ' ✅' : ' ❌'),
        ],
      ),
    );
  }
}

class _Mensaje extends StatelessWidget {
  const _Mensaje(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        texto,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    ),
  );
}
