/// Un pesaje de un michi en una fecha.
class RegistroPeso {
  const RegistroPeso({
    required this.id,
    required this.michiId,
    required this.fecha,
    required this.kg,
    this.nota = '',
  });

  final String id;

  /// Id del `Michi` pesado.
  final String michiId;
  final DateTime fecha;

  /// Peso en kilogramos (redondeado a 2 decimales).
  final double kg;
  final String nota;
}

/// Contrato para guardar y leer pesajes.
abstract interface class PesoRepository {
  /// Todos los registros, ordenados por fecha (del más antiguo al más nuevo).
  Future<List<RegistroPeso>> getAll();

  /// Registros de un michi, ordenados por fecha ascendente.
  Future<List<RegistroPeso>> deMichi(String michiId);

  Future<RegistroPeso> add({
    required String michiId,
    required DateTime fecha,
    required double kg,
    String nota = '',
  });

  Future<void> delete(String id);
}

/// Peso mínimo y máximo aceptados (kg).
const double pesoMinimoKg = 0.1;
const double pesoMaximoKg = 30;

/// Redondea a 2 decimales.
double redondearKg(double kg) => (kg * 100).round() / 100;

/// Convierte el texto a número (coma o punto decimal), o null si no se puede.
double? parsearPeso(String? texto) {
  final limpio = texto?.trim().replaceAll(',', '.') ?? '';
  if (limpio.isEmpty) return null;
  return double.tryParse(limpio);
}

/// Valida un texto de kilos. Devuelve un mensaje de error o null si es válido.
String? validarPeso(String? texto) {
  final valor = parsearPeso(texto);
  if (valor == null) return 'Escribe un peso, p. ej. 4.25 🐾';
  if (valor < pesoMinimoKg || valor > pesoMaximoKg) {
    return 'Debe estar entre 0.1 y 30 kg 🙀';
  }
  return null;
}

/// Diferencia entre el último pesaje y el anterior.
class CambioPeso {
  const CambioPeso({required this.ultimo, this.anterior});

  final RegistroPeso ultimo;
  final RegistroPeso? anterior;

  /// Diferencia en kg (último − anterior), o null si solo hay un registro.
  double? get diferencia =>
      anterior == null ? null : redondearKg(ultimo.kg - anterior!.kg);

  /// Texto como "↑ 0.25 kg 🍗", "↓ 0.10 kg 🏃" o "= sin cambios 😺".
  String? get descripcion {
    final d = diferencia;
    if (d == null) return null;
    if (d > 0) return '↑ ${d.toStringAsFixed(2)} kg 🍗';
    if (d < 0) return '↓ ${(-d).toStringAsFixed(2)} kg 🏃';
    return '= sin cambios 😺';
  }
}

/// Calcula el cambio de peso a partir de registros en cualquier orden.
/// Devuelve null si no hay registros.
CambioPeso? calcularCambioPeso(List<RegistroPeso> registros) {
  if (registros.isEmpty) return null;
  final orden = ordenarPorFecha(registros);
  return CambioPeso(
    ultimo: orden.last,
    anterior: orden.length > 1 ? orden[orden.length - 2] : null,
  );
}

/// Copia de [registros] ordenada por fecha ascendente (orden estable).
List<RegistroPeso> ordenarPorFecha(List<RegistroPeso> registros) {
  final indexados = registros.indexed.toList()
    ..sort((a, b) {
      final c = a.$2.fecha.compareTo(b.$2.fecha);
      return c != 0 ? c : a.$1.compareTo(b.$1);
    });
  return [for (final (_, r) in indexados) r];
}
