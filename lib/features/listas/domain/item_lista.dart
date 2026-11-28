import 'dart:typed_data';

import '../../actualizacion/domain/version_app.dart';
import '../../cartas/domain/cartas_repository.dart';
import '../../fechas/domain/fechas_repository.dart';
import '../../musica/domain/musica_repository.dart';
import '../../preguntas/domain/preguntas_repository.dart';
import 'config_club.dart';
import 'detalles.dart';

export 'detalles.dart';

/// Las tres listas del club.
enum TipoLista {
  peliculas(
    titulo: 'Películas',
    emoji: '🎬',
    coleccion: 'peliculas',
    hechos: 'vistas',
    accionHecho: 'Vista',
    pista: 'Ej. El Gato con Botas',
    vacio: 'Aún no hay películas.\n¡Agrega la primera o carga la lista Disney!',
    categorias: [
      'Disney',
      'DreamWorks',
      'Princesas',
      'Clásicos',
      'Mágicas / Fantasía',
      'Pixar',
      'Aventura',
      'Navideñas',
      'Otras',
    ],
  ),
  deseos(
    titulo: 'Deseos',
    emoji: '🌠',
    coleccion: 'deseos',
    hechos: 'cumplidos',
    accionHecho: 'Cumplido',
    pista: 'Ej. Ver un atardecer en la playa',
    vacio: 'Aún no hay deseos.\n¡Pide el primero!',
    categorias: ['Viajes', 'Comida', 'Experiencias', 'Cosas', 'Metas', 'Otros'],
  ),
  planes(
    titulo: 'Hacer juntos',
    emoji: '🧺',
    coleccion: 'planes',
    hechos: 'hechos',
    accionHecho: 'Hecho',
    pista: 'Ej. Hacer un picnic',
    vacio: 'Aún no hay planes.\n¡Agreguen algo para hacer juntos!',
    categorias: ['Citas', 'Aventuras', 'En casa', 'Aprender', 'Otros'],
  );

  const TipoLista({
    required this.titulo,
    required this.emoji,
    required this.coleccion,
    required this.hechos,
    required this.accionHecho,
    required this.pista,
    required this.vacio,
    required this.categorias,
  });

  final String titulo;
  final String emoji;

  /// Nombre de la colección en Firestore.
  final String coleccion;

  /// Cómo se llaman los elementos completados ("vistas", "cumplidos"...).
  final String hechos;
  final String accionHecho;
  final String pista;
  final String vacio;

  /// Categorías por defecto. Las que usa la app vienen de Firestore
  /// (`categorias/{coleccion}`); estas son la carga inicial y el respaldo.
  final List<String> categorias;
}

/// Un elemento de cualquiera de las listas (película, deseo o plan).
class ItemLista {
  const ItemLista({
    required this.id,
    required this.titulo,
    required this.categoria,
    required this.creadoEn,
    this.nota = '',
    this.hecho = false,
    this.hechoEn,
    this.creadoPor,
    this.hechoPor,
    this.calificaciones = const {},
    this.pelicula,
    this.fotos = 0,
    this.repetible = false,
    this.veces = 0,
    this.ultimaVez,
  });

  final String id;
  final String titulo;
  final String categoria;
  final String nota;
  final bool hecho;
  final DateTime creadoEn;
  final DateTime? hechoEn;

  /// Quién lo agregó (null en elementos viejos o de la carga inicial).
  final Autor? creadoPor;

  /// Quién lo marcó como hecho.
  final Autor? hechoPor;

  /// Calificación de cada persona, por uid.
  final Map<String, Calificacion> calificaciones;

  /// Póster y datos de TMDB (solo películas).
  final InfoPelicula? pelicula;

  /// Cuántas fotos tiene (las fotos viven en la subcolección `fotos`).
  final int fotos;

  /// Se puede hacer varias veces (p. ej. "Desayunar juntos"): al marcarlo se
  /// suma una vez y sigue pendiente.
  final bool repetible;

  /// Cuántas veces lo han hecho (solo repetibles).
  final int veces;

  /// Última vez que lo hicieron (solo repetibles).
  final DateTime? ultimaVez;

  /// Promedio de huellitas, o null si nadie ha calificado.
  double? get promedioHuellitas => calificaciones.isEmpty
      ? null
      : calificaciones.values.map((c) => c.huellitas).reduce((a, b) => a + b) /
            calificaciones.length;

  ItemLista copyWith({
    String? titulo,
    String? categoria,
    String? nota,
    bool? hecho,
    DateTime? Function()? hechoEn,
    Autor? Function()? hechoPor,
    Map<String, Calificacion>? calificaciones,
    InfoPelicula? Function()? pelicula,
    int? fotos,
    bool? repetible,
    int? veces,
    DateTime? Function()? ultimaVez,
  }) => ItemLista(
    id: id,
    titulo: titulo ?? this.titulo,
    categoria: categoria ?? this.categoria,
    nota: nota ?? this.nota,
    hecho: hecho ?? this.hecho,
    creadoEn: creadoEn,
    hechoEn: hechoEn != null ? hechoEn() : this.hechoEn,
    creadoPor: creadoPor,
    hechoPor: hechoPor != null ? hechoPor() : this.hechoPor,
    calificaciones: calificaciones ?? this.calificaciones,
    pelicula: pelicula != null ? pelicula() : this.pelicula,
    fotos: fotos ?? this.fotos,
    repetible: repetible ?? this.repetible,
    veces: veces ?? this.veces,
    ultimaVez: ultimaVez != null ? ultimaVez() : this.ultimaVez,
  );

  Map<String, Object?> toMap() => {
    'titulo': titulo,
    'categoria': categoria,
    'nota': nota,
    'hecho': hecho,
    'creadoEn': creadoEn,
    'hechoEn': hechoEn,
    'creadoPor': creadoPor?.toMap(),
    'hechoPor': hechoPor?.toMap(),
    'calificaciones': {
      for (final MapEntry(:key, :value) in calificaciones.entries)
        key: value.toMap(),
    },
    'pelicula': pelicula?.toMap(),
    'fotos': fotos,
    'repetible': repetible,
    'veces': veces,
    'ultimaVez': ultimaVez,
  };

  /// Las fechas (también las anidadas) ya deben venir como [DateTime].
  factory ItemLista.fromMap(String id, Map<String, Object?> map) => ItemLista(
    id: id,
    titulo: (map['titulo'] as String?) ?? '',
    categoria: (map['categoria'] as String?) ?? 'Otros',
    nota: (map['nota'] as String?) ?? '',
    hecho: (map['hecho'] as bool?) ?? false,
    creadoEn: (map['creadoEn'] as DateTime?) ?? DateTime.now(),
    hechoEn: map['hechoEn'] as DateTime?,
    creadoPor: Autor.fromMap(map['creadoPor']),
    hechoPor: Autor.fromMap(map['hechoPor']),
    calificaciones: {
      if (map['calificaciones'] case final Map cal)
        for (final MapEntry(:key, :value) in cal.entries)
          '$key': ?Calificacion.fromMap(value),
    },
    pelicula: InfoPelicula.fromMap(map['pelicula']),
    fotos: (map['fotos'] as num?)?.toInt() ?? 0,
    repetible: (map['repetible'] as bool?) ?? false,
    veces: (map['veces'] as num?)?.toInt() ?? 0,
    ultimaVez: map['ultimaVez'] as DateTime?,
  );
}

/// Un elemento nuevo, aún sin id.
typedef NuevoItem = ({String titulo, String categoria, String nota});

/// Contrato para guardar las listas del club.
abstract interface class ListaRepository {
  /// `true` si los datos se sincronizan con la nube (Firebase).
  bool get enLaNube;

  /// Crea lo que falte la primera vez (configuración, club y datos
  /// iniciales). No toca nada que ya exista.
  Future<void> inicializar();

  /// Categorías de la lista, en tiempo real (de la base de datos).
  Stream<List<String>> watchCategorias(TipoLista tipo);

  /// Última versión publicada de la app (`config/version`), o null.
  Stream<VersionApp?> watchVersion();

  /// Configuración del club (listas visibles y registro), en tiempo real.
  Stream<ConfigClub> watchConfig();

  /// Elementos de la lista, del más antiguo al más reciente, en tiempo real.
  Stream<List<ItemLista>> watch(TipoLista tipo);

  /// Quién está usando la app (null en modo local).
  Autor? get autorActual;

  /// Agrega un elemento; [pelicula] guarda póster y datos de TMDB.
  Future<void> add(
    TipoLista tipo,
    NuevoItem item, {
    InfoPelicula? pelicula,
    bool repetible = false,
  });

  /// Elementos repetibles: suma una vez (veces + 1, ultimaVez = ahora).
  Future<void> registrarVez(TipoLista tipo, String id);

  /// Cartas con fecha (`clubs/{club}/cartas`).
  CartasRepository get cartas;

  /// Fechas importantes (`clubs/{club}/fechas`).
  FechasRepository get fechas;

  /// Pregunta del día (`clubs/{club}/preguntas`).
  PreguntasRepository get preguntas;

  /// Playlist del club y récords de "Adivina la canción".
  MusicaRepository get musica;

  Future<void> addMany(TipoLista tipo, List<NuevoItem> items);

  /// Guarda título, categoría, nota, [ItemLista.pelicula] y
  /// [ItemLista.repetible].
  Future<void> update(TipoLista tipo, ItemLista item);

  /// Marca o desmarca; guarda quién lo marcó ([autorActual]).
  Future<void> setHecho(TipoLista tipo, String id, bool hecho);

  /// Guarda (o reemplaza) la calificación de [Calificacion.autor].
  Future<void> calificar(TipoLista tipo, String id, Calificacion calificacion);

  /// Borra el elemento y sus fotos.
  Future<void> delete(TipoLista tipo, String id);

  /// Un elemento en tiempo real (null si se borró).
  Stream<ItemLista?> watchItem(TipoLista tipo, String id);

  /// Fotos del elemento, de la más antigua a la más nueva.
  Stream<List<FotoItem>> watchFotos(TipoLista tipo, String id);

  /// Guarda una foto ya comprimida (máximo [maxBytesFoto]).
  Future<void> agregarFoto(TipoLista tipo, String id, Uint8List bytes);

  Future<void> borrarFoto(TipoLista tipo, String id, String fotoId);

  /// Clave de la API de TMDB (documento `config/tmdb`, campo `apiKey`).
  Future<String?> tmdbApiKey();
}
