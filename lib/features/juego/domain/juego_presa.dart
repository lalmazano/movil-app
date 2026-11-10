import 'dart:math';
import 'dart:ui';

/// Qué persigue el michi.
enum TipoPresa {
  raton('Ratón', '🐭'),
  pez('Pez', '🐟'),
  laser('Láser', '🔴');

  const TipoPresa(this.nombre, this.emoji);

  final String nombre;
  final String emoji;
}

/// Velocidad de la presa en píxeles lógicos por segundo.
enum VelocidadPresa {
  lento('Lento', 140),
  normal('Normal', 260),
  rapido('Rápido', 420);

  const VelocidadPresa(this.nombre, this.pixelesPorSegundo);

  final String nombre;
  final double pixelesPorSegundo;
}

/// Lógica pura del juego (sin Flutter): la presa recorre curvas de Bézier
/// cuadráticas encadenadas de forma suave, a veces se detiene un momento
/// (como un ratón de verdad) y reaparece en otro lugar cuando la atrapan.
///
/// El movimiento solo depende del tiempo transcurrido, no de los cuadros por
/// segundo: avanzar 1/30 s dos veces es lo mismo que 1/60 s cuatro veces.
class JuegoPresa {
  JuegoPresa({
    required this._area,
    this.velocidad = VelocidadPresa.normal,
    this.radio = 36,
    Random? random,
  }) : _random = random ?? Random() {
    _posicion = _puntoAleatorio();
    _nuevoTramo(desde: _posicion);
  }

  /// Paso máximo de simulación: si la app se congela un rato, la presa no
  /// "teletransporta".
  static const double dtMaximo = 0.1;

  /// Margen extra para el toque: las patitas no son muy precisas.
  static const double toleranciaToque = 1.35;

  final Random _random;
  final double radio;
  VelocidadPresa velocidad;
  Size _area;

  late Offset _posicion;
  Offset _direccion = const Offset(1, 0);
  late Offset _p0, _p1, _p2;
  double _t = 0;
  double _largoTramo = 1;
  double _pausa = 0;
  int _atrapadas = 0;

  Size get area => _area;
  Offset get posicion => _posicion;

  /// Dirección (unitaria) en la que se mueve la presa.
  Offset get direccion => _direccion;
  int get atrapadas => _atrapadas;
  bool get enPausa => _pausa > 0;

  double get _minX => min(radio, _area.width / 2);
  double get _maxX => max(_area.width - radio, _area.width / 2);
  double get _minY => min(radio, _area.height / 2);
  double get _maxY => max(_area.height - radio, _area.height / 2);

  Offset _limitar(Offset p) =>
      Offset(p.dx.clamp(_minX, _maxX), p.dy.clamp(_minY, _maxY));

  Offset _puntoAleatorio() => Offset(
    _minX + _random.nextDouble() * (_maxX - _minX),
    _minY + _random.nextDouble() * (_maxY - _minY),
  );

  void _nuevoTramo({required Offset desde, Offset? control}) {
    _p0 = desde;
    // El punto de control sigue la dirección anterior para que la curva no
    // haga esquinas; si no hay, uno al azar.
    _p1 = _limitar(control ?? _puntoAleatorio());
    _p2 = _puntoAleatorio();
    _t = 0;
    final largo =
        ((_p1 - _p0).distance + (_p2 - _p1).distance + (_p2 - _p0).distance) /
        2;
    _largoTramo = max(largo, 1);
  }

  Offset _bezier(double t) {
    final u = 1 - t;
    return _p0 * (u * u) + _p1 * (2 * u * t) + _p2 * (t * t);
  }

  Offset _tangente(double t) =>
      (_p1 - _p0) * (2 * (1 - t)) + (_p2 - _p1) * (2 * t);

  /// Avanza la simulación [dt] segundos.
  void actualizar(double dt) {
    var restante = dt.clamp(0.0, dtMaximo);
    final rapidez = velocidad.pixelesPorSegundo;
    while (restante > 0) {
      if (_pausa > 0) {
        final usado = min(_pausa, restante);
        _pausa -= usado;
        restante -= usado;
        continue;
      }
      final avanceT = restante * rapidez / _largoTramo;
      if (_t + avanceT < 1) {
        _t += avanceT;
        restante = 0;
      } else {
        restante -= (1 - _t) * _largoTramo / rapidez;
        final fin = _p2;
        final siguienteControl = fin + (_p2 - _p1) * 0.8;
        _nuevoTramo(desde: fin, control: siguienteControl);
        if (_random.nextDouble() < 0.25) {
          _pausa = 0.3 + _random.nextDouble() * 0.6;
        }
      }
    }
    _posicion = _limitar(_bezier(_t));
    final tan = _tangente(_t);
    if (tan.distance > 0.001) _direccion = tan / tan.distance;
  }

  /// `true` si [punto] toca la presa.
  bool toca(Offset punto) =>
      (punto - _posicion).distance <= radio * toleranciaToque;

  /// Si [punto] toca la presa, suma una atrapada, la hace reaparecer lejos y
  /// devuelve `true`.
  bool intentarAtrapar(Offset punto) {
    if (!toca(punto)) return false;
    _atrapadas++;
    reaparecer(lejosDe: punto);
    return true;
  }

  /// Pone la presa en un lugar al azar (lejos de [lejosDe] si se puede).
  void reaparecer({Offset? lejosDe}) {
    var candidato = _puntoAleatorio();
    if (lejosDe != null) {
      final minimo = _area.shortestSide / 3;
      for (var i = 0; i < 12 && (candidato - lejosDe).distance < minimo; i++) {
        candidato = _puntoAleatorio();
      }
    }
    _posicion = candidato;
    _pausa = 0;
    _nuevoTramo(desde: candidato);
  }

  /// Cambia el tamaño del área de juego (rotación, etc.).
  void redimensionar(Size nueva) {
    if (nueva == _area) return;
    _area = nueva;
    _posicion = _limitar(_posicion);
    _nuevoTramo(desde: _posicion);
  }

  void reiniciarPuntos() => _atrapadas = 0;
}
