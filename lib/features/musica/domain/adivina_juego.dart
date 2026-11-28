import 'dart:math';

import 'cancion.dart';

/// Lógica pura de "Adivina la canción": suena un fragmento de 10 s de la
/// muestra de una canción de la playlist y hay que elegir el título correcto
/// entre 4 opciones.
abstract final class AdivinaJuego {
  /// Rondas por partida (menos si la playlist es chica).
  static const rondasPorPartida = 5;

  /// Opciones por ronda (la correcta + 3 distractores).
  static const opcionesPorRonda = 4;

  /// Mínimo de canciones con muestra para poder jugar.
  static const minimoCanciones = opcionesPorRonda;

  /// Duración del fragmento que suena.
  static const duracionFragmento = Duration(seconds: 10);

  /// El fragmento empieza entre 0 y este segundo (la muestra dura 30 s).
  static const inicioMaximoSegundos = 15;

  /// Responder antes de esto da un punto extra ⚡.
  static const limiteRapido = Duration(seconds: 5);

  /// Canciones que se pueden usar: con muestra, sin repetidas (por id) y sin
  /// títulos repetidos (para que no haya dos opciones iguales).
  static List<Cancion> jugables(Iterable<Cancion> canciones) {
    final ids = <int>{};
    final titulos = <String>{};
    final r = <Cancion>[];
    for (final c in canciones) {
      final url = c.previewUrl;
      if (url == null || url.isEmpty) continue;
      if (!ids.add(c.itunesId)) continue;
      if (!titulos.add(_clave(c.titulo))) continue;
      r.add(c);
    }
    return r;
  }

  /// Si hay suficientes canciones para jugar.
  static bool sePuedeJugar(Iterable<Cancion> canciones) =>
      jugables(canciones).length >= minimoCanciones;

  /// Cuántas rondas tendría una partida con estas canciones (0 si no se
  /// puede jugar).
  static int rondasPosibles(
    Iterable<Cancion> canciones, {
    int rondas = rondasPorPartida,
  }) {
    final n = jugables(canciones).length;
    return n < minimoCanciones ? 0 : min(rondas, n);
  }

  /// Arma las rondas de una partida. Devuelve una lista vacía si no hay al
  /// menos [minimoCanciones] canciones con muestra.
  static List<RondaAdivina> crearRondas(
    Iterable<Cancion> canciones, {
    int rondas = rondasPorPartida,
    Random? random,
  }) {
    final azar = random ?? Random();
    final todas = jugables(canciones);
    if (todas.length < minimoCanciones || rondas <= 0) return const [];
    final respuestas = [...todas]..shuffle(azar);
    return [
      for (final respuesta in respuestas.take(min(rondas, todas.length)))
        _ronda(respuesta, todas, azar),
    ];
  }

  static RondaAdivina _ronda(
    Cancion respuesta,
    List<Cancion> todas,
    Random azar,
  ) {
    final otras = [
      for (final c in todas)
        if (c.itunesId != respuesta.itunesId) c,
    ]..shuffle(azar);
    final opciones = [
      respuesta.titulo,
      for (final c in otras.take(opcionesPorRonda - 1)) c.titulo,
    ]..shuffle(azar);
    return RondaAdivina(
      cancion: respuesta,
      opciones: opciones,
      inicio: Duration(seconds: azar.nextInt(inicioMaximoSegundos + 1)),
    );
  }

  /// Puntos de una respuesta: 1 por acertar y 1 extra si fue rápida.
  static int puntos({required bool acierto, required Duration tiempo}) {
    if (!acierto) return 0;
    return tiempo <= limiteRapido ? 2 : 1;
  }

  /// Si [aciertos] supera el récord anterior (sin récord, cualquier acierto).
  static bool esNuevoRecord(int aciertos, int? recordAnterior) =>
      aciertos > (recordAnterior ?? 0);

  static String _clave(String titulo) => titulo.trim().toLowerCase();
}

/// Una ronda: la canción que suena, las 4 opciones (títulos) y desde qué
/// segundo de la muestra empieza el fragmento.
class RondaAdivina {
  const RondaAdivina({
    required this.cancion,
    required this.opciones,
    required this.inicio,
  });

  final Cancion cancion;
  final List<String> opciones;
  final Duration inicio;

  Duration get fin => inicio + AdivinaJuego.duracionFragmento;

  String get respuesta => cancion.titulo;

  int get indiceCorrecto => opciones.indexOf(cancion.titulo);

  bool esCorrecta(String opcion) => opcion == cancion.titulo;
}

/// Marcador de una partida en curso.
class PartidaAdivina {
  PartidaAdivina(this.rondas);

  final List<RondaAdivina> rondas;

  /// Opción elegida en cada ronda respondida (en orden).
  final elegidas = <String>[];
  int aciertos = 0;
  int puntos = 0;
  int rapidas = 0;

  int get actual => elegidas.length;
  bool get terminada => elegidas.length >= rondas.length;
  RondaAdivina? get ronda => terminada ? null : rondas[actual];

  /// Registra la respuesta de la ronda actual; devuelve si acertó.
  bool responder(String opcion, {Duration tiempo = Duration.zero}) {
    final r = ronda;
    if (r == null) throw StateError('La partida ya terminó');
    final acierto = r.esCorrecta(opcion);
    elegidas.add(opcion);
    final p = AdivinaJuego.puntos(acierto: acierto, tiempo: tiempo);
    if (acierto) aciertos++;
    if (p > 1) rapidas++;
    puntos += p;
    return acierto;
  }
}
