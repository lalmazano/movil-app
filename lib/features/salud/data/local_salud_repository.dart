import '../../../core/storage/json_store.dart';
import '../domain/entrada_salud.dart';

class LocalSaludRepository implements SaludRepository {
  LocalSaludRepository({BaseDir? baseDir})
    : _store = JsonStore(carpeta: 'salud', archivo: 'diario', baseDir: baseDir);

  final JsonStore _store;

  Future<List<EntradaSalud>> _leer() async => [
    for (final d in await _store.leer()) EntradaSalud.fromJson(d),
  ];

  Future<void> _escribir(List<EntradaSalud> todas) =>
      _store.escribir([for (final e in todas) e.toJson()]);

  @override
  Future<List<EntradaSalud>> getAll() async =>
      (await _leer())..sort((a, b) => b.fecha.compareTo(a.fecha));

  @override
  Future<void> guardar(EntradaSalud entrada) async {
    final todas = await _leer();
    final i = todas.indexWhere((e) => e.id == entrada.id);
    if (i == -1) {
      todas.add(entrada);
    } else {
      todas[i] = entrada;
    }
    await _escribir(todas);
  }

  @override
  Future<void> delete(String id) async {
    final todas = await _leer();
    await _escribir(todas.where((e) => e.id != id).toList());
  }
}
