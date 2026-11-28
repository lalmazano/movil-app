/// Textos de fechas y cuentas regresivas para las cartas.
library;

String _dos(int n) => n.toString().padLeft(2, '0');

/// 14/02/2027
String fechaCorta(DateTime f) => '${_dos(f.day)}/${_dos(f.month)}/${f.year}';

/// 21:30
String horaCorta(DateTime f) => '${_dos(f.hour)}:${_dos(f.minute)}';

/// "3 días", "1 día", "5 horas", "1 hora" o "unos minutos".
String duracionAmable(Duration d) {
  if (d.inDays >= 1) return d.inDays == 1 ? '1 día' : '${d.inDays} días';
  if (d.inHours >= 1) return d.inHours == 1 ? '1 hora' : '${d.inHours} horas';
  if (d.inMinutes >= 2) return '${d.inMinutes} minutos';
  return 'unos minutos';
}

/// "faltan 12 días" / "falta 1 día".
String faltan(Duration d) {
  final texto = duracionAmable(d);
  final singular = texto.startsWith('1 ');
  return '${singular ? 'falta' : 'faltan'} $texto';
}
