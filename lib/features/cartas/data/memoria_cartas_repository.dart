import 'dart:async';

import '../../listas/domain/detalles.dart';
import '../../musica/domain/cancion.dart';
import '../domain/cartas_repository.dart';

/// Cartas en memoria, para pruebas y modo local. Aplica el mismo candado
/// que las reglas de Firestore usando [reloj].
class MemoriaCartasRepository implements CartasRepository {
  MemoriaCartasRepository({required this.autor, DateTime Function()? reloj})
    : reloj = reloj ?? DateTime.now;

  /// Quién usa la app (null en modo local sin sesión).
  final Autor? Function() autor;
  final DateTime Function() reloj;

  /// En modo local (sin sesión) todas las cartas son "tuyas".
  static const _local = Autor(uid: 'local', nombre: 'Tú');

  final _cartas = <Carta>[];
  final _contenidos = <String, ContenidoCarta>{};
  final _cambios = StreamController<void>.broadcast();
  var _siguienteId = 0;

  Autor get _yo => autor() ?? _local;

  @override
  DateTime ahora() => reloj();

  @override
  String? get uidActual => _yo.uid;

  List<Carta> get _ordenadas => List.unmodifiable(
    [..._cartas]..sort(
      (a, b) => (b.creadaEn ?? b.abrirEn).compareTo(a.creadaEn ?? a.abrirEn),
    ),
  );

  @override
  Stream<List<Carta>> watch() async* {
    yield _ordenadas;
    yield* _cambios.stream.map((_) => _ordenadas);
  }

  @override
  Future<void> crear({
    required String titulo,
    required String texto,
    required DateTime abrirEn,
    Cancion? cancion,
  }) async {
    final limpio = validarCarta(
      titulo: titulo,
      texto: texto,
      abrirEn: abrirEn,
      ahora: reloj(),
    );
    final id = 'carta${_siguienteId++}';
    _cartas.add(
      Carta(
        id: id,
        de: _yo,
        titulo: limpio,
        abrirEn: abrirEn,
        // Desempata cartas creadas en el mismo instante.
        creadaEn: reloj().add(Duration(microseconds: _siguienteId)),
      ),
    );
    _contenidos[id] = ContenidoCarta(texto: texto, cancion: cancion);
    _cambios.add(null);
  }

  @override
  Future<ContenidoCarta> leerContenido(Carta carta) async {
    final actual = _buscar(carta.id);
    if (!actual.esDe(uidActual) && actual.bloqueadaEn(reloj())) {
      throw cartaCerrada(actual);
    }
    return _contenidos[actual.id] ?? const ContenidoCarta(texto: '');
  }

  @override
  Future<void> marcarAbierta(Carta carta) async {
    final actual = _buscar(carta.id);
    if (actual.esDe(uidActual) ||
        actual.abierta ||
        actual.bloqueadaEn(reloj())) {
      return;
    }
    _cartas[_cartas.indexOf(actual)] = actual.copyWith(
      abiertaEn: reloj(),
      abiertaPor: _yo,
    );
    _cambios.add(null);
  }

  @override
  Future<void> borrar(Carta carta) async {
    final actual = _buscar(carta.id);
    if (!actual.esDe(uidActual)) {
      throw const CartaError('Solo quien escribió la carta puede borrarla');
    }
    _cartas.remove(actual);
    _contenidos.remove(actual.id);
    _cambios.add(null);
  }

  Carta _buscar(String id) => _cartas.firstWhere(
    (c) => c.id == id,
    orElse: () => throw const CartaError('Esta carta ya no existe'),
  );
}
