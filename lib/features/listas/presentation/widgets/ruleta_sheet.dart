import 'dart:math';

import 'package:flutter/material.dart';

import '../../domain/item_lista.dart';

/// Texto de la ruleta según la lista: "¿Qué vemos hoy?" o "¿Qué hacemos hoy?".
String tituloRuleta(TipoLista tipo) =>
    tipo == TipoLista.peliculas ? '¿Qué vemos hoy?' : '¿Qué hacemos hoy?';

/// Abre la ruleta con los pendientes de [items]. Devuelve el elemento elegido
/// si tocan "Ver", o null si cierran la hoja.
///
/// [categorias] da el orden de los chips; [random] permite pruebas
/// deterministas.
Future<ItemLista?> mostrarRuleta(
  BuildContext context, {
  required TipoLista tipo,
  required List<ItemLista> items,
  List<String> categorias = const [],
  Random? random,
}) => showModalBottomSheet<ItemLista>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => RuletaSheet(
    tipo: tipo,
    items: items,
    categorias: categorias,
    random: random,
  ),
);

enum _Fase { inicio, girando, listo }

/// Hoja de la ruleta: elige al azar un elemento pendiente.
class RuletaSheet extends StatefulWidget {
  const RuletaSheet({
    super.key,
    required this.tipo,
    required this.items,
    this.categorias = const [],
    this.random,
  });

  final TipoLista tipo;
  final List<ItemLista> items;
  final List<String> categorias;
  final Random? random;

  @override
  State<RuletaSheet> createState() => _RuletaSheetState();
}

class _RuletaSheetState extends State<RuletaSheet>
    with SingleTickerProviderStateMixin {
  late final Random _random = widget.random ?? Random();
  late final AnimationController _giro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..addStatusListener(_alTerminar);
  late final Animation<double> _avance = CurvedAnimation(
    parent: _giro,
    curve: Curves.decelerate,
  );

  late final List<ItemLista> _pendientes = [
    for (final i in widget.items)
      if (!i.hecho) i,
  ];
  String? _categoria;
  _Fase _fase = _Fase.inicio;

  /// Índice del elegido y cuántos pasos da la ruleta antes de llegar a él.
  int _elegido = 0;
  int _pasos = 0;

  List<String> get _categoriasConPendientes => [
    for (final c in widget.categorias)
      if (_pendientes.any((i) => i.categoria == c)) c,
    ...{
      for (final i in _pendientes)
        if (!widget.categorias.contains(i.categoria)) i.categoria,
    },
  ];

  List<ItemLista> get _candidatos => [
    for (final i in _pendientes)
      if (_categoria == null || i.categoria == _categoria) i,
  ];

  @override
  void dispose() {
    _giro.dispose();
    super.dispose();
  }

  void _alTerminar(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      setState(() => _fase = _Fase.listo);
    }
  }

  void _girar() {
    final candidatos = _candidatos;
    if (candidatos.isEmpty) return;
    setState(() {
      _elegido = _random.nextInt(candidatos.length);
      _pasos = 14 + _random.nextInt(8);
      _fase = _Fase.girando;
    });
    _giro.forward(from: 0);
  }

  void _elegirCategoria(String? c) {
    _giro.stop();
    setState(() {
      _categoria = c;
      _fase = _Fase.inicio;
    });
  }

  /// Elemento que se muestra en este momento del giro: avanza cada vez más
  /// lento y termina justo en el elegido.
  ItemLista _actual(List<ItemLista> candidatos) {
    final paso = (_avance.value * _pasos).round();
    return candidatos[(_elegido - _pasos + paso) % candidatos.length];
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colores = Theme.of(context).colorScheme;
    final titulo = tituloRuleta(widget.tipo);

    if (_pendientes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🎲 $titulo', style: textTheme.titleLarge),
            const SizedBox(height: 24),
            Text('No hay pendientes 🎉', style: textTheme.titleMedium),
          ],
        ),
      );
    }

    final candidatos = _candidatos;
    final categorias = _categoriasConPendientes;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '🎲 $titulo',
            textAlign: TextAlign.center,
            style: textTheme.titleLarge,
          ),
          if (categorias.length > 1) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                for (final c in [null, ...categorias])
                  ChoiceChip(
                    label: Text(c ?? 'Todas'),
                    labelStyle: textTheme.bodySmall,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    showCheckmark: false,
                    selected: c == _categoria,
                    onSelected: _fase == _Fase.girando
                        ? null
                        : (_) => _elegirCategoria(c),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Card(
            color: colores.primaryContainer,
            child: Container(
              constraints: const BoxConstraints(minHeight: 140),
              alignment: Alignment.center,
              padding: const EdgeInsets.all(20),
              child: switch (_fase) {
                _Fase.inicio => Text(
                  candidatos.length == 1
                      ? '1 pendiente en la ruleta'
                      : '${candidatos.length} pendientes en la ruleta',
                  textAlign: TextAlign.center,
                  style: textTheme.titleMedium,
                ),
                _Fase.girando => AnimatedBuilder(
                  animation: _avance,
                  builder: (context, _) => Text(
                    _actual(candidatos).titulo,
                    key: const Key('ruleta-girando'),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleLarge?.copyWith(
                      color: colores.onPrimaryContainer.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                _Fase.listo => _Elegido(item: candidatos[_elegido]),
              },
            ),
          ),
          const SizedBox(height: 16),
          if (_fase == _Fase.listo)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _girar,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Otra vez'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () =>
                        Navigator.of(context).pop(candidatos[_elegido]),
                    icon: const Icon(Icons.visibility),
                    label: const Text('Ver'),
                  ),
                ),
              ],
            )
          else
            FilledButton.icon(
              onPressed: _fase == _Fase.girando ? null : _girar,
              icon: const Icon(Icons.casino),
              label: const Text('Girar'),
            ),
        ],
      ),
    );
  }
}

class _Elegido extends StatelessWidget {
  const _Elegido({required this.item});

  final ItemLista item;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colores = Theme.of(context).colorScheme;
    return Column(
      key: const Key('ruleta-elegido'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('🎉', style: TextStyle(fontSize: 32)),
        const SizedBox(height: 8),
        Text(
          item.titulo,
          textAlign: TextAlign.center,
          style: textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: colores.onPrimaryContainer,
          ),
        ),
        const SizedBox(height: 4),
        Text(item.categoria, style: textTheme.bodySmall),
        if (item.nota.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            item.nota,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodyMedium,
          ),
        ],
      ],
    );
  }
}
