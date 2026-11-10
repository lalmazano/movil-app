/// Qué cuidado hay que recordar.
enum TipoRecordatorio {
  vacuna('Vacuna', '💉'),
  desparasitacion('Desparasitación', '🛡️'),
  comida('Comida', '🍗'),
  arenero('Arenero', '🧹'),
  medicina('Medicina', '💊'),
  otro('Otro', '🐾');

  const TipoRecordatorio(this.etiqueta, this.emoji);

  final String etiqueta;
  final String emoji;

  static TipoRecordatorio desdeNombre(String? nombre) => values.firstWhere(
    (t) => t.name == nombre,
    orElse: () => TipoRecordatorio.otro,
  );
}

/// Cada cuánto se repite un recordatorio.
enum Repeticion {
  unaVez('Una vez'),
  diario('Cada día'),
  semanal('Cada semana'),
  mensual('Cada mes');

  const Repeticion(this.etiqueta);

  final String etiqueta;

  static Repeticion desdeNombre(String? nombre) => values.firstWhere(
    (r) => r.name == nombre,
    orElse: () => Repeticion.unaVez,
  );
}

/// Un recordatorio de cuidado para un michi (o para todos).
class Recordatorio {
  const Recordatorio({
    required this.id,
    required this.tipo,
    required this.titulo,
    required this.fecha,
    this.michiId,
    this.repeticion = Repeticion.unaVez,
    this.activo = true,
  });

  final String id;
  final TipoRecordatorio tipo;
  final String titulo;

  /// Michi al que se refiere (id de `Michi`), o null si es para todos.
  final String? michiId;

  /// Primera fecha y hora (hora local). Las repeticiones toman de aquí la
  /// hora, el día de la semana o el día del mes.
  final DateTime fecha;
  final Repeticion repeticion;
  final bool activo;

  /// Id entero y estable para la notificación del sistema (31 bits).
  int get idNotificacion => idNotificacionDe(id);

  /// Siguiente vez que debe sonar estrictamente después de [ahora], o null si
  /// ya no volverá a sonar (recordatorio de una vez ya pasado).
  ///
  /// No tiene en cuenta [activo]: un recordatorio apagado sigue teniendo
  /// próxima fecha, solo que no se notifica.
  DateTime? proximaOcurrencia(DateTime ahora) {
    if (fecha.isAfter(ahora)) return fecha;
    final h = fecha.hour;
    final m = fecha.minute;
    switch (repeticion) {
      case Repeticion.unaVez:
        return null;
      case Repeticion.diario:
        var c = DateTime(ahora.year, ahora.month, ahora.day, h, m);
        if (!c.isAfter(ahora)) c = DateTime(c.year, c.month, c.day + 1, h, m);
        return c;
      case Repeticion.semanal:
        final dias = (fecha.weekday - ahora.weekday) % 7;
        var c = DateTime(ahora.year, ahora.month, ahora.day + dias, h, m);
        if (!c.isAfter(ahora)) c = DateTime(c.year, c.month, c.day + 7, h, m);
        return c;
      case Repeticion.mensual:
        // Igual que el sistema: los meses que no tienen ese día se saltan.
        final dia = fecha.day;
        for (var i = 0; i < 24; i++) {
          final c = DateTime(ahora.year, ahora.month + i, dia, h, m);
          if (c.day != dia) continue;
          if (c.isAfter(ahora)) return c;
        }
        return null;
    }
  }

  Recordatorio copyWith({
    TipoRecordatorio? tipo,
    String? titulo,
    String? Function()? michiId,
    DateTime? fecha,
    Repeticion? repeticion,
    bool? activo,
  }) => Recordatorio(
    id: id,
    tipo: tipo ?? this.tipo,
    titulo: titulo ?? this.titulo,
    michiId: michiId != null ? michiId() : this.michiId,
    fecha: fecha ?? this.fecha,
    repeticion: repeticion ?? this.repeticion,
    activo: activo ?? this.activo,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'tipo': tipo.name,
    'titulo': titulo,
    'michiId': michiId,
    'fecha': fecha.toIso8601String(),
    'repeticion': repeticion.name,
    'activo': activo,
  };

  factory Recordatorio.fromJson(Map<String, dynamic> d) => Recordatorio(
    id: d['id'] as String,
    tipo: TipoRecordatorio.desdeNombre(d['tipo'] as String?),
    titulo: d['titulo'] as String? ?? '',
    michiId: d['michiId'] as String?,
    fecha: DateTime.parse(d['fecha'] as String),
    repeticion: Repeticion.desdeNombre(d['repeticion'] as String?),
    activo: d['activo'] as bool? ?? true,
  );
}

/// Hash FNV-1a de 31 bits: el mismo id siempre da el mismo número (a
/// diferencia de `String.hashCode`, que no está garantizado entre ejecuciones).
int idNotificacionDe(String id) {
  var hash = 0x811c9dc5;
  for (final c in id.codeUnits) {
    hash ^= c;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash & 0x7fffffff;
}

/// Título y cuerpo de la notificación, con sabor gatuno.
({String titulo, String cuerpo}) textoNotificacion(
  Recordatorio r, {
  String? nombreMichi,
}) {
  final de = nombreMichi == null ? ' michi' : ' de $nombreMichi';
  final para = nombreMichi == null ? ' tu michi' : ' $nombreMichi';
  final titulo = switch (r.tipo) {
    TipoRecordatorio.comida => '🐱 ¡Hora de la comida$de!',
    TipoRecordatorio.arenero => '🧹 ¡A limpiar el arenero$de!',
    TipoRecordatorio.vacuna => '💉 ¡Toca vacuna para$para!',
    TipoRecordatorio.desparasitacion => '🛡️ ¡Toca desparasitar a$para!',
    TipoRecordatorio.medicina => '💊 ¡Hora de la medicina$de!',
    TipoRecordatorio.otro =>
      nombreMichi == null
          ? '🐾 ¡Miau! Recordatorio michi'
          : '🐾 ¡Miau! Recordatorio para $nombreMichi',
  };
  final cuerpo = r.titulo.trim().isEmpty
      ? 'Tu michi cuenta contigo 😸'
      : '${r.titulo.trim()} 🐾';
  return (titulo: titulo, cuerpo: cuerpo);
}

/// Contrato para guardar y leer recordatorios.
abstract interface class RecordatorioRepository {
  /// Todos los recordatorios, ordenados por fecha.
  Future<List<Recordatorio>> getAll();

  /// Crea o reemplaza (por id) un recordatorio.
  Future<void> guardar(Recordatorio recordatorio);

  Future<void> delete(String id);
}
