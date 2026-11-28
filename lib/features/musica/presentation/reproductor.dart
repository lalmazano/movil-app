import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../data/deezer_client.dart';
import '../domain/cancion.dart';

/// Reproduce las muestras de 30 s de iTunes. Una sola a la vez en toda la
/// app. En pruebas se reemplaza [Reproductor.instancia] por uno falso.
abstract class Reproductor extends ChangeNotifier {
  static Reproductor instancia = ReproductorJustAudio();

  /// Canción sonando (o cargando), o null.
  Cancion? get actual;
  bool get sonando;

  /// Avance de 0 a 1 de la muestra actual.
  double get avance;

  /// Reproduce la muestra de [cancion] (si ya sonaba, la detiene).
  /// [desde] y [hasta] limitan el fragmento (p. ej. 10 s para adivinar).
  Future<void> alternar(Cancion cancion, {Duration? desde, Duration? hasta});

  Future<void> detener();
}

class ReproductorJustAudio extends Reproductor {
  AudioPlayer? _player;
  StreamSubscription<Object?>? _subEstado;
  StreamSubscription<Duration>? _subPos;
  Cancion? _actual;
  bool _sonando = false;
  double _avance = 0;

  AudioPlayer get _p => _player ??= _crear();

  AudioPlayer _crear() {
    final p = AudioPlayer();
    _subEstado = p.playerStateStream.listen((s) {
      final termino = s.processingState == ProcessingState.completed;
      final sonando = s.playing && !termino;
      if (termino) {
        _actual = null;
        _avance = 0;
      }
      if (sonando != _sonando || termino) {
        _sonando = sonando;
        notifyListeners();
      }
    });
    _subPos = p.positionStream.listen((pos) {
      final total = p.duration;
      if (total == null || total.inMilliseconds == 0) return;
      _avance = (pos.inMilliseconds / total.inMilliseconds).clamp(0, 1);
      notifyListeners();
    });
    return p;
  }

  @override
  Cancion? get actual => _actual;

  @override
  bool get sonando => _sonando;

  @override
  double get avance => _avance;

  @override
  Future<void> alternar(
    Cancion cancion, {
    Duration? desde,
    Duration? hasta,
  }) async {
    if (_actual == cancion) return detener();
    if (cancion.previewUrl == null) return;
    _actual = cancion;
    _avance = 0;
    notifyListeners();
    // Los enlaces de Deezer caducan: se pide uno vigente antes de sonar.
    final url = cancion.esDeezer
        ? await DeezerClient.fabrica().previewFresco(cancion.itunesId) ??
              cancion.previewUrl!
        : cancion.previewUrl!;
    if (_actual != cancion) return;
    try {
      await _p.setAudioSource(
        ClippingAudioSource(
          start: desde,
          end: hasta,
          child: AudioSource.uri(Uri.parse(url)),
        ),
      );
      unawaited(_p.play());
    } catch (e) {
      debugPrint('No se pudo reproducir: $e');
      _actual = null;
      _sonando = false;
      notifyListeners();
    }
  }

  @override
  Future<void> detener() async {
    _actual = null;
    _sonando = false;
    _avance = 0;
    notifyListeners();
    await _player?.stop();
  }

  @override
  void dispose() {
    _subEstado?.cancel();
    _subPos?.cancel();
    _player?.dispose();
    super.dispose();
  }
}

/// Reproductor que no suena: para pruebas.
class ReproductorFalso extends Reproductor {
  final reproducidas = <Cancion>[];
  Cancion? _actual;

  @override
  Cancion? get actual => _actual;

  @override
  bool get sonando => _actual != null;

  @override
  double get avance => 0;

  @override
  Future<void> alternar(
    Cancion cancion, {
    Duration? desde,
    Duration? hasta,
  }) async {
    if (_actual == cancion) return detener();
    reproducidas.add(cancion);
    _actual = cancion;
    notifyListeners();
  }

  @override
  Future<void> detener() async {
    _actual = null;
    notifyListeners();
  }
}
