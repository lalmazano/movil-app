import '../../listas/domain/detalles.dart';
import '../../musica/domain/cancion.dart';

/// Largo máximo del título (lo exige también `firestore.rules`).
const maxTituloCarta = 120;

/// Largo máximo del texto de la carta (lo exige también `firestore.rules`).
const maxTextoCarta = 5000;

/// Una carta con fecha: el sobre (quién la escribe, título y cuándo se
/// abre) lo ven los dos; el texto solo se lee desde [abrirEn] (o si eres
/// quien la escribió).
class Carta {
  const Carta({
    required this.id,
    required this.de,
    required this.titulo,
    required this.abrirEn,
    this.creadaEn,
    this.abiertaEn,
    this.abiertaPor,
  });

  final String id;
  final Autor de;
  final String titulo;
  final DateTime abrirEn;

  /// null mientras el servidor no confirma la hora.
  final DateTime? creadaEn;

  /// Cuándo la abrió quien la recibió (null si aún no).
  final DateTime? abiertaEn;
  final Autor? abiertaPor;

  bool get abierta => abiertaEn != null;

  /// `true` si a la hora [ahora] todavía no se puede abrir.
  bool bloqueadaEn(DateTime ahora) => ahora.isBefore(abrirEn);

  bool esDe(String? uid) => uid != null && de.uid == uid;

  /// Convierte el mapa de Firestore (con las fechas ya como [DateTime]).
  static Carta? fromMap(String id, Map<String, Object?> map) {
    final de = Autor.fromMap(map['de']);
    final abrirEn = map['abrirEn'];
    if (de == null || abrirEn is! DateTime) return null;
    return Carta(
      id: id,
      de: de,
      titulo: map['titulo'] as String? ?? '',
      abrirEn: abrirEn,
      creadaEn: map['creadaEn'] as DateTime?,
      abiertaEn: map['abiertaEn'] as DateTime?,
      abiertaPor: Autor.fromMap(map['abiertaPor']),
    );
  }

  Carta copyWith({DateTime? abiertaEn, Autor? abiertaPor}) => Carta(
    id: id,
    de: de,
    titulo: titulo,
    abrirEn: abrirEn,
    creadaEn: creadaEn,
    abiertaEn: abiertaEn ?? this.abiertaEn,
    abiertaPor: abiertaPor ?? this.abiertaPor,
  );
}

/// Lo que va dentro del sobre: el texto y, si quien la escribió quiso, una
/// canción. Las dos cosas viven en el documento protegido
/// (`contenido/texto`) para que la canción también sea sorpresa.
class ContenidoCarta {
  const ContenidoCarta({required this.texto, this.cancion});

  final String texto;
  final Cancion? cancion;

  /// Convierte el mapa de `contenido/texto`.
  static ContenidoCarta fromMap(Map<String, Object?>? map) => ContenidoCarta(
    texto: map?['texto'] as String? ?? '',
    cancion: Cancion.fromMap(map?['cancion']),
  );

  Map<String, Object?> toMap() => {
    'texto': texto,
    if (cancion != null) 'cancion': cancion!.toMap(),
  };
}

/// Error con un mensaje amable para mostrar tal cual.
class CartaError implements Exception {
  const CartaError(this.mensaje);

  final String mensaje;

  @override
  String toString() => mensaje;
}

/// Contrato del repositorio de cartas (`clubs/{club}/cartas`).
abstract interface class CartasRepository {
  /// La hora "actual" para candados y cuentas regresivas (en pruebas se
  /// puede simular).
  DateTime ahora();

  /// uid de quien usa la app (en modo local, uno fijo).
  String? get uidActual;

  /// Todas las cartas, de la más nueva a la más vieja.
  Stream<List<Carta>> watch();

  /// Escribe una carta que se podrá abrir desde [abrirEn] (en el futuro),
  /// con una [cancion] opcional que se guarda junto al texto (no en el
  /// sobre, para no arruinar la sorpresa). Lanza [CartaError] si algo no es
  /// válido.
  Future<void> crear({
    required String titulo,
    required String texto,
    required DateTime abrirEn,
    Cancion? cancion,
  });

  /// Lee el texto y la canción. Lanza [CartaError] si todavía está cerrada.
  Future<ContenidoCarta> leerContenido(Carta carta);

  /// Marca la carta como abierta (solo si ya se puede y no es tuya).
  Future<void> marcarAbierta(Carta carta);

  /// Borra la carta y su texto (solo quien la escribió).
  Future<void> borrar(Carta carta);
}

/// Atajos de lectura.
extension LeerCarta on CartasRepository {
  /// Solo el texto. Lanza [CartaError] si todavía está cerrada.
  Future<String> leer(Carta carta) async => (await leerContenido(carta)).texto;
}

/// Revisa los datos antes de guardar y devuelve el título limpio.
String validarCarta({
  required String titulo,
  required String texto,
  required DateTime abrirEn,
  required DateTime ahora,
}) {
  final limpio = titulo.trim();
  if (limpio.isEmpty) throw const CartaError('Ponle un título a la carta');
  if (limpio.length > maxTituloCarta) {
    throw const CartaError(
      'El título es muy largo (máximo $maxTituloCarta letras)',
    );
  }
  if (texto.trim().isEmpty) throw const CartaError('La carta está vacía');
  if (texto.length > maxTextoCarta) {
    throw const CartaError(
      'La carta es muy larga (máximo $maxTextoCarta letras)',
    );
  }
  if (!abrirEn.isAfter(ahora)) {
    throw const CartaError('La fecha para abrirla debe ser en el futuro');
  }
  return limpio;
}

/// Mensaje cuando alguien intenta abrir una carta antes de tiempo.
CartaError cartaCerrada(Carta carta) => const CartaError(
  'Todavía no se puede abrir esta carta 🔒 Ten paciencia 💌',
);
