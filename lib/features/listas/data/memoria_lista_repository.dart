import 'dart:async';

import '../domain/config_club.dart';
import '../domain/item_lista.dart';

/// Repositorio en memoria: para pruebas o cuando Firebase no está configurado.
class MemoriaListaRepository implements ListaRepository {
  MemoriaListaRepository({
    DateTime Function()? reloj,
    this.config = const ConfigClub(),
  }) : _reloj = reloj ?? DateTime.now;

  final ConfigClub config;

  final DateTime Function() _reloj;
  final _datos = {for (final t in TipoLista.values) t: <ItemLista>[]};
  final _cambios = StreamController<TipoLista>.broadcast();
  var _siguienteId = 0;

  @override
  bool get enLaNube => false;

  @override
  Stream<ConfigClub> watchConfig() => Stream.value(config);

  @override
  Stream<List<ItemLista>> watch(TipoLista tipo) async* {
    yield List.unmodifiable(_datos[tipo]!);
    yield* _cambios.stream
        .where((t) => t == tipo)
        .map((_) => List.unmodifiable(_datos[tipo]!));
  }

  @override
  Future<void> add(TipoLista tipo, NuevoItem item) => addMany(tipo, [item]);

  @override
  Future<void> addMany(TipoLista tipo, List<NuevoItem> items) async {
    for (final item in items) {
      _datos[tipo]!.add(
        ItemLista(
          id: '${_siguienteId++}',
          titulo: item.titulo,
          categoria: item.categoria,
          nota: item.nota,
          creadoEn: _reloj(),
        ),
      );
    }
    _cambios.add(tipo);
  }

  @override
  Future<void> update(TipoLista tipo, ItemLista item) async {
    final lista = _datos[tipo]!;
    final i = lista.indexWhere((e) => e.id == item.id);
    if (i >= 0) lista[i] = item;
    _cambios.add(tipo);
  }

  @override
  Future<void> setHecho(TipoLista tipo, String id, bool hecho) async {
    final lista = _datos[tipo]!;
    final i = lista.indexWhere((e) => e.id == id);
    if (i < 0) return;
    lista[i] = lista[i].copyWith(
      hecho: hecho,
      hechoEn: () => hecho ? _reloj() : null,
    );
    _cambios.add(tipo);
  }

  @override
  Future<void> delete(TipoLista tipo, String id) async {
    _datos[tipo]!.removeWhere((e) => e.id == id);
    _cambios.add(tipo);
  }
}
