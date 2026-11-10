import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movil_app/core/theme/app_theme.dart';
import 'package:movil_app/features/juego/presentation/juego_page.dart';
import 'package:movil_app/features/sonidos/domain/servicio_sonidos.dart';

void main() {
  late ServicioSonidosSilencioso sonidos;

  Future<void> abrirYJugar(WidgetTester tester) async {
    sonidos = ServicioSonidosSilencioso();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: JuegoPage(sonidos: sonidos, random: Random(42)),
      ),
    );
    await tester.tap(find.text('¡A jugar!'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
  }

  testWidgets('muestra el menú con presa y velocidad', (tester) async {
    sonidos = ServicioSonidosSilencioso();
    await tester.pumpWidget(MaterialApp(home: JuegoPage(sonidos: sonidos)));
    expect(find.text('Juego para michi'), findsOneWidget);
    expect(find.text('🐭 Ratón'), findsOneWidget);
    expect(find.text('Rápido'), findsOneWidget);
    expect(find.text('¡A jugar!'), findsOneWidget);
  });

  testWidgets('tocar la presa suma atrapadas y hace "pop"', (tester) async {
    await abrirYJugar(tester);
    expect(find.text('¡Atrapadas: 0!'), findsOneWidget);

    // Deja que se mueva un poco.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    await tester.tapAt(tester.getCenter(find.byKey(const Key('presa'))));
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.text('¡Atrapadas: 1!'), findsOneWidget);
    expect(sonidos.llamadas, ['pop']);
    expect(find.text('✨'), findsWidgets);

    await tester.tapAt(tester.getCenter(find.byKey(const Key('presa'))));
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.text('¡Atrapadas: 2!'), findsOneWidget);

    // El destello desaparece.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.text('✨'), findsNothing);

    await tester.longPress(find.byKey(const Key('salir-juego')));
    await tester.pump();
  });

  testWidgets('tocar lejos de la presa no suma', (tester) async {
    await abrirYJugar(tester);
    final presa = tester.getCenter(find.byKey(const Key('presa')));
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    final lejos = Offset(
      presa.dx > size.width / 2 ? 20 : size.width - 20,
      presa.dy > size.height / 2 ? 100 : size.height - 20,
    );
    await tester.tapAt(lejos);
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.text('¡Atrapadas: 0!'), findsOneWidget);
    expect(sonidos.llamadas, isEmpty);

    await tester.longPress(find.byKey(const Key('salir-juego')));
    await tester.pump();
  });

  testWidgets('salir requiere pulsación larga', (tester) async {
    await abrirYJugar(tester);
    await tester.tapAt(tester.getCenter(find.byKey(const Key('presa'))));
    await tester.pump(const Duration(milliseconds: 16));

    // Un toque normal no sale.
    await tester.tap(find.byKey(const Key('salir-juego')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('Atrapadas'), findsOneWidget);

    await tester.longPress(find.byKey(const Key('salir-juego')));
    await tester.pump();
    expect(find.textContaining('Atrapadas'), findsNothing);
    expect(find.text('¡A jugar!'), findsOneWidget);
    expect(find.text('¡Tu michi atrapó 1! 🏆'), findsOneWidget);
  });
}
