import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/widgets/club_logo.dart';
import '../../../core/widgets/paw_background.dart';
import '../../listas/domain/item_lista.dart';
import '../data/local_michi_fact_repository.dart';
import '../domain/michi_fact.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.repository,
    this.facts = const LocalMichiFactRepository(),
  });

  final ListaRepository repository;
  final MichiFactRepository facts;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _random = Random();
  MichiFact? _fact;

  void _nuevoDato() {
    final facts = widget.facts.getAll();
    setState(() => _fact = facts[_random.nextInt(facts.length)]);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('🫘 ${AppConstants.appName}')),
      body: PawBackground(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Center(child: ClubLogo()),
            const SizedBox(height: 12),
            Text(
              'Bienvenidos al club',
              textAlign: TextAlign.center,
              style: textTheme.headlineSmall,
            ),
            Text(
              'Lo que queremos ver, desear y hacer juntos',
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge,
            ),
            if (!widget.repository.enLaNube) ...[
              const SizedBox(height: 12),
              const _AvisoModoLocal(),
            ],
            const SizedBox(height: 16),
            for (final tipo in TipoLista.values)
              _TarjetaLista(tipo: tipo, repository: widget.repository),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Text('📸', style: TextStyle(fontSize: 32)),
                title: const Text('Recuerdos con el michi'),
                subtitle: const Text('Fotos calificadas con huellitas'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    Navigator.of(context).pushNamed(AppRoutes.recuerdos),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Text('🐱', style: TextStyle(fontSize: 32)),
                title: const Text('Dato michi'),
                subtitle: Text(
                  _fact?.text ?? 'Toca para un dato curioso sobre gatos.',
                ),
                onTap: _nuevoDato,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TarjetaLista extends StatefulWidget {
  const _TarjetaLista({required this.tipo, required this.repository});

  final TipoLista tipo;
  final ListaRepository repository;

  @override
  State<_TarjetaLista> createState() => _TarjetaListaState();
}

class _TarjetaListaState extends State<_TarjetaLista> {
  late final _items = widget.repository.watch(widget.tipo);

  @override
  Widget build(BuildContext context) {
    final tipo = widget.tipo;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () =>
            Navigator.of(context).pushNamed(AppRoutes.lista, arguments: tipo),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: StreamBuilder<List<ItemLista>>(
            stream: _items,
            builder: (context, snap) {
              final items = snap.data ?? const <ItemLista>[];
              final hechos = items.where((i) => i.hecho).length;
              return Row(
                children: [
                  Text(tipo.emoji, style: const TextStyle(fontSize: 40)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tipo.titulo, style: textTheme.titleLarge),
                        const SizedBox(height: 4),
                        Text(
                          items.isEmpty
                              ? 'Lista vacía'
                              : '$hechos de ${items.length} ${tipo.hechos}',
                          style: textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: items.isEmpty ? 0 : hechos / items.length,
                            minHeight: 8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AvisoModoLocal extends StatelessWidget {
  const _AvisoModoLocal();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          '☁️ Modo local: Firebase no está configurado, así que los cambios '
          'no se guardan en la nube. Ejecuta `flutterfire configure`.',
          style: TextStyle(color: scheme.onErrorContainer),
        ),
      ),
    );
  }
}
