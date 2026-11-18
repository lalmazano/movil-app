import 'package:flutter_test/flutter_test.dart';
import 'package:movil_app/features/listas/data/catalogo_disney.dart';
import 'package:movil_app/features/listas/data/datos_iniciales.dart';
import 'package:movil_app/features/listas/data/memoria_lista_repository.dart';
import 'package:movil_app/features/listas/domain/config_club.dart';
import 'package:movil_app/features/listas/domain/item_lista.dart';

void main() {
  test('El catálogo usa solo categorías de películas y no repite', () {
    final titulos = <String>{};
    for (final MapEntry(:key, :value) in catalogoDisney.entries) {
      expect(TipoLista.peliculas.categorias, contains(key));
      for (final t in value) {
        expect(titulos.add(t.toLowerCase()), isTrue, reason: t);
      }
    }
  });

  test('peliculasFaltantes omite las que ya están', () {
    final actuales = [
      ItemLista(
        id: '1',
        titulo: 'coco',
        categoria: 'Pixar',
        creadoEn: DateTime(2026),
      ),
    ];
    final faltantes = peliculasFaltantes(actuales);
    expect(faltantes.any((f) => f.titulo == 'Coco'), isFalse);
    expect(faltantes.any((f) => f.titulo == 'Toy Story'), isTrue);
  });

  test('Repositorio en memoria: agregar, marcar, editar y borrar', () async {
    final repo = MemoriaListaRepository(reloj: () => DateTime(2026, 11, 18));
    await repo.add(TipoLista.deseos, (
      titulo: 'Ir a la playa',
      categoria: 'Viajes',
      nota: '',
    ));
    var items = await repo.watch(TipoLista.deseos).first;
    expect(items.single.hecho, isFalse);

    await repo.setHecho(TipoLista.deseos, items.single.id, true);
    items = await repo.watch(TipoLista.deseos).first;
    expect(items.single.hechoEn, DateTime(2026, 11, 18));

    await repo.update(
      TipoLista.deseos,
      items.single.copyWith(titulo: 'Ir a Tikal'),
    );
    items = await repo.watch(TipoLista.deseos).first;
    expect(items.single.titulo, 'Ir a Tikal');
    expect(await repo.watch(TipoLista.planes).first, isEmpty);

    await repo.delete(TipoLista.deseos, items.single.id);
    expect(await repo.watch(TipoLista.deseos).first, isEmpty);
  });

  test('ItemLista ida y vuelta por mapa', () {
    final item = ItemLista(
      id: 'x',
      titulo: 'Picnic',
      categoria: 'Citas',
      nota: 'con sándwiches',
      hecho: true,
      creadoEn: DateTime(2026, 1, 1),
      hechoEn: DateTime(2026, 2, 1),
    );
    final copia = ItemLista.fromMap('x', item.toMap());
    expect(copia.titulo, 'Picnic');
    expect(copia.hecho, isTrue);
    expect(copia.hechoEn, DateTime(2026, 2, 1));
  });

  test('ConfigClub: campos ausentes valen true', () {
    final c = ConfigClub.fromMap({'deseos': false, 'registroAbierto': false});
    expect(c.listasVisibles, [TipoLista.peliculas, TipoLista.planes]);
    expect(c.registroAbierto, isFalse);
    expect(ConfigClub.fromMap(null).listasVisibles, TipoLista.values);
  });

  test('Datos iniciales: uno por lista, con categoría válida', () {
    for (final tipo in TipoLista.values) {
      final items = datosIniciales[tipo]!;
      expect(items, hasLength(1));
      expect(tipo.categorias, contains(items.single.categoria));
    }
    expect(
      datosIniciales[TipoLista.peliculas]!.single.titulo,
      'Tierra de osos',
    );
  });
}
