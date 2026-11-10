import '../../domain/michi.dart';

/// Emojis que se pueden elegir para representar a un michi.
const emojisMichi = ['🐱', '😺', '🐈', '🐈‍⬛', '🦁', '🐯'];

/// Edad legible ("3 años", "5 meses"...), o null si no hay nacimiento.
String? describirEdad(Michi michi, DateTime hoy) {
  final n = michi.nacimiento;
  final anios = michi.edad(hoy);
  if (n == null || anios == null) return null;
  if (anios >= 1) return anios == 1 ? '1 año' : '$anios años';
  final meses =
      (hoy.year - n.year) * 12 +
      hoy.month -
      n.month -
      (hoy.day < n.day ? 1 : 0);
  if (meses <= 0) return 'Recién nacido 🍼';
  return meses == 1 ? '1 mes' : '$meses meses';
}

/// Fecha corta dd/mm/aaaa.
String formatearDia(DateTime f) {
  String dos(int n) => n.toString().padLeft(2, '0');
  return '${dos(f.day)}/${dos(f.month)}/${f.year}';
}
