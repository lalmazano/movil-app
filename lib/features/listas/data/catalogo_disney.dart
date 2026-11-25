import '../domain/item_lista.dart';

/// Lista de películas para el reto Disney (tomada de las listas de referencia).
/// Cada clave es una categoría de [TipoLista.peliculas].
const Map<String, List<String>> catalogoDisney = {
  'Princesas': [
    'Blancanieves y los siete enanos',
    'La Cenicienta',
    'La Bella Durmiente',
    'La Sirenita',
    'La Bella y la Bestia',
    'Aladdín',
    'Pocahontas',
    'Mulán',
    'La princesa y el sapo',
    'Enredados',
    'Valiente',
    'Frozen',
    'Frozen II',
    'Moana',
    'Raya y el último dragón',
  ],
  'Clásicos': [
    'Pinocho',
    'Fantasía',
    'Dumbo',
    'Bambi',
    'Alicia en el país de las maravillas',
    'Peter Pan',
    'La dama y el vagabundo',
    '101 dálmatas',
    'El libro de la selva',
    'Los aristogatos',
    'Robin Hood',
    'Las aventuras de Winnie Pooh',
    'Bernardo y Bianca en Cangurolandia',
    'El Rey León',
    'Hércules',
    'Tarzán',
    'Mary Poppins',
  ],
  'Mágicas / Fantasía': [
    'La espada en la piedra',
    'Maléfica',
    'Las crónicas de Narnia',
    'Abracadabra (Hocus Pocus)',
    'Mi amigo el dragón',
    'Mi amigo el gigante',
    'El cascanueces y los cuatro reinos',
    'Tinker Bell',
    'Tinker Bell y el tesoro perdido',
    'Tron',
    'Cruella',
  ],
  'Pixar': [
    'Toy Story',
    'Toy Story 2',
    'Toy Story 3',
    'Toy Story 4',
    'Monsters Inc.',
    'Buscando a Nemo',
    'Los Increíbles',
    'Cars',
    'Cars 2',
    'Cars 3',
    'Ratatouille',
    'Wall-E',
    'Up',
    'Intensamente',
    'Un gran dinosaurio',
    'Buscando a Dory',
    'Coco',
    'Unidos',
    'Soul',
    'Red',
    'Elementos',
  ],
  'Aventura': [
    'Zootopia',
    'Las locuras del emperador',
    'Lilo & Stitch',
    'Bolt',
    'El gran ratón detective',
    'Atlantis: el imperio perdido',
    'El planeta del tesoro',
    'Tierra de osos',
    'Tierra de osos 2',
    'Vacas vaqueras',
    'La familia del futuro',
    'Mickey, Donald y Goofy: Los tres mosqueteros',
    'Ralph, el demoledor',
    'Big Hero 6',
    'Christopher Robin',
    'Big Red',
  ],
  'Navideñas': [
    'Santa Cláusula',
    'Noelle',
    'Mi pobre angelito (Disney)',
    'Operación regalo',
    'Mickey: Había una vez una Navidad',
    'Los fantasmas de Scrooge',
    'Los Muppets en Cuento de Navidad',
    'El extraño mundo de Jack',
  ],
  'DreamWorks': [
    'El Gato con Botas',
    'El Gato con Botas: El último deseo',
    'Spirit: el corcel indomable',
  ],
  'Otras': ['Minions', 'Minions: Nace un villano'],
};

/// Películas del catálogo que aún no están en [actuales] (sin repetir títulos).
List<NuevoItem> peliculasFaltantes(List<ItemLista> actuales) {
  String clave(String t) => t.trim().toLowerCase();
  final existentes = {for (final i in actuales) clave(i.titulo)};
  return [
    for (final MapEntry(key: categoria, value: titulos)
        in catalogoDisney.entries)
      for (final titulo in titulos)
        if (existentes.add(clave(titulo)))
          (titulo: titulo, categoria: categoria, nota: ''),
  ];
}
