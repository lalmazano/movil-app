import '../../../core/storage/json_store.dart';
import '../domain/registro_peso.dart';

class LocalPesoRepository implements PesoRepository {
  LocalPesoRepository({BaseDir? baseDir})
    : _store = JsonStore(carpeta: 'peso', archivo: 'pesos', baseDir: baseDir);

  final JsonStore _store;

  Future<List<RegistroPeso>> _leer() async => [
    for (final d in await _store.leer())
      RegistroPeso(
        id: d['id'] as String,
        michiId: d['michiId'] as String,
        fecha: DateTime.parse(d['fecha'] as String),
        kg: (d['kg'] as num).toDouble(),
        nota: d['nota'] as String? ?? '',
      ),
  ];

  Future<void> _escribir(List<RegistroPeso> registros) => _store.escribir([
    for (final r in registros)
      {
        'id': r.id,
        'michiId': r.michiId,
        'fecha': r.fecha.toIso8601String(),
        'kg': r.kg,
        'nota': r.nota,
      },
  ]);

  @override
  Future<List<RegistroPeso>> getAll() async => ordenarPorFecha(await _leer());

  @override
  Future<List<RegistroPeso>> deMichi(String michiId) async =>
      (await getAll()).where((r) => r.michiId == michiId).toList();

  @override
  Future<RegistroPeso> add({
    required String michiId,
    required DateTime fecha,
    required double kg,
    String nota = '',
  }) async {
    final registro = RegistroPeso(
      id: nuevoId(),
      michiId: michiId,
      fecha: fecha,
      kg: redondearKg(kg),
      nota: nota.trim(),
    );
    await _escribir([...await _leer(), registro]);
    return registro;
  }

  @override
  Future<void> delete(String id) async =>
      _escribir((await _leer()).where((r) => r.id != id).toList());
}
