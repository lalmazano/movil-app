import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movil_app/core/theme/app_theme.dart';
import 'package:movil_app/features/editor_foto/domain/editor_estado.dart';
import 'package:movil_app/features/editor_foto/presentation/editor_foto_page.dart';

/// Abre el editor desde un botón y guarda lo que devuelve el `pop`.
class _Lanzador extends StatelessWidget {
  const _Lanzador({required this.onResultado, this.dirSalida});

  final void Function(String?) onResultado;
  final Future<Directory> Function()? dirSalida;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            final r = await Navigator.of(context).push<String>(
              MaterialPageRoute(
                builder: (_) => EditorFotoPage(
                  fotoPath: '/no/existe/michi.jpg',
                  dirSalida: dirSalida,
                ),
              ),
            );
            onResultado(r);
          },
          child: const Text('abrir'),
        ),
      ),
    );
  }
}

void main() {
  late Directory tmp;
  var resultado = 'sin-resultado' as String?;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('editor_foto_test');
    resultado = 'sin-resultado';
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  Future<void> abrir(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: _Lanzador(
          onResultado: (r) => resultado = r,
          dirSalida: () async => tmp,
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.byType(EditorFotoPage), findsOneWidget);
  }

  EditorEstado estadoDe(WidgetTester tester) => tester
      .widgetList<ListenableBuilder>(find.byType(ListenableBuilder))
      .map((w) => w.listenable)
      .whereType<EditorEstado>()
      .single;

  Finder stickers() => find.byWidgetPredicate(
    (w) =>
        w is GestureDetector &&
        w.key is ValueKey<String> &&
        (w.key! as ValueKey<String>).value.startsWith('sticker-'),
  );

  Future<void> elegirMarco(WidgetTester tester, String nombre) async {
    final chip = find.byKey(ValueKey('chip-marco-$nombre'));
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
  }

  Future<void> agregar(WidgetTester tester, String sticker) async {
    final boton = find.byKey(ValueKey('bandeja-$sticker'));
    await tester.scrollUntilVisible(
      boton,
      80,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('bandeja-stickers')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(boton);
  }

  testWidgets('agrega sticker, elige marco, deshace y limpia', (tester) async {
    await abrir(tester);
    expect(find.text('Decorar ✨'), findsOneWidget);
    expect(stickers(), findsNothing);

    await agregar(tester, '👑');
    await tester.pump();
    expect(stickers(), findsOneWidget);
    expect(find.byKey(const ValueKey('seleccion-sticker')), findsOneWidget);
    expect(find.byKey(const ValueKey('quitar-sticker')), findsOneWidget);

    await elegirMarco(tester, 'polaroid');
    await tester.pump();
    expect(find.text('Mi michi 🐾'), findsOneWidget);
    final chip = tester.widget<ChoiceChip>(
      find.byKey(const ValueKey('chip-marco-polaroid')),
    );
    expect(chip.selected, isTrue);

    // Arrastrar el sticker lo mueve.
    final estado = estadoDe(tester);
    final antes = estado.stickers.single.posicion;
    await tester.drag(stickers(), const Offset(40, 60));
    await tester.pump();
    expect(estado.stickers.single.posicion.dx, greaterThan(antes.dx));
    expect(estado.stickers.single.posicion.dy, greaterThan(antes.dy));

    // Tocar la foto deselecciona.
    await tester.tapAt(
      tester.getTopLeft(find.byType(AspectRatio)) + const Offset(30, 30),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('seleccion-sticker')), findsNothing);

    await tester.tap(find.byTooltip('Deshacer')); // deshace el arrastre
    await tester.pump();
    expect(estado.stickers.single.posicion, antes);

    await tester.tap(find.byTooltip('Limpiar'));
    await tester.pump();
    expect(stickers(), findsNothing);
    expect(find.text('Mi michi 🐾'), findsNothing);

    await tester.tap(find.byTooltip('Deshacer'));
    await tester.pump();
    expect(stickers(), findsOneWidget);
    expect(find.text('Mi michi 🐾'), findsOneWidget);
  });

  testWidgets('quitar y mantener presionado eliminan stickers', (tester) async {
    await abrir(tester);
    await agregar(tester, 'orejitas');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('quitar-sticker')));
    await tester.pump();
    expect(stickers(), findsNothing);

    await agregar(tester, '🐟');
    await tester.pump();
    await tester.longPress(stickers());
    await tester.pump();
    expect(stickers(), findsNothing);
  });

  testWidgets('arrastrar el sticker de abajo lo trae al frente', (
    tester,
  ) async {
    await abrir(tester);
    await agregar(tester, '🐱');
    await tester.pump();
    final estado = estadoDe(tester);
    estado.mover(estado.stickers.single.id, const Offset(-0.2, 0));
    await agregar(tester, '😻');
    await tester.pump();
    final abajo = estado.stickers.first;

    await tester.drag(
      find.byKey(ValueKey('sticker-${abajo.id}')),
      const Offset(0, 80),
    );
    await tester.pump();
    expect(estado.stickers.last.id, abajo.id);
    expect(estado.stickers.last.posicion.dy, greaterThan(abajo.posicion.dy));
    expect(estado.seleccionadoId, abajo.id);
  });

  testWidgets('cancelar devuelve null', (tester) async {
    await abrir(tester);
    await tester.tap(find.byTooltip('Cancelar'));
    await tester.pumpAndSettle();
    expect(resultado, isNull);
  });

  testWidgets('Listo exporta un PNG y devuelve su ruta', (tester) async {
    await abrir(tester);
    await agregar(tester, '✨');
    await elegirMarco(tester, 'huellitas');
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('editor-listo')));
    // toImage/toByteData/escritura son asíncronos reales: se alterna tiempo
    // real (runAsync) con pumps para que avance la continuación.
    for (var i = 0; i < 100 && resultado == 'sin-resultado'; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(resultado, isNotNull);
    expect(resultado, isNot('sin-resultado'));
    final archivo = File(resultado!);
    expect(archivo.parent.path, tmp.path);
    expect(archivo.uri.pathSegments.last, startsWith('michi_editado_'));
    expect(archivo.path, endsWith('.png'));
    final bytes = archivo.readAsBytesSync();
    // Firma PNG.
    expect(bytes.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
    // Ancho ~1080 px (bytes 16..19 del IHDR, big-endian).
    final ancho =
        (bytes[16] << 24) | (bytes[17] << 16) | (bytes[18] << 8) | bytes[19];
    expect(ancho, closeTo(1080, 2));
  });
}
