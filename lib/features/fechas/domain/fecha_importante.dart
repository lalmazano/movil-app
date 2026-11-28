import '../../home/domain/aniversario.dart';
import '../../listas/domain/detalles.dart';

/// Emojis que se pueden elegir para una fecha.
const emojisFecha = ['🎂', '💍', '❤️', '🎉', '✈️', '🎓', '⭐'];

/// Lo que se captura al crear o editar una fecha.
class NuevaFecha {
  const NuevaFecha({
    required this.titulo,
    required this.fecha,
    this.anual = false,
    this.emoji = '⭐',
    this.contarAnios = false,
  });

  final String titulo;
  final DateTime fecha;

  /// Se repite cada año (cumpleaños, aniversarios).
  final bool anual;
  final String emoji;

  /// En fechas anuales, el año de [fecha] es el original y se muestra
  /// "cumple N años".
  final bool contarAnios;

  /// Campos de Firestore (sin `creadaPor`). La fecha se guarda a mediodía
  /// para que un cambio de zona horaria no la mueva de día.
  Map<String, Object?> toMap() => {
    'titulo': titulo.trim(),
    'fecha': DateTime(fecha.year, fecha.month, fecha.day, 12),
    'anual': anual,
    'emoji': emoji,
    'contarAnios': anual && contarAnios,
  };
}

/// Una fecha importante del club: `clubs/{club}/fechas/{id}`.
class FechaImportante {
  const FechaImportante({
    required this.id,
    required this.titulo,
    required this.fecha,
    this.anual = false,
    this.emoji = '⭐',
    this.contarAnios = false,
    this.creadaPor,
  });

  /// [map] ya debe traer las fechas como [DateTime].
  factory FechaImportante.fromMap(String id, Map<String, Object?> map) =>
      FechaImportante(
        id: id,
        titulo: (map['titulo'] as String?) ?? '',
        fecha: (map['fecha'] as DateTime?) ?? DateTime(2000),
        anual: (map['anual'] as bool?) ?? false,
        emoji: (map['emoji'] as String?) ?? '⭐',
        contarAnios: (map['contarAnios'] as bool?) ?? false,
        creadaPor: Autor.fromMap(map['creadaPor']),
      );

  final String id;
  final String titulo;
  final DateTime fecha;
  final bool anual;
  final String emoji;
  final bool contarAnios;
  final Autor? creadaPor;

  NuevaFecha get datos => NuevaFecha(
    titulo: titulo,
    fecha: fecha,
    anual: anual,
    emoji: emoji,
    contarAnios: contarAnios,
  );

  /// Próxima vez que toca (ver [proximaOcurrencia]).
  DateTime proxima(DateTime hoy) => proximaOcurrencia(fecha, hoy, anual: anual);

  /// Días que faltan (negativo si ya pasó y no se repite).
  int diasRestantes(DateTime hoy) => diasEntre(hoy, proxima(hoy));

  /// "cumple 30 años" en fechas anuales con año original, o null.
  String? cumple(DateTime hoy) {
    if (!anual || !contarAnios) return null;
    final n = aniosQueCumple(fecha, proxima(hoy));
    return n < 1 ? null : 'cumple ${n == 1 ? '1 año' : '$n años'}';
  }

  /// "Faltan 12 días" o "Faltan 12 días · cumple 30 años".
  String cuentaRegresiva(DateTime hoy) {
    final texto = textoCuentaRegresiva(diasRestantes(hoy), hoy: hoy);
    return switch (cumple(hoy)) {
      final c? => '$texto · $c',
      null => texto,
    };
  }

  /// Faltan 7 días o menos (y no ha pasado).
  bool esCercana(DateTime hoy) {
    final d = diasRestantes(hoy);
    return d >= 0 && d <= 7;
  }
}

/// Solo la fecha, en UTC para que el horario de verano no mueva la cuenta.
DateTime _soloFecha(DateTime f) => DateTime.utc(f.year, f.month, f.day);

/// Días de calendario de [desde] a [hasta] (ignora las horas).
int diasEntre(DateTime desde, DateTime hasta) =>
    _soloFecha(hasta).difference(_soloFecha(desde)).inDays;

/// La fecha [fecha] en el año [anio]; el 29 de febrero pasa al 28 si el año
/// no es bisiesto.
DateTime enAnio(DateTime fecha, int anio) {
  final ultimoDia = DateTime.utc(anio, fecha.month + 1, 0).day;
  return DateTime.utc(anio, fecha.month, fecha.day.clamp(1, ultimoDia));
}

/// Próxima vez que toca [fecha] contando desde [hoy] (incluido). Si es
/// [anual] pasa al año siguiente cuando ya pasó este año; si no, es la
/// misma fecha (puede estar en el pasado). Siempre en UTC sin hora.
DateTime proximaOcurrencia(DateTime fecha, DateTime hoy, {bool anual = false}) {
  if (!anual) return _soloFecha(fecha);
  final base = _soloFecha(hoy);
  final esteAnio = enAnio(fecha, hoy.year);
  return esteAnio.isBefore(base) ? enAnio(fecha, hoy.year + 1) : esteAnio;
}

/// Años que se cumplen en [ocurrencia] desde la fecha original.
int aniosQueCumple(DateTime original, DateTime ocurrencia) =>
    ocurrencia.year - original.year;

String _plural(int n, String singular, String plural) =>
    '$n ${n == 1 ? singular : plural}';

/// Texto de la cuenta regresiva según los [dias] que faltan:
/// "¡Hoy! 🎉", "Mañana", "Faltan 12 días", "En 3 meses", "En 1 año";
/// en el pasado, "Fue ayer" o "Hace 5 días".
///
/// Con 60 días o más se cuenta en meses de calendario a partir de [hoy].
String textoCuentaRegresiva(int dias, {DateTime? hoy}) {
  if (dias == 0) return '¡Hoy! 🎉';
  if (dias == 1) return 'Mañana';
  if (dias == -1) return 'Fue ayer';
  if (dias < 0) return 'Hace ${_plural(-dias, 'día', 'días')}';
  if (dias < 60) return 'Faltan $dias días';
  final desde = _soloFecha(hoy ?? DateTime.now());
  final t = tiempoJuntos(desde, desde.add(Duration(days: dias)));
  final meses = t.anios * 12 + t.meses;
  if (meses < 12) return 'En ${_plural(meses, 'mes', 'meses')}';
  return 'En ${_plural(meses ~/ 12, 'año', 'años')}';
}

/// Ordena por cercanía: primero las que vienen (la más próxima primero) y al
/// final las que ya pasaron (la más reciente primero).
List<FechaImportante> ordenarPorCercania(
  Iterable<FechaImportante> fechas,
  DateTime hoy,
) {
  int clave(FechaImportante f) {
    final d = f.diasRestantes(hoy);
    // Las pasadas van después de todas las que vienen.
    return d >= 0 ? d : 1000000 - d;
  }

  return fechas.toList()..sort((a, b) {
    final c = clave(a).compareTo(clave(b));
    return c != 0
        ? c
        : a.titulo.toLowerCase().compareTo(b.titulo.toLowerCase());
  });
}

/// La próxima fecha que aún no pasa, o null.
FechaImportante? siguienteFecha(
  Iterable<FechaImportante> fechas,
  DateTime hoy,
) {
  FechaImportante? mejor;
  for (final f in fechas) {
    final d = f.diasRestantes(hoy);
    if (d < 0) continue;
    if (mejor == null || d < mejor.diasRestantes(hoy)) mejor = f;
  }
  return mejor;
}

const _meses = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

/// "14 feb 2025", o "14 feb" con [conAnio] en false.
String formatoFecha(DateTime f, {bool conAnio = true}) =>
    '${f.day} ${_meses[f.month - 1]}${conAnio ? ' ${f.year}' : ''}';
