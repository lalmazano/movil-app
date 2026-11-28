import 'package:flutter/material.dart';

import '../../../core/widgets/club_logo.dart';
import '../../../core/widgets/paw_background.dart';
import '../domain/auth_service.dart';
import 'login_page.dart';

/// Muestra [child] solo si hay sesión iniciada y el usuario es miembro del
/// club. Si no hay sesión, muestra la entrada; si el registro está cerrado,
/// avisa.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.auth, required this.child});

  final AuthService auth;
  final Widget child;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final _cambios = widget.auth.cambios;
  String? _uidRevisado;
  Future<bool>? _registro;

  Future<bool> _registroDe(Usuario usuario) {
    if (_uidRevisado != usuario.id || _registro == null) {
      _uidRevisado = usuario.id;
      _registro = widget.auth.asegurarRegistro();
    }
    return _registro!;
  }

  void _reintentar() => setState(() => _registro = null);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Usuario?>(
      stream: _cambios,
      initialData: widget.auth.actual,
      builder: (context, snap) {
        final usuario = snap.data;
        if (usuario == null) {
          _uidRevisado = null;
          return LoginPage(auth: widget.auth);
        }
        return FutureBuilder<bool>(
          future: _registroDe(usuario),
          builder: (context, registro) {
            if (registro.hasError) {
              return _Aviso(
                texto: 'No se pudo comprobar tu acceso al club.',
                accion: 'Reintentar',
                onAccion: _reintentar,
                auth: widget.auth,
              );
            }
            if (!registro.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (!registro.data!) {
              return _Aviso(
                texto:
                    'El registro del club está cerrado.\n'
                    'Pide que te dejen entrar 🫘',
                auth: widget.auth,
              );
            }
            return widget.child;
          },
        );
      },
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({
    required this.texto,
    required this.auth,
    this.accion,
    this.onAccion,
  });

  final String texto;
  final AuthService auth;
  final String? accion;
  final VoidCallback? onAccion;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PawBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                const ClubLogo(radio: 64),
                const SizedBox(height: 24),
                TextoConGatito(
                  texto,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 24),
                if (accion != null)
                  FilledButton(onPressed: onAccion, child: Text(accion!)),
                TextButton.icon(
                  onPressed: auth.salir,
                  icon: const Icon(Icons.logout),
                  label: const Text('Usar otra cuenta'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
