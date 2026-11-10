import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../core/storage/json_store.dart';
import '../domain/servicio_sonidos.dart';

/// Sonidos reales con `audioplayers`, usando los WAV originales de
/// `assets/sonidos/` (generados con `tool/generar_sonidos.py`).
///
/// Los reproductores se crean solo cuando hacen falta, así que construir este
/// servicio no toca el audio. La preferencia encendido/apagado se guarda en
/// `<documentos>/sonidos/preferencias.json`.
class ServicioSonidosAudioplayers extends ServicioSonidos {
  ServicioSonidosAudioplayers({BaseDir? baseDir})
    : _store = JsonStore(
        carpeta: 'sonidos',
        archivo: 'preferencias',
        baseDir: baseDir,
      );

  static const _miau = 'sonidos/miau.wav';
  static const _ronroneo = 'sonidos/ronroneo.wav';
  static const _pop = 'sonidos/pop.wav';
  static const _trino = 'sonidos/trino.wav';

  /// Varios reproductores de baja latencia para que los "pop" seguidos se
  /// puedan superponer.
  static const _tamPoolPop = 3;

  final JsonStore _store;
  bool _activado = true;
  Future<void>? _carga;
  Future<bool>? _hayAudio;

  AudioPlayer? _maullido;
  AudioPlayer? _trinador;
  AudioPlayer? _ronroneador;
  StreamSubscription<void>? _finRonroneo;
  int _vueltasRestantes = 0;
  final List<AudioPlayer> _pops = [];
  int _siguientePop = 0;

  @override
  bool get activado => _activado;

  /// Lee la preferencia guardada (solo la primera vez; se puede llamar
  /// varias veces sin problema).
  Future<void> cargar() => _carga ??= _leerPreferencia();

  Future<void> _leerPreferencia() async {
    try {
      final datos = await _store.leer();
      final valor = datos.isEmpty ? null : datos.first['activado'];
      if (valor is bool && valor != _activado) {
        _activado = valor;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('No se pudo leer la preferencia de sonido: $e');
    }
  }

  @override
  Future<void> setActivado(bool valor) async {
    if (valor != _activado) {
      _activado = valor;
      notifyListeners();
    }
    if (!valor) await detenerRonroneo();
    try {
      await _store.escribir([
        {'activado': valor},
      ]);
    } catch (e) {
      debugPrint('No se pudo guardar la preferencia de sonido: $e');
    }
  }

  /// Comprueba una sola vez que el plugin nativo exista. Sin él (pruebas de
  /// widgets, plataformas sin soporte) no se crea ningún `AudioPlayer`, porque
  /// su canal global de eventos reporta errores que no se pueden atrapar.
  Future<bool> _audioDisponible() => _hayAudio ??= _probarPlugin();

  Future<bool> _probarPlugin() async {
    if (kIsWeb) return true;
    try {
      await const MethodChannel('xyz.luan/audioplayers.global')
          .invokeMethod<void>('init');
      return true;
    } on MissingPluginException {
      debugPrint('Sin plugin de audio: el michi se queda mudo.');
      return false;
    } catch (_) {
      return true; // Otro error: que lo intente audioplayers.
    }
  }

  /// Ejecuta [accion] tragándose cualquier error del audio.
  Future<void> _seguro(Future<void> Function() accion) async {
    try {
      if (!await _audioDisponible()) return;
      await accion();
    } catch (e) {
      debugPrint('Sonido michi falló: $e');
    }
  }

  // AudioCache usa el prefijo 'assets/' por defecto.
  AudioPlayer _nuevo() => AudioPlayer();

  @override
  Future<void> maullar() async {
    if (!_activado) return;
    await _seguro(() async {
      final p = _maullido ??= _nuevo();
      await p.stop();
      await p.play(AssetSource(_miau), mode: PlayerMode.lowLatency);
    });
  }

  @override
  Future<void> trino() async {
    if (!_activado) return;
    await _seguro(() async {
      final p = _trinador ??= _nuevo();
      await p.stop();
      await p.play(AssetSource(_trino), mode: PlayerMode.lowLatency);
    });
  }

  @override
  Future<void> pop() async {
    if (!_activado) return;
    await _seguro(() async {
      if (_pops.length < _tamPoolPop) _pops.add(_nuevo());
      final p = _pops[_siguientePop % _pops.length];
      _siguientePop++;
      await p.stop();
      await p.play(AssetSource(_pop), mode: PlayerMode.lowLatency);
    });
  }

  @override
  Future<void> ronronear({int vueltas = 2}) async {
    if (!_activado) return;
    await _seguro(() async {
      final p = _ronroneador ??= _nuevo();
      _finRonroneo ??= p.onPlayerComplete.listen((_) {
        if (_vueltasRestantes > 1 && _activado) {
          _vueltasRestantes--;
          _seguro(p.resume);
        } else {
          _vueltasRestantes = 0;
        }
      });
      final yaSonando = p.state == PlayerState.playing;
      _vueltasRestantes = vueltas;
      await p.setReleaseMode(
        vueltas <= 0 ? ReleaseMode.loop : ReleaseMode.stop,
      );
      // Si ya ronronea, solo se alarga: no se reinicia el sonido.
      if (yaSonando) return;
      // Modo normal (no lowLatency) para poder repetir y saber cuándo acaba.
      await p.play(AssetSource(_ronroneo), mode: PlayerMode.mediaPlayer);
    });
  }

  @override
  Future<void> detenerRonroneo() async {
    _vueltasRestantes = 0;
    final p = _ronroneador;
    if (p == null) return;
    await _seguro(p.stop);
  }

  @override
  void dispose() {
    _finRonroneo?.cancel();
    for (final p in [_maullido, _trinador, _ronroneador, ..._pops]) {
      if (p != null) _seguro(p.dispose);
    }
    super.dispose();
  }
}
