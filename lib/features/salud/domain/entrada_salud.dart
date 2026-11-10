/// Tipo de entrada del diario de salud.
enum TipoSalud {
  visitaVeterinario('Visita al veterinario', '🩺'),
  vacuna('Vacuna', '💉'),
  medicina('Medicina', '💊'),
  sintoma('Síntoma / nota', '📝');

  const TipoSalud(this.etiqueta, this.emoji);

  final String etiqueta;
  final String emoji;

  static TipoSalud desdeNombre(String? nombre) => values.firstWhere(
    (t) => t.name == nombre,
    orElse: () => TipoSalud.sintoma,
  );
}

/// Una anotación en el diario de salud de un michi.
class EntradaSalud {
  const EntradaSalud({
    required this.id,
    required this.tipo,
    required this.fecha,
    required this.titulo,
    this.michiId,
    this.notas = '',
    this.costo,
  });

  final String id;
  final TipoSalud tipo;
  final DateTime fecha;
  final String titulo;

  /// Michi al que pertenece (id de `Michi`), o null si no se indicó.
  final String? michiId;
  final String notas;

  /// Costo opcional (veterinario, medicina…).
  final double? costo;

  Map<String, dynamic> toJson() => {
    'id': id,
    'tipo': tipo.name,
    'fecha': fecha.toIso8601String(),
    'titulo': titulo,
    'michiId': michiId,
    'notas': notas,
    'costo': costo,
  };

  factory EntradaSalud.fromJson(Map<String, dynamic> d) => EntradaSalud(
    id: d['id'] as String,
    tipo: TipoSalud.desdeNombre(d['tipo'] as String?),
    fecha: DateTime.parse(d['fecha'] as String),
    titulo: d['titulo'] as String? ?? '',
    michiId: d['michiId'] as String?,
    notas: d['notas'] as String? ?? '',
    costo: (d['costo'] as num?)?.toDouble(),
  );
}

/// Filtra [entradas] por michi y tipo (null = sin filtro).
List<EntradaSalud> filtrarEntradas(
  List<EntradaSalud> entradas, {
  String? michiId,
  TipoSalud? tipo,
}) => [
  for (final e in entradas)
    if ((michiId == null || e.michiId == michiId) &&
        (tipo == null || e.tipo == tipo))
      e,
];

/// Contrato para guardar y leer el diario de salud.
abstract interface class SaludRepository {
  /// Todas las entradas, de la más reciente a la más antigua.
  Future<List<EntradaSalud>> getAll();

  /// Crea o reemplaza (por id) una entrada.
  Future<void> guardar(EntradaSalud entrada);

  Future<void> delete(String id);
}
