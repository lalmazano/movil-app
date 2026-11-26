import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movil_app/features/actualizacion/domain/version_app.dart';
import 'package:movil_app/features/actualizacion/presentation/aviso_actualizacion.dart';
import 'package:movil_app/features/listas/data/memoria_lista_repository.dart';
import 'package:movil_app/features/listas/domain/config_club.dart';
import 'package:movil_app/features/listas/presentation/config_scope.dart';

const _v120 = VersionApp(
  version: '1.2.0',
  build: 5,
  url: 'https://ejemplo.web.app/apk/club-del-frijol.apk',
  notas: '• Ruleta nueva',
);

Widget _app(
  MemoriaListaRepository repo, {
  int instalado = 3,
  Instalador? instalador,
  ConfigClub config = const ConfigClub(),
}) => MaterialApp(
  home: ConfigClubScope(
    config: config,
    child: Scaffold(
      body: AvisoActualizacion(
        repository: repo,
        soportado: true,
        leerBuild: () async => instalado,
        instalador: instalador ?? (_) => const Stream.empty(),
      ),
    ),
  ),
);

void main() {
  test('VersionApp.fromMap exige build y url', () {
    expect(VersionApp.fromMap(null), isNull);
    expect(VersionApp.fromMap({'build': 2}), isNull);
    final v = VersionApp.fromMap({
      'version': '1.1.0',
      'build': 2,
      'url': 'https://x/y.apk',
      'obligatoria': true,
    });
    expect(v?.build, 2);
    expect(v?.obligatoria, isTrue);
  });

  testWidgets('Con versión nueva muestra el diálogo y descarga', (
    tester,
  ) async {
    final progreso = StreamController<double>();
    await tester.pumpWidget(
      _app(
        MemoriaListaRepository(version: _v120),
        instalador: (_) => progreso.stream,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('🎁 Versión 1.2.0'), findsOneWidget);
    expect(find.text('• Ruleta nueva'), findsOneWidget);

    await tester.tap(find.text('Actualizar'));
    await tester.pump();
    progreso.add(40);
    await tester.pump();
    expect(find.text('Descargando… 40 %'), findsOneWidget);

    progreso.addError(const ActualizacionException('Sin permiso'));
    await tester.pump();
    expect(find.text('Sin permiso'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
    await progreso.close();
  });

  testWidgets('"Después" cierra y deja la tarjeta en el inicio', (
    tester,
  ) async {
    await tester.pumpWidget(_app(MemoriaListaRepository(version: _v120)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Después'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('aviso-actualizacion')), findsOneWidget);
  });

  testWidgets('Obligatoria: no hay botón "Después"', (tester) async {
    await tester.pumpWidget(
      _app(
        MemoriaListaRepository(
          version: const VersionApp(
            version: '2.0.0',
            build: 9,
            url: 'https://x/y.apk',
            obligatoria: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Después'), findsNothing);
    expect(find.textContaining('necesaria'), findsOneWidget);
  });

  testWidgets('Misma versión o bandera apagada: no avisa', (tester) async {
    await tester.pumpWidget(
      _app(MemoriaListaRepository(version: _v120), instalado: 5),
    );
    await tester.pumpAndSettle();
    expect(find.text('🎁 Versión 1.2.0'), findsNothing);
    expect(find.byKey(const Key('aviso-actualizacion')), findsNothing);

    await tester.pumpWidget(
      _app(
        MemoriaListaRepository(version: _v120),
        config: const ConfigClub(actualizaciones: false),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('🎁 Versión 1.2.0'), findsNothing);
  });
}
