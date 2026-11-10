import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/paw_background.dart';
import '../data/local_michi_fact_repository.dart';
import '../domain/michi_fact.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    this.repository = const LocalMichiFactRepository(),
  });

  final MichiFactRepository repository;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _michis = ['🐱', '😺', '😸', '😻', '😽', '😹', '🐈', '🐈‍⬛'];

  final _random = Random();
  int _michiIndex = 0;
  int _caricias = 0;
  MichiFact? _fact;

  void _acariciar() {
    setState(() {
      _caricias++;
      _michiIndex = (_michiIndex + 1) % _michis.length;
    });
  }

  void _nuevoDato() {
    final facts = widget.repository.getAll();
    setState(() => _fact = facts[_random.nextInt(facts.length)]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('🐾 ${AppConstants.appName} 🐾')),
      body: PawBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                GestureDetector(
                  onTap: _acariciar,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, anim) =>
                        ScaleTransition(scale: anim, child: child),
                    child: CircleAvatar(
                      key: ValueKey(_michiIndex),
                      radius: 72,
                      backgroundColor: theme.colorScheme.secondary.withValues(
                        alpha: 0.35,
                      ),
                      child: Text(
                        _michis[_michiIndex],
                        style: const TextStyle(fontSize: 80),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('¡Miau! Bienvenido', style: textTheme.headlineMedium),
                const SizedBox(height: 4),
                Text(
                  _caricias == 0
                      ? 'Toca al michi para acariciarlo'
                      : 'Caricias: $_caricias ${'❤' * min(_caricias, 5)}',
                  style: textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text('Dato michi', style: textTheme.titleLarge),
                        const SizedBox(height: 8),
                        Text(
                          _fact?.text ?? 'Pide un dato curioso sobre gatos.',
                          textAlign: TextAlign.center,
                          style: textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _nuevoDato,
                          icon: const Icon(Icons.pets),
                          label: const Text('Otro dato'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
