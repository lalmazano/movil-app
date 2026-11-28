import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movil_app/features/listas/domain/detalles.dart';
import 'package:movil_app/features/musica/data/buscador_musica.dart';
import 'package:movil_app/features/musica/data/deezer_client.dart';
import 'package:movil_app/features/musica/data/itunes_client.dart';
import 'package:movil_app/features/musica/data/memoria_musica_repository.dart';
import 'package:movil_app/features/musica/domain/cancion.dart';

http.Response json(Object o) =>
    http.Response.bytes(utf8.encode(jsonEncode(o)), 200);

const deezerBachata = {
  'id': 1753549417,
  'title': 'La Bachata',
  'duration': 162,
  'preview': 'https://cdnt-preview.dzcdn.net/viejo.mp3',
  'artist': {'name': 'Manuel Turizo'},
  'album': {'title': 'La Bachata', 'cover_medium': 'https://x/250.jpg'},
};

const itunesBachata = {
  'trackId': 1624563284,
  'trackName': 'La Bachata',
  'artistName': 'Manuel Turizo',
  'previewUrl': 'https://audio/x.m4a',
  'artworkUrl100': 'https://x/100x100bb.jpg',
};

void main() {
  tearDown(() {
    ItunesClient.fabrica = ItunesClient.new;
    DeezerClient.fabrica = DeezerClient.new;
  });

  test('Cancion de Deezer: clave, enlace y mapa ida y vuelta', () {
    final c = Cancion.fromDeezer(deezerBachata)!;
    expect(c.esDeezer, isTrue);
    expect(c.clave, 'dz1753549417');
    expect(c.deezerUrl.toString(), 'https://www.deezer.com/track/1753549417');
    expect(c.duracionMs, 162000);
    final map = c.toMap();
    expect(map['deezerId'], 1753549417);
    expect(map.containsKey('itunesId'), isFalse);
    final otra = Cancion.fromMap(map)!;
    expect(otra, c);
    expect(otra.esDeezer, isTrue);

    final it = Cancion.fromItunes(itunesBachata)!;
    expect(it.clave, '1624563284');
    expect(Cancion.fromMap(it.toMap())!.esDeezer, isFalse);
    expect(it == c, isFalse);
    expect(it.huella, c.huella);
  });

  test('huella ignora mayúsculas, paréntesis y artistas invitados', () {
    const a = Cancion(
      itunesId: 1,
      titulo: 'Nuestra Canción (feat. Vicente García)',
      artista: 'Monsieur Periné, Vicente García',
    );
    const b = Cancion(
      itunesId: 2,
      fuente: FuenteMusica.deezer,
      titulo: 'nuestra canción',
      artista: 'Monsieur Periné',
    );
    expect(a.huella, b.huella);
  });

  test('mezclarResultados alterna y quita repetidos', () {
    final it = Cancion.fromItunes(itunesBachata)!;
    final dz = Cancion.fromDeezer(deezerBachata)!;
    const otra = Cancion(
      itunesId: 9,
      fuente: FuenteMusica.deezer,
      titulo: 'Bonito',
      artista: 'Jarabe de Palo',
    );
    final r = mezclarResultados([it], [dz, otra]);
    expect(r, [it, otra]);
  });

  test('buscarEnAmbas junta las dos y tolera que una falle', () async {
    ItunesClient.fabrica = () => ItunesClient(
      client: MockClient(
        (_) async => json({
          'results': [itunesBachata],
        }),
      ),
    );
    DeezerClient.fabrica = () => DeezerClient(
      client: MockClient(
        (_) async => json({
          'data': [
            deezerBachata,
            {...deezerBachata, 'id': 5, 'title': 'Bonito'},
          ],
        }),
      ),
    );
    final ambas = await buscarEnAmbas('bachata');
    expect(ambas.map((c) => c.titulo), ['La Bachata', 'Bonito']);
    expect(ambas.first.esDeezer, isFalse);
    expect(ambas.last.esDeezer, isTrue);

    ItunesClient.fabrica = () =>
        ItunesClient(client: MockClient((_) async => http.Response('x', 500)));
    final soloDeezer = await buscarEnAmbas('bachata');
    expect(soloDeezer.length, 2);

    DeezerClient.fabrica = () => DeezerClient(
      client: MockClient((_) async => throw Exception('sin red')),
    );
    expect(buscarEnAmbas('bachata'), throwsA(isA<ItunesException>()));
  });

  test('previewFresco pide un enlace vigente por id', () async {
    late Uri pedida;
    final dz = DeezerClient(
      client: MockClient((r) async {
        pedida = r.url;
        return json({
          'id': 1,
          'preview': 'https://cdnt-preview.dzcdn.net/nuevo.mp3',
        });
      }),
    );
    expect(await dz.previewFresco(1753549417), endsWith('nuevo.mp3'));
    expect(pedida.path, '/track/1753549417');
  });

  test('la playlist no repite la misma canción de otro catálogo', () async {
    final repo = MemoriaMusicaRepository(
      autor: () => const Autor(uid: 'u1', nombre: 'Luis'),
    );
    expect(await repo.agregar(Cancion.fromItunes(itunesBachata)!), isTrue);
    expect(await repo.agregar(Cancion.fromDeezer(deezerBachata)!), isFalse);
    final lista = await repo.watchPlaylist().first;
    expect(lista.single.id, '1624563284');
  });
}
