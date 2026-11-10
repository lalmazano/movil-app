import 'package:flutter/material.dart';

import 'paw_background.dart';

class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('No encontrado')),
      body: PawBackground(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🙀', style: TextStyle(fontSize: 72)),
              const SizedBox(height: 12),
              Text(
                'Un michi se llevó esta página.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
