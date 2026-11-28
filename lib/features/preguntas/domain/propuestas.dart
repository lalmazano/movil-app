import '../../listas/domain/detalles.dart';
import 'preguntas_repository.dart' show preguntaDelDia;

/// Largo permitido de una pregunta propuesta (lo exigen las reglas).
const minCaracteresPropuesta = 5;
const maxCaracteresPropuesta = 300;

/// Pregunta propuesta por alguien del club, guardada en Firestore
/// (`clubs/{club}/banco_preguntas/{id}`). Las que aún no se usan salen
/// primero, de la más antigua a la más nueva.
class PreguntaPropuesta {
  const PreguntaPropuesta({
    required this.id,
    required this.texto,
    required this.creadaEn,
    this.autor,
    this.usadaEn,
  });

  final String id;
  final String texto;
  final DateTime creadaEn;
  final Autor? autor;

  /// Día en que salió como pregunta del día (null = todavía en espera).
  final DateTime? usadaEn;

  bool get usada => usadaEn != null;

  factory PreguntaPropuesta.fromMap(String id, Map<String, Object?> map) =>
      PreguntaPropuesta(
        id: id,
        texto: (map['texto'] as String?) ?? '',
        creadaEn: (map['creadaEn'] as DateTime?) ?? DateTime.now(),
        autor: Autor.fromMap(map['autor']),
        usadaEn: map['usadaEn'] as DateTime?,
      );
}

/// De dónde salió la pregunta de un día.
enum FuentePregunta {
  /// Propuesta por alguien del club.
  club,

  /// Del banco que viene con la app.
  app,
}

/// Valida una propuesta y la devuelve limpia; lanza [ArgumentError] si no
/// sirve.
String validarPropuesta(String texto) {
  final limpio = texto.trim();
  if (limpio.length < minCaracteresPropuesta ||
      limpio.length > maxCaracteresPropuesta) {
    throw ArgumentError.value(
      texto,
      'texto',
      'La pregunta debe tener entre $minCaracteresPropuesta y '
          '$maxCaracteresPropuesta letras',
    );
  }
  return limpio;
}

/// La siguiente propuesta en espera (la más antigua), o null.
PreguntaPropuesta? siguientePropuesta(Iterable<PreguntaPropuesta> banco) {
  final pendientes = banco.where((p) => !p.usada).toList()
    ..sort((a, b) => a.creadaEn.compareTo(b.creadaEn));
  return pendientes.firstOrNull;
}

/// Decide la pregunta de [fecha]: primero la propuesta del club más antigua
/// en espera; si no hay, la del banco de la app.
({String pregunta, FuentePregunta fuente, PreguntaPropuesta? propuesta})
elegirPregunta(DateTime fecha, {Iterable<PreguntaPropuesta> banco = const []}) {
  final propuesta = siguientePropuesta(banco);
  if (propuesta != null) {
    return (
      pregunta: propuesta.texto,
      fuente: FuentePregunta.club,
      propuesta: propuesta,
    );
  }
  return (
    pregunta: preguntaDelDia(fecha),
    fuente: FuentePregunta.app,
    propuesta: null,
  );
}
