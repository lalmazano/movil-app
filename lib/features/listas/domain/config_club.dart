import 'item_lista.dart';

/// Configuración del club, guardada en el documento `config/app` de Firestore.
///
/// Campos booleanos (si faltan, valen `true`):
/// - `peliculas`, `deseos`, `planes`: qué listas se muestran.
/// - `registroAbierto`: si alguien nuevo puede entrar al club.
/// - Funciones: `calificaciones` (huellitas al marcar), `autores` (quién
///   agregó / marcó), `ruleta`, `buscar`, `fotos`, `posters` (TMDB),
///   `contador` (contador de aniversario), `widget` (widget de Android) y
///   `actualizaciones` (avisar y descargar versiones nuevas), `cartas`,
///   `resumen`, `fechas`, `preguntas`, `sugerencias`, `repetibles`,
///   `playlist`, `adivina` y `cartasMusica`.
///
/// Otros:
/// - `aniversario` (timestamp, opcional): fecha desde la que cuenta el club.
class ConfigClub {
  const ConfigClub({
    this.peliculas = true,
    this.deseos = true,
    this.planes = true,
    this.registroAbierto = true,
    this.calificaciones = true,
    this.autores = true,
    this.ruleta = true,
    this.buscar = true,
    this.fotos = true,
    this.posters = true,
    this.contador = true,
    this.widget = true,
    this.actualizaciones = true,
    this.cartas = true,
    this.resumen = true,
    this.fechas = true,
    this.preguntas = true,
    this.sugerencias = true,
    this.repetibles = true,
    this.playlist = true,
    this.adivina = true,
    this.cartasMusica = true,
    this.aniversario,
  });

  factory ConfigClub.fromMap(Map<String, Object?>? map) {
    bool b(String campo) => map?[campo] as bool? ?? true;
    return ConfigClub(
      peliculas: b('peliculas'),
      deseos: b('deseos'),
      planes: b('planes'),
      registroAbierto: b('registroAbierto'),
      calificaciones: b('calificaciones'),
      autores: b('autores'),
      ruleta: b('ruleta'),
      buscar: b('buscar'),
      fotos: b('fotos'),
      posters: b('posters'),
      contador: b('contador'),
      widget: b('widget'),
      actualizaciones: b('actualizaciones'),
      cartas: b('cartas'),
      resumen: b('resumen'),
      fechas: b('fechas'),
      preguntas: b('preguntas'),
      sugerencias: b('sugerencias'),
      repetibles: b('repetibles'),
      playlist: b('playlist'),
      adivina: b('adivina'),
      cartasMusica: b('cartasMusica'),
      aniversario: map?['aniversario'] as DateTime?,
    );
  }

  /// Todos los campos booleanos de `config/app`. La app crea los que falten
  /// con `true` (sin cambiar los que ya existen).
  static const banderas = [
    'peliculas',
    'deseos',
    'planes',
    'registroAbierto',
    'calificaciones',
    'autores',
    'ruleta',
    'buscar',
    'fotos',
    'posters',
    'contador',
    'widget',
    'actualizaciones',
    'cartas',
    'resumen',
    'fechas',
    'preguntas',
    'sugerencias',
    'repetibles',
    'playlist',
    'adivina',
    'cartasMusica',
  ];

  final bool peliculas;
  final bool deseos;
  final bool planes;
  final bool registroAbierto;

  /// Pedir huellitas y comentario al marcar como hecho, y mostrarlas.
  final bool calificaciones;

  /// Mostrar quién agregó y quién marcó cada elemento.
  final bool autores;

  /// Botón 🎲 "¿Qué vemos/hacemos hoy?".
  final bool ruleta;

  /// Botón 🔍 de búsqueda en las listas.
  final bool buscar;

  /// Fotos de recuerdos en cada elemento.
  final bool fotos;

  /// Pósters y datos de películas desde TMDB.
  final bool posters;

  /// Contador "Llevamos X años…" en el inicio (requiere `aniversario`).
  final bool contador;

  /// Actualizar el widget de la pantalla de inicio de Android.
  final bool widget;

  /// Avisar cuando hay una versión nueva y descargarla.
  final bool actualizaciones;

  /// Cartas con fecha que se abren en un día (✉️).
  final bool cartas;

  /// Resumen anual tipo "Wrapped" (🎁).
  final bool resumen;

  /// Fechas importantes con cuenta regresiva (📆).
  final bool fechas;

  /// Pregunta del día para conocerse (🎲).
  final bool preguntas;

  /// Sugerencias de películas de TMDB (🎬).
  final bool sugerencias;

  /// Planes repetibles con contador de veces (🔁).
  final bool repetibles;

  /// Playlist del club con buscador de iTunes (📀).
  final bool playlist;

  /// Juego "Adivina la canción" (❓).
  final bool adivina;

  /// Canción adjunta en las cartas con fecha (✉️🎵).
  final bool cartasMusica;

  /// Las fechas ya deben venir como [DateTime].
  final DateTime? aniversario;

  bool esVisible(TipoLista tipo) => switch (tipo) {
    TipoLista.peliculas => peliculas,
    TipoLista.deseos => deseos,
    TipoLista.planes => planes,
  };

  List<TipoLista> get listasVisibles =>
      TipoLista.values.where(esVisible).toList();
}
