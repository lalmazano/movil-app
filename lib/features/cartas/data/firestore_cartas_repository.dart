import 'package:cloud_firestore/cloud_firestore.dart';

import '../../listas/domain/detalles.dart';
import '../../musica/domain/cancion.dart';
import '../domain/cartas_repository.dart';

/// Cartas en Firestore: `clubs/{clubId}/cartas/{id}` (el sobre) y
/// `clubs/{clubId}/cartas/{id}/contenido/texto` (el texto y la canción
/// opcional, que las reglas
/// solo dejan leer desde `abrirEn` o a quien la escribió).
class FirestoreCartasRepository implements CartasRepository {
  FirestoreCartasRepository(
    this.db, {
    required this.clubId,
    required this.autor,
  });

  final FirebaseFirestore db;
  final String clubId;

  /// Quién usa la app (null antes de iniciar sesión).
  final Autor? Function() autor;

  CollectionReference<Map<String, dynamic>> get _col =>
      db.collection('clubs').doc(clubId).collection('cartas');

  DocumentReference<Map<String, dynamic>> _texto(String id) =>
      _col.doc(id).collection('contenido').doc('texto');

  Autor get _yo =>
      autor() ??
      (throw const CartaError('Inicia sesión para usar las cartas 💌'));

  /// Convierte los Timestamp (también anidados) a DateTime.
  static Object? _fechas(Object? v) => switch (v) {
    Timestamp t => t.toDate(),
    Map m => {for (final e in m.entries) '${e.key}': _fechas(e.value)},
    _ => v,
  };

  @override
  DateTime ahora() => DateTime.now();

  @override
  String? get uidActual => autor()?.uid;

  @override
  Stream<List<Carta>> watch() => _col.snapshots().map((snap) {
    final cartas = [
      for (final doc in snap.docs)
        ?Carta.fromMap(
          doc.id,
          (_fechas(doc.data()) as Map).cast<String, Object?>(),
        ),
    ];
    // Se ordena aquí para no necesitar índices ni excluir las que aún no
    // tienen `creadaEn` confirmado.
    final ahora = DateTime.now();
    cartas.sort((a, b) => (b.creadaEn ?? ahora).compareTo(a.creadaEn ?? ahora));
    return cartas;
  });

  @override
  Future<void> crear({
    required String titulo,
    required String texto,
    required DateTime abrirEn,
    Cancion? cancion,
  }) async {
    final yo = _yo;
    final limpio = validarCarta(
      titulo: titulo,
      texto: texto,
      abrirEn: abrirEn,
      ahora: ahora(),
    );
    final ref = _col.doc();
    // La canción va con el texto (protegido), no en el sobre: así la otra
    // persona no sabe cuál es hasta el día de abrirla.
    final contenido = ContenidoCarta(texto: texto, cancion: cancion);
    // El sobre y el texto van juntos en un solo lote (las reglas del texto
    // revisan el sobre con getAfter).
    await (db.batch()
          ..set(ref, {
            'de': yo.toMap(),
            'titulo': limpio,
            'abrirEn': Timestamp.fromDate(abrirEn),
            'creadaEn': FieldValue.serverTimestamp(),
          })
          ..set(_texto(ref.id), contenido.toMap()))
        .commit();
  }

  @override
  Future<ContenidoCarta> leerContenido(Carta carta) async {
    final mia = carta.esDe(uidActual);
    if (!mia && carta.bloqueadaEn(ahora())) throw cartaCerrada(carta);
    try {
      final doc = await _texto(carta.id).get();
      return ContenidoCarta.fromMap(doc.data());
    } on FirebaseException catch (e) {
      // El reloj del teléfono puede ir adelantado respecto al servidor.
      if (e.code == 'permission-denied') throw cartaCerrada(carta);
      throw const CartaError('No se pudo leer la carta. Intenta de nuevo.');
    }
  }

  @override
  Future<void> marcarAbierta(Carta carta) async {
    final yo = autor();
    if (yo == null ||
        carta.esDe(yo.uid) ||
        carta.abierta ||
        carta.bloqueadaEn(ahora())) {
      return;
    }
    await _col.doc(carta.id).update({
      'abiertaEn': FieldValue.serverTimestamp(),
      'abiertaPor': yo.toMap(),
    });
  }

  @override
  Future<void> borrar(Carta carta) async {
    if (!carta.esDe(uidActual)) {
      throw const CartaError('Solo quien escribió la carta puede borrarla');
    }
    // Primero el texto (sus reglas leen el sobre) y luego el sobre.
    await (db.batch()
          ..delete(_texto(carta.id))
          ..delete(_col.doc(carta.id)))
        .commit();
  }
}
