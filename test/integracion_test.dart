import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movil_app/core/theme/app_theme.dart';
import 'package:movil_app/features/editor_foto/presentation/editor_foto_page.dart';
import 'package:movil_app/features/home/presentation/home_page.dart';
import 'package:movil_app/features/recuerdos/presentation/nuevo_recuerdo_page.dart';
import 'package:movil_app/features/sonidos/domain/servicio_sonidos.dart';

import 'support/michis_fakes.dart';

void main() {
  testWidgets('acariciar al michi maúlla y cada 5 caricias ronronea', (
    tester,
  ) async {
    final sonidos = ServicioSonidosSilencioso();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: HomePage(michiRepository: MichiRepoEnMemoria(), sonidos: sonidos),
      ),
    );
    await tester.pumpAndSettle();
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byKey(const ValueKey('michi-interactivo')));
      await tester.pumpAndSettle();
    }
    expect(sonidos.llamadas.where((s) => s == 'maullar'), hasLength(5));
    expect(sonidos.llamadas.where((s) => s == 'ronronear'), hasLength(1));

    // Silenciar desde el botón de la barra.
    await tester.tap(find.byIcon(Icons.volume_up));
    await tester.pumpAndSettle();
    expect(sonidos.activado, isFalse);
  });

  testWidgets('Nuevo recuerdo abre el editor con "Decorar"', (tester) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: NuevoRecuerdoPage(
          fotoPath: '/no/existe.jpg',
          repository: RecuerdoRepoEnMemoria(),
          michiRepository: MichiRepoEnMemoria(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Decorar ✨'));
    await tester.pumpAndSettle();
    expect(find.byType(EditorFotoPage), findsOneWidget);
  });
}
