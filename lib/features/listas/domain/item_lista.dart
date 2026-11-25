import 'config_club.dart';

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
  });

  final String id;
  final String titulo;
  final String categoria;
  final String nota;
  final bool hecho;
  final DateTime creadoEn;
  final DateTime? hechoEn;

  ItemLista copyWith({
    String? titulo,
    String? categoria,
    String? nota,
    bool? hecho,
    DateTime? Function()? hechoEn,
  }) => ItemLista(
    id: id,
    titulo: titulo ?? this.titulo,
    categoria: categoria ?? this.categoria,
    nota: nota ?? this.nota,
    hecho: hecho ?? this.hecho,
    creadoEn: creadoEn,
    hechoEn: hechoEn != null ? hechoEn() : this.hechoEn,
  );

  Map<String, Object?> toMap() => {
    'titulo': titulo,
    'categoria': categoria,
    'nota': nota,
    'hecho': hecho,
    'creadoEn': creadoEn,
    'hechoEn': hechoEn,
  };

  /// Las fechas ya deben venir como [DateTime].
  factory ItemLista.fromMap(String id, Map<String, Object?> map) => ItemLista(
    id: id,
    titulo: (map['titulo'] as String?) ?? '',
    categoria: (map['categoria'] as String?) ?? 'Otros',
    nota: (map['nota'] as String?) ?? '',
    hecho: (map['hecho'] as bool?) ?? false,
    creadoEn: (map['creadoEn'] as DateTime?) ?? DateTime.now(),
    hechoEn: map['hechoEn'] as DateTime?,
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

  /// Configuración del club (listas visibles y registro), en tiempo real.
  Stream<ConfigClub> watchConfig();

  /// Elementos de la lista, del más antiguo al más reciente, en tiempo real.
  Stream<List<ItemLista>> watch(TipoLista tipo);

  Future<void> add(TipoLista tipo, NuevoItem item);

  Future<void> addMany(TipoLista tipo, List<NuevoItem> items);

  Future<void> update(TipoLista tipo, ItemLista item);

  Future<void> setHecho(TipoLista tipo, String id, bool hecho);

  Future<void> delete(TipoLista tipo, String id);
}
