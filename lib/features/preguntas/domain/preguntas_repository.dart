import 'dart:async';

import '../../listas/domain/detalles.dart';
import 'banco_preguntas.dart';
import 'propuestas.dart';

export 'propuestas.dart';

/// Máximo de caracteres de una respuesta (lo exigen las reglas de Firestore).
const maxCaracteresRespuesta = 1000;

/// Clave del día local en formato `aaaa-mm-dd` (el id del documento).
String claveDia(DateTime fecha) {
  String dos(int n) => n.toString().padLeft(2, '0');
  return '${fecha.year.toString().padLeft(4, '0')}-${dos(fecha.month)}-'
      '${dos(fecha.day)}';
}

/// Convierte una clave `aaaa-mm-dd` en fecha local (null si no es válida).
DateTime? fechaDeClave(String clave) {
  final partes = clave.split('-');
  if (partes.length != 3) return null;
  final [a, m, d] = partes.map(int.tryParse).toList();
  if (a == null || m == null || d == null) return null;
  return DateTime(a, m, d);
}

/// Pregunta que le toca a un día. Depende solo de la fecha local, así que es
/// la misma en los dos teléfonos.
///
/// Se cuentan los días desde una fecha fija y se recorre el banco con un
/// salto que no divide su tamaño: así se visitan todas las preguntas antes de
/// repetir y dos días seguidos caen lejos uno del otro en el banco.
String preguntaDelDia(DateTime fecha, {List<String> banco = bancoPreguntas}) {
  final n = banco.length;
  // UTC para que los cambios de horario no muevan la cuenta de días.
  final dias = DateTime.utc(
    fecha.year,
    fecha.month,
    fecha.day,
  ).difference(DateTime.utc(2024)).inDays;
  final indice = (dias * _salto(n) + 7) % n;
  return banco[indice < 0 ? indice + n : indice];
}

/// Primer número desde 37 que es primo relativo con [n].
int _salto(int n) {
  int mcd(int a, int b) => b == 0 ? a : mcd(b, a % b);
  var s = 37;
  while (n > 1 && mcd(s, n) != 1) {
    s++;
  }
  return s;
}

/// Respuesta de una persona a la pregunta de un día.
class Respuesta {
  const Respuesta({required this.autor, required this.texto, this.fecha});

  final Autor autor;
  final String texto;
  final DateTime? fecha;

  Map<String, Object?> toMap() => {
    'texto': texto,
    'autor': autor.toMap(),
    'fecha': fecha,
  };

  /// Las fechas ya deben venir como [DateTime].
  static Respuesta? fromMap(Object? map) {
    if (map is! Map) return null;
    final autor = Autor.fromMap(map['autor']);
    final texto = map['texto'];
    if (autor == null || texto is! String) return null;
    return Respuesta(
      autor: autor,
      texto: texto,
      fecha: map['fecha'] as DateTime?,
    );
  }
}

/// Lo que se puede ver de un día: la pregunta, mi respuesta y (solo si ya
/// respondí) las de los demás.
class DiaPregunta {
  const DiaPregunta({
    required this.dia,
    required this.pregunta,
    this.mia,
    this.otras = const [],
    this.cargando = false,
  });

  /// Clave `aaaa-mm-dd`.
  final String dia;
  final String pregunta;
  final Respuesta? mia;
  final List<Respuesta> otras;

  /// Aún no se sabe si respondí.
  final bool cargando;

  bool get respondi => mia != null;

  DateTime? get fecha => fechaDeClave(dia);
}

/// Contrato del repositorio de la pregunta del día
/// (`clubs/{club}/preguntas/{aaaa-mm-dd}/respuestas/{uid}`).
///
/// La respuesta de la otra persona solo se puede leer después de contestar la
/// propia: no llames a [watchOtras] antes de que exista mi respuesta (las
/// reglas lo rechazan). [watchDia] ya se encarga de eso.
abstract interface class PreguntasRepository {
  /// Clave de hoy (fecha local).
  String get hoy;

  /// Quién usa la app (null sin sesión).
  Autor? get autorActual;

  /// Crea el documento de hoy con su pregunta si todavía no existe: primero
  /// una propuesta del club; si no hay, la del banco de la app.
  Future<void> asegurarHoy();

  /// Preguntas propuestas por el club (en espera primero).
  Stream<List<PreguntaPropuesta>> watchPropuestas();

  /// Propone una pregunta nueva (5 a 300 letras).
  Future<void> proponer(String texto);

  /// Borra una propuesta propia.
  Future<void> borrarPropuesta(String id);

  /// Pregunta guardada de [dia] (si aún no existe, la del banco).
  Stream<String> watchPregunta(String dia);

  /// Mi respuesta de [dia], o null si no he respondido.
  Stream<Respuesta?> watchMiRespuesta(String dia);

  /// Respuestas de los demás en [dia]. Solo después de responder.
  Stream<List<Respuesta>> watchOtras(String dia);

  /// Guarda (o cambia) mi respuesta de [dia].
  Future<void> responder(String dia, String texto);

  /// Días anteriores a hoy (del más reciente al más viejo) con lo que se
  /// puede ver de cada uno.
  Stream<List<DiaPregunta>> watchHistorial({int limite = 30});

  /// La otra persona del club, si ya se conoce por alguna respuesta visible
  /// (sirve para decir "Esperando a Ana…"). null si aún no se sabe.
  Future<Autor?> pareja();
}

extension VerDia on PreguntasRepository {
  /// Todo lo visible de [dia] en un solo stream. Escucha las respuestas de
  /// los demás solo cuando ya existe la mía; si eso falla, se quedan ocultas.
  Stream<DiaPregunta> watchDia(String dia) {
    late final StreamController<DiaPregunta> salida;
    final subs = <StreamSubscription<Object?>>[];
    StreamSubscription<List<Respuesta>>? subOtras;
    String? pregunta;
    Respuesta? mia;
    var miaCargada = false;
    var otras = const <Respuesta>[];

    void emitir() {
      if (salida.isClosed) return;
      salida.add(
        DiaPregunta(
          dia: dia,
          pregunta: pregunta ?? preguntaDelDia(fechaDeClave(dia)!),
          mia: mia,
          otras: mia == null ? const [] : otras,
          cargando: !miaCargada,
        ),
      );
    }

    salida = StreamController<DiaPregunta>(
      onListen: () {
        subs.add(
          watchPregunta(dia).listen((p) {
            pregunta = p;
            emitir();
          }, onError: (Object _) {}),
        );
        subs.add(
          watchMiRespuesta(dia).listen(
            (r) {
              mia = r;
              miaCargada = true;
              if (r != null) {
                subOtras ??= watchOtras(dia).listen((o) {
                  otras = o;
                  emitir();
                }, onError: (Object _) {});
              }
              emitir();
            },
            onError: (Object _) {
              miaCargada = true;
              emitir();
            },
          ),
        );
      },
      onCancel: () async {
        for (final s in subs) {
          await s.cancel();
        }
        await subOtras?.cancel();
      },
    );
    return salida.stream;
  }
}
