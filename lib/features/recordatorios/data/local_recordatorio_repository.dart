import '../../../core/storage/json_store.dart';
import '../domain/recordatorio.dart';

class LocalRecordatorioRepository implements RecordatorioRepository {
  LocalRecordatorioRepository({BaseDir? baseDir})
    : _store = JsonStore(
        carpeta: 'recordatorios',
        archivo: 'recordatorios',
        baseDir: baseDir,
      );

  final JsonStore _store;

  Future<List<Recordatorio>> _leer() async => [
    for (final d in await _store.leer()) Recordatorio.fromJson(d),
  ];

  Future<void> _escribir(List<Recordatorio> todos) =>
      _store.escribir([for (final r in todos) r.toJson()]);

  @override
  Future<List<Recordatorio>> getAll() async =>
      (await _leer())..sort((a, b) => a.fecha.compareTo(b.fecha));

  @override
  Future<void> guardar(Recordatorio recordatorio) async {
    final todos = await _leer();
    final i = todos.indexWhere((r) => r.id == recordatorio.id);
    if (i == -1) {
      todos.add(recordatorio);
    } else {
      todos[i] = recordatorio;
    }
    await _escribir(todos);
  }

  @override
  Future<void> delete(String id) async {
    final todos = await _leer();
    await _escribir(todos.where((r) => r.id != id).toList());
  }
}
