import '../../michis/domain/michi.dart';
import '../../peso/domain/registro_peso.dart';
import '../../recuerdos/domain/recuerdo.dart';

export '../../peso/domain/registro_peso.dart' show RegistroPeso;

/// Un logro (insignia) que se desbloquea usando la app.
class Logro {
  const Logro({
    required this.id,
    required this.emoji,
    required this.titulo,
    required this.descripcion,
    required int actual,
    required this.meta,
  }) : actual = actual > meta ? meta : actual;

  final String id;
  final String emoji;
  final String titulo;
  final String descripcion;

  /// Avance actual (nunca mayor que [meta]).
  final int actual;
  final int meta;

  bool get desbloqueado => actual >= meta;

  /// Avance de 0.0 a 1.0.
  double get progreso => meta == 0 ? 1 : actual / meta;
}

/// Calcula todos los logros a partir de los datos de la app. Función pura: no
/// guarda nada, así que siempre refleja el estado actual.
///
/// Los recuerdos con fecha posterior a [hoy] no cuentan para la racha.
List<Logro> calcularLogros({
  required List<Michi> michis,
  required List<Recuerdo> recuerdos,
  required List<RegistroPeso> pesos,
  required DateTime hoy,
}) {
  final fotos = recuerdos.length;
  final mejorPerfil = michis.fold<int>(0, (mejor, m) {
    final campos =
        (m.fotoPath != null ? 1 : 0) + (m.nacimiento != null ? 1 : 0);
    return campos > mejor ? campos : mejor;
  });
  final idsMichis = {for (final m in michis) m.id};
  final fotografiados = recuerdos
      .map((r) => r.michiId)
      .where(idsMichis.contains)
      .toSet()
      .length;
  final fotoDeCumple = recuerdos.any((r) {
    final michi = michis.where((m) => m.id == r.michiId).firstOrNull;
    return michi != null && michi.esCumpleanos(r.fecha);
  });

  return [
    Logro(
      id: 'primer_recuerdo',
      emoji: '📸',
      titulo: 'Primer recuerdo',
      descripcion: 'Guarda tu primera foto con tu michi.',
      actual: fotos,
      meta: 1,
    ),
    Logro(
      id: 'fotografo_michi',
      emoji: '📷',
      titulo: 'Fotógrafo michi',
      descripcion: 'Guarda 10 fotos con tus michis.',
      actual: fotos,
      meta: 10,
    ),
    Logro(
      id: 'paparazzi_gatuno',
      emoji: '🎞️',
      titulo: 'Paparazzi gatuno',
      descripcion: 'Guarda 50 fotos. ¡Tu michi ya es una celebridad!',
      actual: fotos,
      meta: 50,
    ),
    Logro(
      id: 'purrfecto',
      emoji: '😻',
      titulo: '¡Purr-fecto!',
      descripcion: 'Califica una foto con 5 huellitas.',
      actual: recuerdos.any((r) => r.calificacion == 5) ? 1 : 0,
      meta: 1,
    ),
    Logro(
      id: 'critico_exigente',
      emoji: '😾',
      titulo: 'Crítico exigente',
      descripcion: 'Califica una foto con solo 1 huellita.',
      actual: recuerdos.any((r) => r.calificacion == 1) ? 1 : 0,
      meta: 1,
    ),
    Logro(
      id: 'racha_7_dias',
      emoji: '🔥',
      titulo: 'Racha de 7 días',
      descripcion: 'Toma fotos 7 días seguidos.',
      actual: rachaMasLarga(recuerdos.map((r) => r.fecha), hoy: hoy),
      meta: 7,
    ),
    Logro(
      id: 'familia_gatuna',
      emoji: '🐈🐈',
      titulo: 'Familia gatuna',
      descripcion: 'Registra 2 o más michis.',
      actual: michis.length,
      meta: 2,
    ),
    Logro(
      id: 'perfil_completo',
      emoji: '🪪',
      titulo: 'Perfil completo',
      descripcion: 'Ponle foto y fecha de nacimiento a un michi.',
      actual: mejorPerfil,
      meta: 2,
    ),
    Logro(
      id: 'todos_en_la_foto',
      emoji: '🎯',
      titulo: 'Todos en la foto',
      descripcion: 'Cada uno de tus michis sale en al menos un recuerdo.',
      actual: fotografiados,
      meta: michis.isEmpty ? 1 : michis.length,
    ),
    Logro(
      id: 'foto_de_cumple',
      emoji: '🎂',
      titulo: 'Foto de cumple',
      descripcion: 'Guarda una foto de un michi el día de su cumpleaños.',
      actual: fotoDeCumple ? 1 : 0,
      meta: 1,
    ),
    Logro(
      id: 'bascula_al_dia',
      emoji: '⚖️',
      titulo: 'Báscula al día',
      descripcion: 'Registra 3 pesajes.',
      actual: pesos.length,
      meta: 3,
    ),
  ];
}

/// Mayor cantidad de días de calendario consecutivos con al menos una fecha.
/// Varias fechas el mismo día cuentan una vez; las posteriores a [hoy] se
/// ignoran.
int rachaMasLarga(Iterable<DateTime> fechas, {required DateTime hoy}) {
  final limite = _dia(hoy);
  final dias = fechas.map(_dia).where((d) => d <= limite).toSet().toList()
    ..sort();
  var mejor = 0;
  var actual = 0;
  int? anterior;
  for (final d in dias) {
    actual = (anterior != null && d == anterior + 1) ? actual + 1 : 1;
    if (actual > mejor) mejor = actual;
    anterior = d;
  }
  return mejor;
}

/// Número de día de calendario (independiente de la hora y del horario de
/// verano).
int _dia(DateTime f) =>
    DateTime.utc(f.year, f.month, f.day).millisecondsSinceEpoch ~/
    Duration.millisecondsPerDay;
