import 'package:movil_app/features/michis/domain/michi.dart';
import 'package:movil_app/features/recuerdos/domain/recuerdo.dart';

/// Repositorio de michis en memoria para pruebas.
class MichiRepoEnMemoria implements MichiRepository {
  MichiRepoEnMemoria([List<Michi> iniciales = const []])
    : datos = List.of(iniciales);

  final List<Michi> datos;
  int _siguiente = 100;

  @override
  Future<List<Michi>> getAll() async => List.of(datos);

  @override
  Future<Michi> add({
    required String nombre,
    String? fotoOrigen,
    DateTime? nacimiento,
    String raza = '',
    String emoji = '🐱',
  }) async {
    final m = Michi(
      id: 'm${_siguiente++}',
      nombre: nombre,
      fotoPath: fotoOrigen,
      nacimiento: nacimiento,
      raza: raza,
      emoji: emoji,
    );
    datos.add(m);
    return m;
  }

  @override
  Future<Michi> update(Michi michi, {String? fotoOrigen}) async {
    final actualizado = fotoOrigen == null
        ? michi
        : michi.copyWith(fotoPath: () => fotoOrigen);
    final i = datos.indexWhere((m) => m.id == michi.id);
    datos[i] = actualizado;
    return actualizado;
  }

  @override
  Future<void> delete(String id) async => datos.removeWhere((m) => m.id == id);
}

/// Repositorio de recuerdos en memoria para pruebas.
class RecuerdoRepoEnMemoria implements RecuerdoRepository {
  RecuerdoRepoEnMemoria([List<Recuerdo> iniciales = const []])
    : datos = List.of(iniciales);

  final List<Recuerdo> datos;

  @override
  Future<List<Recuerdo>> getAll() async =>
      List.of(datos)..sort((a, b) => b.fecha.compareTo(a.fecha));

  @override
  Future<Recuerdo> add({
    required String sourcePath,
    required int calificacion,
    String nota = '',
    String? michiId,
  }) async {
    final r = Recuerdo(
      id: 'r${datos.length}',
      imagePath: sourcePath,
      fecha: DateTime(2026, 11, 10, 12, datos.length),
      calificacion: calificacion,
      nota: nota,
      michiId: michiId,
    );
    datos.add(r);
    return r;
  }

  @override
  Future<void> update(Recuerdo recuerdo) async {
    final i = datos.indexWhere((r) => r.id == recuerdo.id);
    datos[i] = recuerdo;
  }

  @override
  Future<void> delete(String id) async => datos.removeWhere((r) => r.id == id);
}

Recuerdo recuerdoDePrueba(
  String id,
  DateTime fecha,
  int calificacion, {
  String nota = '',
  String? michiId,
}) => Recuerdo(
  id: id,
  imagePath: '/no/existe/$id.jpg',
  fecha: fecha,
  calificacion: calificacion,
  nota: nota,
  michiId: michiId,
);
