/// Persona que inició sesión.
class Usuario {
  const Usuario({required this.id, this.nombre, this.correo, this.fotoUrl});

  final String id;
  final String? nombre;
  final String? correo;
  final String? fotoUrl;

  String get nombreCorto =>
      (nombre?.trim().isNotEmpty ?? false) ? nombre!.split(' ').first : 'Hola';
}

/// Inicio de sesión del club.
abstract interface class AuthService {
  Usuario? get actual;

  /// Emite el usuario cada vez que entra o sale.
  Stream<Usuario?> get cambios;

  /// Devuelve false si la persona canceló.
  Future<bool> entrarConGoogle();

  Future<void> salir();
}
