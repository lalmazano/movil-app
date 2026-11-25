import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:movil_app/app/app.dart';
import 'package:movil_app/features/listas/data/memoria_lista_repository.dart';
import 'package:movil_app/features/listas/domain/item_lista.dart';
import 'package:movil_app/features/listas/presentation/widgets/comprimir_foto.dart';
import 'package:movil_app/features/listas/presentation/widgets/seccion_fotos.dart';
import 'package:movil_app/features/listas/presentation/widgets/visor_foto.dart';

/// PNG válido de 1×1 píxel.
final png1x1 = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0xCF, 0xC0, 0xF0,
  0x1F, 0x00, 0x05, 0x00, 0x01, 0xFF, 0x89, 0x99, 0x3D, 0x1D, 0x00, 0x00,
  0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

void main() {
  late Uint8List? siguienteFoto;

  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1080, 2400);
    view.devicePixelRatio = 2.5;
    siguienteFoto = png1x1;
    SeccionFotos.selectorPorDefecto = (_) async => siguienteFoto;
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
    SeccionFotos.selectorPorDefecto = seleccionarConImagePicker;
  });

  Future<MemoriaListaRepository> abrirDetalle(WidgetTester tester) async {
    final repo = MemoriaListaRepository(
      autorActual: const Autor(uid: 'u1', nombre: 'Ana López'),
    );
    await repo.add(TipoLista.planes, (
      titulo: 'Picnic en el parque',
      categoria: 'Citas',
      nota: '',
    ));
    await tester.pumpWidget(ClubDelFrijolApp(repository: repo));
    await tester.pump();
    await tester.tap(find.text('Hacer juntos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Picnic en el parque'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Recuerdos 📷'), 200);
    await tester.pumpAndSettle();
    return repo;
  }

  Future<void> agregarDesdeGaleria(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('boton-agregar-foto')));
    await tester.pumpAndSettle();
    expect(find.text('Cámara'), findsOneWidget);
    await tester.tap(find.text('Galería'));
    await tester.pumpAndSettle();
  }

  Future<ItemLista> unico(MemoriaListaRepository repo) async =>
      (await repo.watch(TipoLista.planes).first).single;

  testWidgets('Agregar, ver y borrar una foto de recuerdo', (tester) async {
    final repo = await abrirDetalle(tester);
    expect(find.text('Aún no hay fotos de este recuerdo.'), findsOneWidget);

    await agregarDesdeGaleria(tester);

    expect(find.byType(Image), findsOneWidget);
    expect((await unico(repo)).fotos, 1);

    await tester.tap(find.byType(Image));
    await tester.pumpAndSettle();
    expect(find.byType(VisorFoto), findsOneWidget);
    expect(find.textContaining('Agregada por Ana'), findsOneWidget);
    expect(find.text('1 de 1'), findsOneWidget);

    await tester.tap(find.byTooltip('Borrar foto'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Borrar'));
    await tester.pumpAndSettle();

    expect(find.byType(VisorFoto), findsNothing);
    expect(find.byType(Image), findsNothing);
    expect(find.text('Aún no hay fotos de este recuerdo.'), findsOneWidget);
    expect((await unico(repo)).fotos, 0);
  });

  testWidgets('Una foto demasiado pesada muestra un aviso', (tester) async {
    final repo = await abrirDetalle(tester);
    // Bytes que no son una imagen y pasan del límite: no se pueden reducir.
    siguienteFoto = Uint8List(maxBytesFoto + 1);

    await agregarDesdeGaleria(tester);

    expect(find.text('La foto es muy pesada'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect((await unico(repo)).fotos, 0);
  });

  test('reducirFoto deja pasar fotos chicas y rechaza basura', () async {
    expect(await reducirFoto(png1x1), same(png1x1));
    expect(await reducirFoto(Uint8List(maxBytesFoto + 1)), isNull);
  });

  test('reducirFoto recomprime un JPEG pesado por debajo del límite', () async {
    // Ruido aleatorio en calidad 100: comprime muy mal y pasa de 900 KB.
    final imagen = img.Image(width: 1600, height: 1200);
    var semilla = 7;
    for (final p in imagen) {
      semilla = (semilla * 1103515245 + 12345) & 0x7fffffff;
      p.setRgb(semilla & 0xff, (semilla >> 8) & 0xff, (semilla >> 16) & 0xff);
    }
    final pesada = img.encodeJpg(imagen, quality: 100);
    expect(pesada.length, greaterThan(maxBytesFoto));

    final reducida = await reducirFoto(pesada);
    expect(reducida, isNotNull);
    expect(reducida!.length, lessThanOrEqualTo(maxBytesFoto));
    expect(img.decodeJpg(reducida), isNotNull);
  });
}
