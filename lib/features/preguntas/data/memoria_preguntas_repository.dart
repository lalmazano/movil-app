import 'dart:async';

import '../../listas/domain/detalles.dart';
import '../domain/preguntas_repository.dart';

/// Preguntas en memoria, para pruebas y modo local. Aplica la misma regla que
/// Firestore: las respuestas de los demás solo se ven después de responder.
class MemoriaPreguntasRepository implements PreguntasRepository {
  MemoriaPreguntasRepository({
    required this.autor,
    DateTime Function()? reloj,
    this.internet,
  }) : reloj = reloj ?? DateTime.now;

  /// Para pruebas: simula la pregunta de internet de un día.
  final Future<String?> Function(DateTime fecha)? internet;

  final _propuestas = <PreguntaPropuesta>[];
  var _siguienteId = 0;

  /// Quién usa la app (null en modo local sin sesión).
  final Autor? Function() autor;
  final DateTime Function() reloj;

  /// Pregunta guardada por día.
  final _preguntas = <String, String>{};

  /// Respuestas por día y uid.
  final _respuestas = <String, Map<String, Respuesta>>{};
  final _cambios = StreamController<void>.broadcast();

  @override
  String get hoy => claveDia(reloj());

  @override
  Autor? get autorActual => autor();

  /// Repite el valor actual cada vez que algo cambia.
  Stream<T> _vigilar<T>(T Function() valor) async* {
    yield valor();
    yield* _cambios.stream.map((_) => valor());
  }

  @override
  Future<void> asegurarHoy({bool usarInternet = false}) async {
    final dia = hoy;
    if (_preguntas.containsKey(dia)) return;
    final fecha = fechaDeClave(dia)!;
    final deInternet =
        siguientePropuesta(_propuestas) == null &&
            usarInternet &&
            tocaInternet(fecha)
        ? await internet?.call(fecha)
        : null;
    final elegida = elegirPregunta(
      fecha,
      banco: _propuestas,
      deInternet: deInternet,
    );
    if (_preguntas.containsKey(dia)) return;
    if (elegida.propuesta case final p?) {
      final i = _propuestas.indexWhere((x) => x.id == p.id);
      _propuestas[i] = PreguntaPropuesta(
        id: p.id,
        texto: p.texto,
        creadaEn: p.creadaEn,
        autor: p.autor,
        usadaEn: reloj(),
      );
    }
    _preguntas[dia] = elegida.pregunta;
    _cambios.add(null);
  }

  @override
  Stream<List<PreguntaPropuesta>> watchPropuestas() =>
      _vigilar(() => List.unmodifiable(_propuestas));

  @override
  Future<void> proponer(String texto) async {
    final yo = autor();
    if (yo == null) throw StateError('Inicia sesión para proponer.');
    _propuestas.add(
      PreguntaPropuesta(
        id: '${_siguienteId++}',
        texto: validarPropuesta(texto),
        creadaEn: reloj(),
        autor: yo,
      ),
    );
    _cambios.add(null);
  }

  @override
  Future<void> borrarPropuesta(String id) async {
    _propuestas.removeWhere((p) => p.id == id);
    _cambios.add(null);
  }

  @override
  Stream<String> watchPregunta(String dia) =>
      _vigilar(() => _preguntas[dia] ?? preguntaDelDia(fechaDeClave(dia)!));

  Respuesta? _mia(String dia) {
    final uid = autor()?.uid;
    return uid == null ? null : _respuestas[dia]?[uid];
  }

  /// Respuestas de los demás, solo si ya respondí (si no, ninguna).
  List<Respuesta> _otras(String dia) {
    final uid = autor()?.uid;
    if (_mia(dia) == null) return const [];
    return [
      for (final r in (_respuestas[dia] ?? const {}).values)
        if (r.autor.uid != uid) r,
    ];
  }

  @override
  Stream<Respuesta?> watchMiRespuesta(String dia) => _vigilar(() => _mia(dia));

  @override
  Stream<List<Respuesta>> watchOtras(String dia) => _vigilar(() => _otras(dia));

  @override
  Future<void> responder(String dia, String texto) async {
    final yo = autor();
    if (yo == null) throw StateError('Inicia sesión para responder.');
    await responderComo(yo, dia, texto);
  }

  /// Guarda la respuesta de [yo] (en pruebas simula el teléfono del otro).
  Future<void> responderComo(Autor yo, String dia, String texto) async {
    final limpio = texto.trim();
    if (limpio.isEmpty || limpio.length > maxCaracteresRespuesta) {
      throw ArgumentError.value(texto, 'texto', 'Debe tener 1 a 1000 letras');
    }
    _preguntas.putIfAbsent(dia, () => preguntaDelDia(fechaDeClave(dia)!));
    (_respuestas[dia] ??= {})[yo.uid] = Respuesta(
      autor: yo,
      texto: limpio,
      fecha: reloj(),
    );
    _cambios.add(null);
  }

  List<DiaPregunta> _historial(int limite) {
    final actual = hoy;
    final dias = _preguntas.keys.where((d) => d.compareTo(actual) < 0).toList()
      ..sort((a, b) => b.compareTo(a));
    return [
      for (final dia in dias.take(limite))
        DiaPregunta(
          dia: dia,
          pregunta: _preguntas[dia]!,
          mia: _mia(dia),
          otras: _otras(dia),
        ),
    ];
  }

  @override
  Stream<List<DiaPregunta>> watchHistorial({int limite = 30}) =>
      _vigilar(() => _historial(limite));

  @override
  Future<Autor?> pareja() async {
    final dias = _respuestas.keys.toList()..sort((a, b) => b.compareTo(a));
    for (final dia in dias) {
      final otras = _otras(dia);
      if (otras.isNotEmpty) return otras.first.autor;
    }
    return null;
  }
}
