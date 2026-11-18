import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:movil_app/app/app.dart';
import 'package:movil_app/features/auth/domain/auth_service.dart';
import 'package:movil_app/features/listas/data/memoria_lista_repository.dart';

class _AuthFalso implements AuthService {
  final _controller = StreamController<Usuario?>.broadcast();

  @override
  Usuario? actual;

  @override
  Stream<Usuario?> get cambios => _controller.stream;

  @override
  Future<bool> entrarConGoogle() async {
    actual = const Usuario(
      id: '1',
      nombre: 'Josué Almazán',
      correo: 'josue@example.com',
    );
    _controller.add(actual);
    return true;
  }

  @override
  Future<void> salir() async {
    actual = null;
    _controller.add(null);
  }
}

void main() {
  testWidgets('Sin sesión pide entrar con Google y luego muestra el club', (
    tester,
  ) async {
    final auth = _AuthFalso();
    await tester.pumpWidget(
      ClubDelFrijolApp(repository: MemoriaListaRepository(), auth: auth),
    );
    await tester.pump();
    expect(find.text('Entrar con Google'), findsOneWidget);

    await tester.tap(find.text('Entrar con Google'));
    await tester.pumpAndSettle();
    expect(find.text('¡Hola, Josué!'), findsOneWidget);
    expect(find.text('Películas'), findsOneWidget);

    await tester.tap(find.byTooltip('Cuenta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();
    expect(find.text('Entrar con Google'), findsOneWidget);
  });
}
