import 'package:movil_app/features/michis/domain/michi.dart';
import 'package:movil_app/features/recordatorios/domain/notificador_recordatorios.dart';
import 'package:movil_app/features/recordatorios/domain/recordatorio.dart';
import 'package:movil_app/features/salud/domain/entrada_salud.dart';

class NotificadorFalso implements NotificadorRecordatorios {
  final programadas = <int, NotificacionProgramada>{};
  final cancelados = <int>[];
  int permisosPedidos = 0;

  @override
  Future<bool> solicitarPermiso() async {
    permisosPedidos++;
    return true;
  }

  @override
  Future<void> programar(NotificacionProgramada n) async =>
      programadas[n.id] = n;

  @override
  Future<void> cancelar(int id) async {
    cancelados.add(id);
    programadas.remove(id);
  }
}

class RecordatoriosEnMemoria implements RecordatorioRepository {
  final datos = <Recordatorio>[];

  @override
  Future<List<Recordatorio>> getAll() async => List.of(datos);

  @override
  Future<void> guardar(Recordatorio r) async {
    final i = datos.indexWhere((x) => x.id == r.id);
    if (i == -1) {
      datos.add(r);
    } else {
      datos[i] = r;
    }
  }

  @override
  Future<void> delete(String id) async => datos.removeWhere((r) => r.id == id);
}

class SaludEnMemoria implements SaludRepository {
  final datos = <EntradaSalud>[];

  @override
  Future<List<EntradaSalud>> getAll() async =>
      List.of(datos)..sort((a, b) => b.fecha.compareTo(a.fecha));

  @override
  Future<void> guardar(EntradaSalud e) async {
    final i = datos.indexWhere((x) => x.id == e.id);
    if (i == -1) {
      datos.add(e);
    } else {
      datos[i] = e;
    }
  }

  @override
  Future<void> delete(String id) async => datos.removeWhere((e) => e.id == id);
}

class MichisEnMemoria implements MichiRepository {
  MichisEnMemoria(this.datos);

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
    final m = Michi(id: '${datos.length + 1}', nombre: nombre, emoji: emoji);
    datos.add(m);
    return m;
  }

  @override
  Future<Michi> update(Michi michi, {String? fotoOrigen}) async => michi;

  @override
  Future<void> delete(String id) async => datos.removeWhere((m) => m.id == id);
}

const pelusa = Michi(id: 'p', nombre: 'Pelusa', emoji: '😺');
const garfield = Michi(id: 'g', nombre: 'Garfield', emoji: '😼');
