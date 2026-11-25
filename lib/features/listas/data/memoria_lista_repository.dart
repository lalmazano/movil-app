import 'dart:async';
import 'dart:typed_data';

import '../domain/config_club.dart';
import '../domain/item_lista.dart';

/// Repositorio en memoria: para pruebas o cuando Firebase no está configurado.
class MemoriaListaRepository implements ListaRepository {
  MemoriaListaRepository({
    DateTime Function()? reloj,
    this.config = const ConfigClub(),
    this.categorias = const {},
    this.autorActual,
    this.apiKeyTmdb,
  }) : _reloj = reloj ?? DateTime.now;

  @override
  final Autor? autorActual;

  final String? apiKeyTmdb;
  final _fotos = <String, List<FotoItem>>{};

  final ConfigClub config;

  /// Categorías por lista; si falta una, se usan las de la app.
  final Map<TipoLista, List<String>> categorias;

  final DateTime Function() _reloj;
  final _datos = {for (final t in TipoLista.values) t: <ItemLista>[]};
  final _cambios = StreamController<TipoLista>.broadcast();
  var _siguienteId = 0;

  @override
  bool get enLaNube => false;

  @override
  Future<void> inicializar() async {}

  @override
  Stream<List<String>> watchCategorias(TipoLista tipo) =>
      Stream.value(categorias[tipo] ?? tipo.categorias);

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
  Future<void> add(
    TipoLista tipo,
    NuevoItem item, {
    InfoPelicula? pelicula,
  }) async {
    _datos[tipo]!.add(_nuevo(item, pelicula));
    _cambios.add(tipo);
  }

  ItemLista _nuevo(NuevoItem item, [InfoPelicula? pelicula]) => ItemLista(
    id: '${_siguienteId++}',
    titulo: item.titulo,
    categoria: item.categoria,
    nota: item.nota,
    creadoEn: _reloj(),
    creadoPor: autorActual,
    pelicula: pelicula,
  );

  @override
  Future<void> addMany(TipoLista tipo, List<NuevoItem> items) async {
    for (final item in items) {
      _datos[tipo]!.add(_nuevo(item));
    }
    _cambios.add(tipo);
  }

  void _cambiar(TipoLista tipo, String id, ItemLista Function(ItemLista) f) {
    final lista = _datos[tipo]!;
    final i = lista.indexWhere((e) => e.id == id);
    if (i < 0) return;
    lista[i] = f(lista[i]);
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
      hechoPor: () => hecho ? autorActual : null,
    );
    _cambios.add(tipo);
  }

  @override
  Future<void> calificar(
    TipoLista tipo,
    String id,
    Calificacion calificacion,
  ) async => _cambiar(
    tipo,
    id,
    (i) => i.copyWith(
      calificaciones: {
        ...i.calificaciones,
        calificacion.autor.uid: Calificacion(
          autor: calificacion.autor,
          huellitas: calificacion.huellitas,
          comentario: calificacion.comentario,
          fecha: _reloj(),
        ),
      },
    ),
  );

  @override
  Future<void> delete(TipoLista tipo, String id) async {
    _datos[tipo]!.removeWhere((e) => e.id == id);
    _fotos.remove('${tipo.name}/$id');
    _cambios.add(tipo);
  }

  ItemLista? _buscar(TipoLista tipo, String id) {
    for (final i in _datos[tipo]!) {
      if (i.id == id) return i;
    }
    return null;
  }

  @override
  Stream<ItemLista?> watchItem(TipoLista tipo, String id) =>
      watch(tipo).map((_) => _buscar(tipo, id));

  @override
  Stream<List<FotoItem>> watchFotos(TipoLista tipo, String id) => watch(tipo)
      .map((_) => List.unmodifiable(_fotos['${tipo.name}/$id'] ?? const []));

  @override
  Future<void> agregarFoto(TipoLista tipo, String id, Uint8List bytes) async {
    if (bytes.length > maxBytesFoto) {
      throw ArgumentError('La foto pesa más de $maxBytesFoto bytes');
    }
    (_fotos['${tipo.name}/$id'] ??= []).add(
      FotoItem(
        id: '${_siguienteId++}',
        bytes: bytes,
        creadoEn: _reloj(),
        autor: autorActual,
      ),
    );
    _cambiar(tipo, id, (i) => i.copyWith(fotos: i.fotos + 1));
  }

  @override
  Future<void> borrarFoto(TipoLista tipo, String id, String fotoId) async {
    _fotos['${tipo.name}/$id']?.removeWhere((f) => f.id == fotoId);
    _cambiar(tipo, id, (i) => i.copyWith(fotos: i.fotos - 1));
  }

  @override
  Future<String?> tmdbApiKey() async => apiKeyTmdb;
}
