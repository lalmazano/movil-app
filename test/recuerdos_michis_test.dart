import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movil_app/core/theme/app_theme.dart';
import 'package:movil_app/features/michis/domain/michi.dart';
import 'package:movil_app/features/recuerdos/domain/recuerdo.dart';
import 'package:movil_app/features/recuerdos/domain/recuerdo_acciones.dart';
import 'package:movil_app/features/recuerdos/presentation/recuerdos_page.dart';

import 'support/michis_fakes.dart';

class _SinAcciones implements RecuerdoAcciones {
  @override
  Future<void> compartir(Recuerdo recuerdo) async {}

  @override
  Future<void> guardarEnGaleria(Recuerdo recuerdo) async {}
}

const _pelusa = Michi(id: 'p', nombre: 'Pelusa');
const _tom = Michi(id: 't', nombre: 'Tom', emoji: '🐯');

Future<void> _abrir(
  WidgetTester tester,
  RecuerdoRepoEnMemoria repo, {
  List<Michi> michis = const [_pelusa, _tom],
}) async {
  tester.view.physicalSize = const Size(500, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: RecuerdosPage(
        repository: repo,
        michiRepository: MichiRepoEnMemoria(michis),
        selectorFoto: (_, _) async => '/no/existe/nueva.jpg',
        acciones: _SinAcciones(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Notas de las tarjetas en el orden en que se muestran.
List<String> _notas(WidgetTester tester) {
  final textos = tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? '')
      .where((t) => t.startsWith('nota '))
      .toList();
  return textos;
}

void main() {
  testWidgets('etiquetar al michi al crear y cambiarlo en el detalle', (
    tester,
  ) async {
    final repo = RecuerdoRepoEnMemoria();
    await _abrir(tester, repo);

    await tester.tap(find.text('Tomar foto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elegir de la galería'));
    await tester.pumpAndSettle();

    expect(find.text('¿Qué michi sale en la foto?'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Pelusa'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Calificar 4 de 5'));
    await tester.pumpAndSettle();
    final guardar = find.ancestor(
      of: find.text('Guardar recuerdo'),
      matching: find.bySubtype<FilledButton>(),
    );
    await tester.ensureVisible(guardar);
    await tester.tap(guardar);
    await tester.pumpAndSettle();

    expect(repo.datos.single.michiId, 'p');
    // La tarjeta muestra la etiqueta del michi (además del chip de filtro).
    expect(find.text('Pelusa'), findsNWidgets(2));

    // Cambiar a Tom desde el detalle.
    await tester.tap(find.text('10/11/2026 12:00'));
    await tester.pumpAndSettle();
    expect(find.text('Recuerdo'), findsOneWidget);
    final chipPelusa = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'Pelusa'),
    );
    expect(chipPelusa.selected, isTrue);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Tom'));
    await tester.pumpAndSettle();
    expect(repo.datos.single.michiId, 't');

    // Tocar el elegido lo quita.
    await tester.tap(find.widgetWithText(ChoiceChip, 'Tom'));
    await tester.pumpAndSettle();
    expect(repo.datos.single.michiId, isNull);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Tom'));
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Tom'), findsNWidgets(2));
    expect(find.text('Pelusa'), findsOneWidget);
  });

  testWidgets('sin michis no aparece el selector', (tester) async {
    await _abrir(tester, RecuerdoRepoEnMemoria(), michis: []);
    await tester.tap(find.text('Tomar foto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elegir de la galería'));
    await tester.pumpAndSettle();
    expect(find.text('¿Qué michi sale en la foto?'), findsNothing);
  });

  testWidgets('ordenar y filtrar recuerdos', (tester) async {
    final repo = RecuerdoRepoEnMemoria([
      recuerdoDePrueba(
        '1',
        DateTime(2026, 10, 5),
        5,
        nota: 'nota octubre',
        michiId: 'p',
      ),
      recuerdoDePrueba(
        '2',
        DateTime(2026, 11, 2),
        2,
        nota: 'nota nov tom',
        michiId: 't',
      ),
      recuerdoDePrueba(
        '3',
        DateTime(2026, 11, 8),
        3,
        nota: 'nota nov pelusa',
        michiId: 'p',
      ),
    ]);
    await _abrir(tester, repo);

    expect(find.text('3 recuerdos · promedio 3.3 🐾'), findsOneWidget);
    expect(_notas(tester), ['nota nov pelusa', 'nota nov tom', 'nota octubre']);

    // Orden.
    await tester.tap(find.text('Más recientes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Más antiguos'));
    await tester.pumpAndSettle();
    expect(_notas(tester), ['nota octubre', 'nota nov tom', 'nota nov pelusa']);

    await tester.tap(find.text('Más antiguos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mejor calificadas'));
    await tester.pumpAndSettle();
    expect(_notas(tester), ['nota octubre', 'nota nov pelusa', 'nota nov tom']);

    // Filtro por michi.
    await tester.tap(find.widgetWithText(FilterChip, 'Pelusa'));
    await tester.pumpAndSettle();
    expect(_notas(tester), ['nota octubre', 'nota nov pelusa']);
    expect(find.text('2 recuerdos · promedio 4.0 🐾'), findsOneWidget);

    // Filtro por mes (además del michi).
    await tester.tap(find.text('Todos los meses'));
    await tester.pumpAndSettle();
    expect(find.text('octubre 2026'), findsOneWidget);
    await tester.tap(find.text('noviembre 2026'));
    await tester.pumpAndSettle();
    expect(_notas(tester), ['nota nov pelusa']);
    expect(find.text('1 recuerdo · promedio 3.0 🐾'), findsOneWidget);

    // Sin resultados.
    await tester.tap(find.widgetWithText(FilterChip, 'noviembre 2026'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('octubre 2026'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Tom'));
    await tester.pumpAndSettle();
    expect(
      find.text('Ningún recuerdo coincide con los filtros.'),
      findsOneWidget,
    );
    expect(find.text('0 recuerdos 🐾'), findsOneWidget);

    await tester.tap(find.text('Quitar filtros'));
    await tester.pumpAndSettle();
    expect(find.text('3 recuerdos · promedio 3.3 🐾'), findsOneWidget);
    expect(find.text('Limpiar'), findsNothing);
  });
}
