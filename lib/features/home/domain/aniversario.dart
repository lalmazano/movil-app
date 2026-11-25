/// Cuánto tiempo llevamos juntos, en años, meses y días de calendario.
class TiempoJuntos {
  const TiempoJuntos({
    required this.anios,
    required this.meses,
    required this.dias,
    required this.totalDias,
  });

  final int anios;
  final int meses;
  final int dias;

  /// Días totales desde la fecha; negativo si la fecha aún no llega.
  final int totalDias;

  bool get esFuturo => totalDias < 0;

  @override
  bool operator ==(Object other) =>
      other is TiempoJuntos &&
      other.anios == anios &&
      other.meses == meses &&
      other.dias == dias &&
      other.totalDias == totalDias;

  @override
  int get hashCode => Object.hash(anios, meses, dias, totalDias);

  @override
  String toString() =>
      'TiempoJuntos($anios años, $meses meses, $dias días; $totalDias)';
}

/// Solo la fecha (sin hora), en UTC para que el cambio de horario no mueva
/// la cuenta de días.
DateTime _soloFecha(DateTime f) => DateTime.utc(f.year, f.month, f.day);

int _diasDelMes(int anio, int mes) => DateTime.utc(anio, mes + 1, 0).day;

/// Suma [meses] a [fecha]; si el día no existe en el mes destino, usa el
/// último día del mes (31 ene + 1 mes = 28 o 29 feb).
DateTime _sumarMeses(DateTime fecha, int meses) {
  final indice = fecha.year * 12 + (fecha.month - 1) + meses;
  final anio = indice ~/ 12;
  final mes = indice % 12 + 1;
  final dia = fecha.day.clamp(1, _diasDelMes(anio, mes));
  return DateTime.utc(anio, mes, dia);
}

/// Tiempo de calendario entre [desde] y [hoy] (solo cuentan las fechas, no
/// las horas). Si [desde] es posterior a [hoy], los años, meses y días se
/// calculan al revés (lo que falta) y [TiempoJuntos.totalDias] es negativo.
TiempoJuntos tiempoJuntos(DateTime desde, DateTime hoy) {
  final inicio = _soloFecha(desde);
  final fin = _soloFecha(hoy);
  final totalDias = fin.difference(inicio).inDays;
  final (a, b) = totalDias < 0 ? (fin, inicio) : (inicio, fin);

  var meses = (b.year - a.year) * 12 + (b.month - a.month);
  var corte = _sumarMeses(a, meses);
  if (corte.isAfter(b)) {
    meses--;
    corte = _sumarMeses(a, meses);
  }
  return TiempoJuntos(
    anios: meses ~/ 12,
    meses: meses % 12,
    dias: b.difference(corte).inDays,
    totalDias: totalDias,
  );
}

String _plural(int n, String singular, String plural) =>
    '$n ${n == 1 ? singular : plural}';

String _dias(int n) => _plural(n, 'día', 'días');

/// Frase completa: "Llevamos 1 año, 3 meses y 12 días juntos 🫘".
String textoAniversario(DateTime desde, DateTime hoy) {
  final t = tiempoJuntos(desde, hoy);
  if (t.totalDias == 0) return '¡Hoy empieza todo! 🫘';
  if (t.esFuturo) return _textoFalta(-t.totalDias);
  final partes = [
    if (t.anios > 0) _plural(t.anios, 'año', 'años'),
    if (t.meses > 0) _plural(t.meses, 'mes', 'meses'),
    if (t.dias > 0) _dias(t.dias),
  ];
  final juntas = partes.length == 1
      ? partes.single
      : '${partes.sublist(0, partes.length - 1).join(', ')} y ${partes.last}';
  return 'Llevamos $juntas juntos 🫘';
}

/// Frase corta: "457 días juntos 🫘".
String textoDiasJuntos(DateTime desde, DateTime hoy) {
  final total = tiempoJuntos(desde, hoy).totalDias;
  if (total == 0) return '¡Hoy empieza todo! 🫘';
  if (total < 0) return _textoFalta(-total);
  return '${_dias(total)} juntos 🫘';
}

String _textoFalta(int dias) =>
    '${dias == 1 ? 'Falta' : 'Faltan'} ${_dias(dias)} 🫘';
