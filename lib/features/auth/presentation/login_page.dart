import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/club_logo.dart';
import '../../../core/widgets/paw_background.dart';
import '../domain/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.auth});

  final AuthService auth;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _cargando = false;

  Future<void> _entrar() async {
    setState(() => _cargando = true);
    try {
      await widget.auth.entrarConGoogle();
    } catch (e) {
      debugPrint('Error al entrar con Google: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo entrar con Google. Intenta de nuevo.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: PawBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  const ClubLogo(radio: 80),
                  const SizedBox(height: 24),
                  Text(
                    AppConstants.appName,
                    textAlign: TextAlign.center,
                    style: textTheme.headlineMedium?.copyWith(
                      fontFamily: familiaLogotipo,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Películas, deseos y planes para hacer juntos',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 40),
                  FilledButton.icon(
                    onPressed: _cargando ? null : _entrar,
                    icon: _cargando
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login),
                    label: const Text('Entrar con Google'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
