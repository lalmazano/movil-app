/// Una foto guardada con el michi, con su calificación.
class Recuerdo {
  const Recuerdo({
    required this.id,
    required this.imagePath,
    required this.fecha,
    required this.calificacion,
    this.nota = '',
  }) : assert(calificacion >= 1 && calificacion <= 5);

  final String id;
  final String imagePath;
  final DateTime fecha;

  /// De 1 a 5 huellitas.
  final int calificacion;
  final String nota;

  Recuerdo copyWith({int? calificacion, String? nota}) => Recuerdo(
    id: id,
    imagePath: imagePath,
    fecha: fecha,
    calificacion: calificacion ?? this.calificacion,
    nota: nota ?? this.nota,
  );
}

/// Contrato para guardar y leer recuerdos.
abstract interface class RecuerdoRepository {
  /// Todos los recuerdos, del más reciente al más antiguo.
  Future<List<Recuerdo>> getAll();

  /// Copia la foto en [sourcePath] al almacenamiento de la app y la guarda.
  Future<Recuerdo> add({
    required String sourcePath,
    required int calificacion,
    String nota = '',
  });

  Future<void> update(Recuerdo recuerdo);

  Future<void> delete(String id);
}

/// Texto divertido para cada calificación.
String etiquetaCalificacion(int calificacion) => switch (calificacion) {
  1 => 'Miau... 😿',
  2 => 'Meh-au 😾',
  3 => 'Ronroneable 😺',
  4 => '¡Michi-genial! 😸',
  _ => '¡Purr-fecto! 😻',
};
