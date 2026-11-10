import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movil_app/core/theme/app_theme.dart';
import 'package:movil_app/features/recuerdos/domain/recuerdo.dart';
import 'package:movil_app/features/recuerdos/presentation/recuerdos_page.dart';

class _RepoEnMemoria implements RecuerdoRepository {
  final _datos = <Recuerdo>[];

  @override
  Future<List<Recuerdo>> getAll() async => List.of(_datos.reversed);

  @override
  Future<Recuerdo> add({
    required String sourcePath,
    required int calificacion,
    String nota = '',
  }) async {
    final r = Recuerdo(
      id: '${_datos.length}',
      imagePath: sourcePath,
      fecha: DateTime(2026, 11, 10),
      calificacion: calificacion,
      nota: nota,
    );
    _datos.add(r);
    return r;
  }

  @override
  Future<void> update(Recuerdo recuerdo) async {
    final i = _datos.indexWhere((r) => r.id == recuerdo.id);
    _datos[i] = recuerdo;
  }

  @override
  Future<void> delete(String id) async => _datos.removeWhere((r) => r.id == id);
}

void main() {
  testWidgets('tomar foto, calificarla y guardarla', (tester) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = _RepoEnMemoria();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: RecuerdosPage(
          repository: repo,
          selectorFoto: (_, _) async => '/no/existe/michi.jpg',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Aún no hay recuerdos'), findsOneWidget);

    await tester.tap(find.text('Tomar foto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Selfie con mi michi'));
    await tester.pumpAndSettle();

    // Sin calificación no se puede guardar.
    final guardar = find.ancestor(
      of: find.text('Guardar recuerdo'),
      matching: find.bySubtype<FilledButton>(),
    );
    expect(tester.widget<FilledButton>(guardar).onPressed, isNull);

    await tester.tap(find.bySemanticsLabel('Calificar 5 de 5'));
    await tester.pumpAndSettle();
    expect(find.text('¡Purr-fecto! 😻'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Con Pelusa');
    await tester.ensureVisible(guardar);
    await tester.tap(guardar);
    await tester.pumpAndSettle();

    expect(repo._datos.single.calificacion, 5);
    expect(find.text('Con Pelusa'), findsOneWidget);
    expect(find.textContaining('1 recuerdo · promedio 5.0'), findsOneWidget);

    // Cambiar la calificación desde el detalle.
    await tester.tap(find.text('Con Pelusa'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Calificar 2 de 5'));
    await tester.pumpAndSettle();
    expect(repo._datos.single.calificacion, 2);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.textContaining('promedio 2.0'), findsOneWidget);
  });
}
