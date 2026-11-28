import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../listas/domain/detalles.dart';
import '../domain/preguntas_repository.dart';
import 'preguntas_internet.dart';

/// Preguntas en Firestore: `clubs/{clubId}/preguntas/{aaaa-mm-dd}` con
/// `{pregunta}` y cada respuesta en `respuestas/{uid}`.
///
/// Las reglas solo dejan leer la respuesta del otro cuando ya existe la mía,
/// así que esas lecturas se hacen después de responder y, si fallan, las
/// respuestas se tratan como ocultas.
class FirestorePreguntasRepository implements PreguntasRepository {
  FirestorePreguntasRepository(
    this.db, {
    required this.clubId,
    required this.autor,
  });

  final FirebaseFirestore db;
  final String clubId;

  /// Quién usa la app (null antes de iniciar sesión).
  final Autor? Function() autor;

  /// Se recuerda la pareja en cuanto se conoce.
  Autor? _pareja;

  CollectionReference<Map<String, dynamic>> get _col =>
      db.collection('clubs').doc(clubId).collection('preguntas');

  CollectionReference<Map<String, dynamic>> get _banco =>
      db.collection('clubs').doc(clubId).collection('banco_preguntas');

  CollectionReference<Map<String, dynamic>> _respuestas(String dia) =>
      _col.doc(dia).collection('respuestas');

  @override
  String get hoy => claveDia(DateTime.now());

  @override
  Autor? get autorActual => autor();

  /// Convierte los Timestamp (también anidados) a DateTime.
  static Object? _fechas(Object? v) => switch (v) {
    Timestamp t => t.toDate(),
    Map m => {for (final e in m.entries) '${e.key}': _fechas(e.value)},
    List l => [for (final e in l) _fechas(e)],
    _ => v,
  };

  static Respuesta? _respuesta(DocumentSnapshot<Map<String, dynamic>> doc) =>
      doc.exists ? Respuesta.fromMap(_fechas(doc.data())) : null;

  @override
  Future<void> asegurarHoy({bool usarInternet = false}) async {
    final dia = hoy;
    final fecha = fechaDeClave(dia)!;
    final ref = _col.doc(dia);
    if ((await ref.get()).exists) return;

    // Lo que tarda (leer propuestas, pedir a internet) va fuera de la
    // transacción; dentro solo se confirma.
    var banco = const <PreguntaPropuesta>[];
    try {
      banco = [
        for (final d in (await _banco.get()).docs)
          PreguntaPropuesta.fromMap(
            d.id,
            _fechas(d.data()) as Map<String, Object?>,
          ),
      ];
    } on FirebaseException catch (_) {
      // Sin permiso o sin conexión: se sigue sin propuestas.
    }
    final deInternet =
        siguientePropuesta(banco) == null && usarInternet && tocaInternet(fecha)
        ? await PreguntasInternet.fabrica().preguntaPara(fecha)
        : null;
    final elegida = elegirPregunta(fecha, banco: banco, deInternet: deInternet);

    // Transacción: solo el primero que abre la pregunta la crea.
    await db.runTransaction((tx) async {
      final doc = await tx.get(ref);
      if (doc.exists) return;
      final propuesta = elegida.propuesta;
      if (propuesta != null) {
        final refP = _banco.doc(propuesta.id);
        final p = await tx.get(refP);
        if (p.exists && p.data()?['usadaEn'] == null) {
          tx.update(refP, {'usadaEn': FieldValue.serverTimestamp()});
        }
      }
      tx.set(ref, {
        'pregunta': elegida.pregunta,
        'fuente': elegida.fuente.name,
        if (propuesta != null) 'propuestaId': propuesta.id,
        if (propuesta?.autor case final a?) 'propuestaPor': a.toMap(),
      });
    });
  }

  @override
  Stream<List<PreguntaPropuesta>> watchPropuestas() => _banco
      .orderBy('creadaEn')
      .snapshots()
      .map(
        (snap) => [
          for (final d in snap.docs)
            PreguntaPropuesta.fromMap(
              d.id,
              _fechas(d.data()) as Map<String, Object?>,
            ),
        ],
      );

  @override
  Future<void> proponer(String texto) {
    final yo = autor();
    if (yo == null) throw StateError('Inicia sesión para proponer.');
    return _banco.add({
      'texto': validarPropuesta(texto),
      'autor': yo.toMap(),
      'creadaEn': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> borrarPropuesta(String id) => _banco.doc(id).delete();

  @override
  Stream<String> watchPregunta(String dia) => _col
      .doc(dia)
      .snapshots()
      .map(
        (d) =>
            (d.data()?['pregunta'] as String?) ??
            preguntaDelDia(fechaDeClave(dia)!),
      );

  @override
  Stream<Respuesta?> watchMiRespuesta(String dia) {
    final uid = autor()?.uid;
    if (uid == null) return Stream.value(null);
    return _respuestas(dia).doc(uid).snapshots().map(_respuesta);
  }

  @override
  Stream<List<Respuesta>> watchOtras(String dia) {
    final uid = autor()?.uid;
    if (uid == null) return Stream.value(const []);
    // Justo después de responder, el servidor puede no tener aún mi
    // respuesta y rechazar la lectura: se reintenta hasta que la acepte.
    late final StreamController<List<Respuesta>> salida;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? sub;
    Timer? reintento;
    var espera = const Duration(seconds: 2);

    void escuchar() {
      sub = _respuestas(dia).snapshots().listen(
        (snap) {
          espera = const Duration(seconds: 2);
          final otras = [
            for (final doc in snap.docs)
              if (doc.id != uid) ?_respuesta(doc),
          ];
          for (final r in otras) {
            _pareja ??= r.autor;
          }
          salida.add(otras);
        },
        onError: (Object _) {
          sub?.cancel();
          if (salida.isClosed) return;
          salida.add(const []);
          reintento = Timer(espera, escuchar);
          if (espera < const Duration(seconds: 30)) espera *= 2;
        },
      );
    }

    salida = StreamController<List<Respuesta>>(
      onListen: escuchar,
      onCancel: () async {
        reintento?.cancel();
        await sub?.cancel();
      },
    );
    return salida.stream;
  }

  @override
  Future<void> responder(String dia, String texto) async {
    final yo = autor();
    if (yo == null) throw StateError('Inicia sesión para responder.');
    final limpio = texto.trim();
    if (limpio.isEmpty || limpio.length > maxCaracteresRespuesta) {
      throw ArgumentError.value(texto, 'texto', 'Debe tener 1 a 1000 letras');
    }
    await _respuestas(dia).doc(yo.uid).set({
      'texto': limpio,
      'autor': yo.toMap(),
      'fecha': FieldValue.serverTimestamp(),
    });
  }

  /// Mi respuesta y, si existe, las de los demás (ocultas si no se pueden
  /// leer).
  Future<DiaPregunta> _dia(
    String uid,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final dia = doc.id;
    final pregunta =
        (doc.data()['pregunta'] as String?) ??
        preguntaDelDia(fechaDeClave(dia) ?? DateTime(2024));
    Respuesta? mia;
    var otras = const <Respuesta>[];
    try {
      mia = _respuesta(await _respuestas(dia).doc(uid).get());
      if (mia != null) {
        final snap = await _respuestas(dia).get();
        otras = [
          for (final d in snap.docs)
            if (d.id != uid) ?_respuesta(d),
        ];
        for (final r in otras) {
          _pareja ??= r.autor;
        }
      }
    } on FirebaseException catch (_) {
      // Sin permiso: se queda oculta.
    }
    return DiaPregunta(dia: dia, pregunta: pregunta, mia: mia, otras: otras);
  }

  @override
  Stream<List<DiaPregunta>> watchHistorial({int limite = 30}) {
    final uid = autor()?.uid;
    if (uid == null) return Stream.value(const []);
    // Rango ascendente por id (aaaa-mm-dd) y se invierte en la app: Firestore
    // no siempre permite ordenar por id en forma descendente.
    final desde = claveDia(DateTime.now().subtract(Duration(days: limite)));
    return _col
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: desde)
        .where(FieldPath.documentId, isLessThan: hoy)
        .snapshots()
        .asyncMap(
          (snap) => Future.wait([
            for (final d in snap.docs.reversed.take(limite)) _dia(uid, d),
          ]),
        );
  }

  @override
  Future<Autor?> pareja() async {
    if (_pareja != null) return _pareja;
    final uid = autor()?.uid;
    if (uid == null) return null;
    try {
      final desde = claveDia(DateTime.now().subtract(const Duration(days: 7)));
      final dias = await _col
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: desde)
          .where(FieldPath.documentId, isLessThanOrEqualTo: hoy)
          .get();
      for (final d in dias.docs.reversed) {
        final dia = await _dia(uid, d);
        if (dia.otras.isNotEmpty) return _pareja = dia.otras.first.autor;
      }
    } on FirebaseException catch (_) {
      // Sin conexión o sin permiso: aún no se sabe.
    }
    return _pareja;
  }
}
