import 'package:flutter/material.dart';

import '../domain/auth_service.dart';
import 'login_page.dart';

/// Muestra [child] si hay sesión iniciada; si no, la pantalla de entrada.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.auth, required this.child});

  final AuthService auth;
  final Widget child;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final _cambios = widget.auth.cambios;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Usuario?>(
      stream: _cambios,
      initialData: widget.auth.actual,
      builder: (context, snap) =>
          snap.data == null ? LoginPage(auth: widget.auth) : widget.child,
    );
  }
}
