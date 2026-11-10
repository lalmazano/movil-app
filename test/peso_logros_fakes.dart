import 'package:movil_app/features/michis/domain/michi.dart';
import 'package:movil_app/features/peso/domain/registro_peso.dart';
import 'package:movil_app/features/recuerdos/domain/recuerdo.dart';

/// Repositorios en memoria para las pruebas de peso y logros.
class MichisEnMemoria implements MichiRepository {
  MichisEnMemoria([List<Michi>? iniciales]) : datos = [...?iniciales];

  final List<Michi> datos;

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
      id: '${datos.length}',
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
  Future<Michi> update(Michi michi, {String? fotoOrigen}) async => michi;

  @override
  Future<void> delete(String id) async => datos.removeWhere((m) => m.id == id);
}

class RecuerdosEnMemoria implements RecuerdoRepository {
  RecuerdosEnMemoria([List<Recuerdo>? iniciales]) : datos = [...?iniciales];

  final List<Recuerdo> datos;

  @override
  Future<List<Recuerdo>> getAll() async => List.of(datos);

  @override
  Future<Recuerdo> add({
    required String sourcePath,
    required int calificacion,
    String nota = '',
    String? michiId,
  }) async => throw UnimplementedError();

  @override
  Future<void> update(Recuerdo recuerdo) async {}

  @override
  Future<void> delete(String id) async {}
}

class PesosEnMemoria implements PesoRepository {
  PesosEnMemoria([List<RegistroPeso>? iniciales]) : datos = [...?iniciales];

  final List<RegistroPeso> datos;
  var _n = 0;

  @override
  Future<List<RegistroPeso>> getAll() async => ordenarPorFecha(datos);

  @override
  Future<List<RegistroPeso>> deMichi(String michiId) async =>
      (await getAll()).where((r) => r.michiId == michiId).toList();

  @override
  Future<RegistroPeso> add({
    required String michiId,
    required DateTime fecha,
    required double kg,
    String nota = '',
  }) async {
    final r = RegistroPeso(
      id: 'nuevo${_n++}',
      michiId: michiId,
      fecha: fecha,
      kg: redondearKg(kg),
      nota: nota,
    );
    datos.add(r);
    return r;
  }

  @override
  Future<void> delete(String id) async => datos.removeWhere((r) => r.id == id);
}
