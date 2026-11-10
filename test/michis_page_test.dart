import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movil_app/core/theme/app_theme.dart';
import 'package:movil_app/features/michis/domain/michi.dart';
import 'package:movil_app/features/michis/presentation/michis_page.dart';
import 'package:movil_app/features/michis/presentation/widgets/michi_textos.dart';

import 'support/michis_fakes.dart';

void main() {
  testWidgets('crear, ver, editar y borrar un michi', (tester) async {
    tester.view.physicalSize = const Size(500, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final michis = MichiRepoEnMemoria();
    final recuerdos = RecuerdoRepoEnMemoria([
      recuerdoDePrueba('a', DateTime(2026, 1, 1), 4),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MichisPage(
          repository: michis,
          recuerdoRepository: recuerdos,
          selectorFoto: (_) async => '/no/existe/perfil.jpg',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Aún no hay michis'), findsOneWidget);

    // Crear: el nombre es obligatorio.
    await tester.tap(find.text('Nuevo michi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar michi'));
    await tester.pumpAndSettle();
    expect(find.text('¿Cómo se llama tu michi? 🐾'), findsOneWidget);
    expect(michis.datos, isEmpty);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nombre'),
      'Pelusa',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Raza (opcional)'),
      'Siamés',
    );
    await tester.tap(find.text('🐯'));
    await tester.tap(find.byTooltip('Cambiar foto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elegir de la galería'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fecha de nacimiento'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar michi'));
    await tester.pumpAndSettle();

    final pelusa = michis.datos.single;
    expect(pelusa.nombre, 'Pelusa');
    expect(pelusa.raza, 'Siamés');
    expect(pelusa.emoji, '🐯');
    expect(pelusa.fotoPath, '/no/existe/perfil.jpg');
    expect(pelusa.nacimiento, isNotNull);
    expect(
      find.textContaining('Bienvenido a la familia, Pelusa'),
      findsOneWidget,
    );
    expect(find.text('Siamés · 1 año'), findsOneWidget);

    // Un recuerdo etiquetado con Pelusa.
    recuerdos.datos.add(
      recuerdoDePrueba('b', DateTime(2026, 2, 1), 5, michiId: pelusa.id),
    );

    // Nació hace justo un año (fecha por defecto del selector): ¡cumpleaños!
    expect(find.text('Pelusa 🎂'), findsOneWidget);

    // Perfil.
    await tester.tap(find.text('Pelusa 🎂'));
    await tester.pumpAndSettle();
    expect(find.text('1 año'), findsOneWidget);
    expect(find.text('1 recuerdo juntos'), findsOneWidget);
    expect(find.textContaining('¡Hoy es su cumpleaños!'), findsOneWidget);

    // Editar.
    await tester.tap(find.byTooltip('Editar'));
    await tester.pumpAndSettle();
    expect(find.text('Editar michi'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Pelusa'),
      'Pelusita',
    );
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();
    expect(michis.datos.single.nombre, 'Pelusita');
    expect(find.text('Pelusita 🐯'), findsOneWidget);

    // Volver: la lista se actualiza.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Pelusita 🎂'), findsOneWidget);

    // Borrar, primero cancelando.
    await tester.tap(find.text('Pelusita 🎂'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Borrar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(michis.datos, hasLength(1));

    await tester.tap(find.byTooltip('Borrar'));
    await tester.pumpAndSettle();
    expect(find.text('¿Borrar a Pelusita? 🙀'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Borrar'));
    await tester.pumpAndSettle();
    expect(michis.datos, isEmpty);
    expect(recuerdos.datos.every((r) => r.michiId == null), isTrue);
    expect(find.textContaining('Aún no hay michis'), findsOneWidget);
  });

  test('describirEdad', () {
    final hoy = DateTime(2026, 11, 10);
    Michi m(DateTime? n) => Michi(id: 'x', nombre: 'x', nacimiento: n);
    expect(describirEdad(m(null), hoy), isNull);
    expect(describirEdad(m(DateTime(2020, 11, 10)), hoy), '6 años');
    expect(describirEdad(m(DateTime(2025, 11, 11)), hoy), '11 meses');
    expect(describirEdad(m(DateTime(2026, 10, 1)), hoy), '1 mes');
    expect(describirEdad(m(DateTime(2026, 11, 1)), hoy), 'Recién nacido 🍼');
  });
}
