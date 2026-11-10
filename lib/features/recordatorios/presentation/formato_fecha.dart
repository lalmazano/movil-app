const _dias = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
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

String _dos(int n) => n.toString().padLeft(2, '0');

/// "mar 11 nov 2026".
String fechaCorta(DateTime f) =>
    '${_dias[f.weekday - 1]} ${f.day} ${_meses[f.month - 1]} ${f.year}';

/// "08:30".
String horaCorta(DateTime f) => '${_dos(f.hour)}:${_dos(f.minute)}';

/// "mar 11 nov 2026 · 08:30".
String fechaHora(DateTime f) => '${fechaCorta(f)} · ${horaCorta(f)}';

/// Convierte "12,5" o "12.50" en número; null si está vacío o no es válido.
double? leerCosto(String texto) {
  final limpio = texto.trim().replaceAll(',', '.');
  if (limpio.isEmpty) return null;
  return double.tryParse(limpio);
}

/// "12.50" sin ceros de más ("12" si es entero).
String formatearCosto(double c) =>
    c == c.roundToDouble() ? c.toStringAsFixed(0) : c.toStringAsFixed(2);
