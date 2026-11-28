import 'dart:async';

import '../../listas/domain/detalles.dart';
import '../domain/musica_repository.dart';

/// Música en memoria, para pruebas y modo local.
class MemoriaMusicaRepository implements MusicaRepository {
  MemoriaMusicaRepository({required this.autor, DateTime Function()? reloj})
    : reloj = reloj ?? DateTime.now;

  final Autor? Function() autor;
  final DateTime Function() reloj;

  final _playlist = <String, CancionPlaylist>{};
  final _records = <String, RecordAdivina>{};
  final _cambios = StreamController<void>.broadcast();

  /// En modo local sin sesión se usa un autor fijo para poder probar.
  Autor get _yo => autor() ?? const Autor(uid: 'local', nombre: 'Yo');

  @override
  Autor? get autorActual => autor();

  Stream<T> _vigilar<T>(T Function() valor) async* {
    yield valor();
    yield* _cambios.stream.map((_) => valor());
  }

  @override
  Stream<List<CancionPlaylist>> watchPlaylist() => _vigilar(
    () =>
        _playlist.values.toList()
          ..sort((a, b) => b.agregadaEn.compareTo(a.agregadaEn)),
  );

  @override
  Future<bool> agregar(Cancion cancion) async {
    final id = cancion.clave;
    if (_playlist.containsKey(id) ||
        _playlist.values.any((c) => c.cancion.huella == cancion.huella)) {
      return false;
    }
    _playlist[id] = CancionPlaylist(
      id: id,
      cancion: cancion,
      agregadaEn: reloj(),
      agregadaPor: _yo,
    );
    _cambios.add(null);
    return true;
  }

  @override
  Future<void> quitar(String id) async {
    _playlist.remove(id);
    _cambios.add(null);
  }

  @override
  Future<void> alternarCorazon(String id) async {
    final c = _playlist[id];
    if (c == null) return;
    final corazones = {...c.corazones};
    if (!corazones.remove(_yo.uid)) corazones.add(_yo.uid);
    _playlist[id] = CancionPlaylist(
      id: c.id,
      cancion: c.cancion,
      agregadaEn: c.agregadaEn,
      agregadaPor: c.agregadaPor,
      corazones: corazones,
    );
    _cambios.add(null);
  }

  @override
  Stream<List<RecordAdivina>> watchRecords() => _vigilar(
    () => _records.values.toList()..sort((a, b) => b.mejor.compareTo(a.mejor)),
  );

  @override
  Future<void> guardarPartida(int aciertos) async {
    final yo = _yo;
    final antes = _records[yo.uid];
    _records[yo.uid] = RecordAdivina(
      autor: yo,
      mejor: antes == null || aciertos > antes.mejor ? aciertos : antes.mejor,
      partidas: (antes?.partidas ?? 0) + 1,
      ultimaEn: reloj(),
    );
    _cambios.add(null);
  }
}
