/// Perfil de un gato de la casa.
class Michi {
  const Michi({
    required this.id,
    required this.nombre,
    this.fotoPath,
    this.nacimiento,
    this.raza = '',
    this.emoji = '🐱',
  });

  final String id;
  final String nombre;

  /// Foto de perfil (ruta absoluta en el dispositivo) o null.
  final String? fotoPath;
  final DateTime? nacimiento;
  final String raza;

  /// Emoji que lo representa cuando no hay foto.
  final String emoji;

  /// Edad en años cumplidos a la fecha [hoy], o null si no hay nacimiento.
  int? edad(DateTime hoy) {
    final n = nacimiento;
    if (n == null) return null;
    var anios = hoy.year - n.year;
    if (hoy.month < n.month || (hoy.month == n.month && hoy.day < n.day)) {
      anios--;
    }
    return anios;
  }

  /// True si [hoy] es su cumpleaños.
  bool esCumpleanos(DateTime hoy) =>
      nacimiento != null &&
      nacimiento!.month == hoy.month &&
      nacimiento!.day == hoy.day;

  Michi copyWith({
    String? nombre,
    String? Function()? fotoPath,
    DateTime? Function()? nacimiento,
    String? raza,
    String? emoji,
  }) => Michi(
    id: id,
    nombre: nombre ?? this.nombre,
    fotoPath: fotoPath != null ? fotoPath() : this.fotoPath,
    nacimiento: nacimiento != null ? nacimiento() : this.nacimiento,
    raza: raza ?? this.raza,
    emoji: emoji ?? this.emoji,
  );
}

/// Contrato para guardar y leer michis.
abstract interface class MichiRepository {
  /// Todos los michis, en orden de creación.
  Future<List<Michi>> getAll();

  /// Guarda un michi nuevo. Si [fotoOrigen] no es null, copia esa foto a la
  /// carpeta de la app y la usa como foto de perfil.
  Future<Michi> add({
    required String nombre,
    String? fotoOrigen,
    DateTime? nacimiento,
    String raza = '',
    String emoji = '🐱',
  });

  /// Actualiza los datos. Si [fotoOrigen] no es null, reemplaza la foto.
  Future<Michi> update(Michi michi, {String? fotoOrigen});

  Future<void> delete(String id);
}
