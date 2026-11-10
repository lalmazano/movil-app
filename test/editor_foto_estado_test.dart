import 'package:flutter_test/flutter_test.dart';
import 'package:movil_app/features/editor_foto/domain/editor_estado.dart';

void main() {
  late EditorEstado estado;
  late int n;

  setUp(() {
    n = 0;
    estado = EditorEstado(generarId: () => 's${n++}');
  });

  test('agregar coloca el sticker al centro y lo selecciona', () {
    final id = estado.agregar('🐾');
    expect(id, 's0');
    expect(estado.stickers.single.sticker, '🐾');
    expect(estado.stickers.single.posicion, const Offset(0.5, 0.5));
    expect(estado.seleccionadoId, id);
    expect(estado.puedeDeshacer, isTrue);
  });

  test('mover desplaza y limita al lienzo', () {
    final id = estado.agregar('👑');
    estado.mover(id, const Offset(0.1, -0.2));
    expect(estado.stickers.single.posicion.dx, closeTo(0.6, 1e-9));
    expect(estado.stickers.single.posicion.dy, closeTo(0.3, 1e-9));
    estado.mover(id, const Offset(5, -5));
    expect(estado.stickers.single.posicion, const Offset(1, 0));
  });

  test('transformar escala (con límites) y rota', () {
    final id = estado.agregar('🐟');
    estado.transformar(id, escala: 2, rotacion: 0.5);
    expect(estado.stickers.single.escala, 2);
    expect(estado.stickers.single.rotacion, 0.5);
    estado.transformar(id, escala: 100);
    expect(estado.stickers.single.escala, EditorEstado.escalaMaxima);
    estado.transformar(id, escala: 0.01);
    expect(estado.stickers.single.escala, EditorEstado.escalaMinima);
    expect(estado.stickers.single.rotacion, 0.5);
  });

  test('un gesto completo se deshace en un solo paso', () {
    final id = estado.agregar('💕');
    estado.comenzarGesto(id);
    for (var i = 0; i < 10; i++) {
      estado.mover(id, const Offset(0.01, 0));
      estado.transformar(id, escala: 1 + i / 10);
    }
    estado.terminarGesto();
    expect(estado.stickers.single.posicion.dx, closeTo(0.6, 1e-9));
    estado.deshacer();
    expect(estado.stickers.single.posicion, const Offset(0.5, 0.5));
    expect(estado.stickers.single.escala, 1);
  });

  test('comenzarGesto trae el sticker al frente', () {
    final a = estado.agregar('🐱');
    estado.agregar('😻');
    estado.comenzarGesto(a);
    estado.terminarGesto();
    expect(estado.stickers.last.id, a);
    expect(estado.seleccionadoId, a);
  });

  test('eliminar quita el sticker y la selección', () {
    final a = estado.agregar('🐱');
    final b = estado.agregar('✨');
    estado.eliminar(b);
    expect(estado.stickers.map((s) => s.id), [a]);
    expect(estado.seleccionadoId, isNull);
    estado.eliminar('no-existe');
    expect(estado.stickers, hasLength(1));
  });

  test('deshacer recorre el historial en orden', () {
    final a = estado.agregar('🐱');
    estado.cambiarMarco(Marco.polaroid);
    estado.mover(a, const Offset(0.2, 0));
    estado.eliminar(a);

    estado.deshacer();
    expect(estado.stickers.single.posicion.dx, closeTo(0.7, 1e-9));
    estado.deshacer();
    expect(estado.stickers.single.posicion, const Offset(0.5, 0.5));
    estado.deshacer();
    expect(estado.marco, Marco.ninguno);
    estado.deshacer();
    expect(estado.stickers, isEmpty);
    expect(estado.puedeDeshacer, isFalse);
    estado.deshacer(); // no explota sin historial
  });

  test('limpiar borra todo y se puede deshacer', () {
    estado.agregar('🐱');
    estado.agregar(StickersMichi.bigotes);
    estado.cambiarMarco(Marco.huellitas);
    estado.limpiar();
    expect(estado.stickers, isEmpty);
    expect(estado.marco, Marco.ninguno);
    expect(estado.estaVacio, isTrue);
    estado.deshacer();
    expect(estado.stickers, hasLength(2));
    expect(estado.marco, Marco.huellitas);
  });

  test('cambiar al mismo marco no ensucia el historial', () {
    estado.cambiarMarco(Marco.ninguno);
    expect(estado.puedeDeshacer, isFalse);
  });

  test('notifica a los oyentes', () {
    var avisos = 0;
    estado.addListener(() => avisos++);
    final id = estado.agregar('🐾');
    estado.seleccionar(null);
    estado.eliminar(id);
    expect(avisos, 3);
  });
}
