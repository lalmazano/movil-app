import 'package:flutter/material.dart';

import '../../../core/widgets/paw_background.dart';
import '../../michis/domain/michi.dart';
import '../../peso/domain/registro_peso.dart';
import '../../recuerdos/domain/recuerdo.dart';
import '../domain/logro.dart';

/// Vitrina de logros (insignias) calculados a partir de los datos de la app.
class LogrosPage extends StatefulWidget {
  const LogrosPage({
    super.key,
    required this.michis,
    required this.recuerdos,
    required this.pesos,
    this.ahora = DateTime.now,
  });

  final MichiRepository michis;
  final RecuerdoRepository recuerdos;
  final PesoRepository pesos;
  final DateTime Function() ahora;

  @override
  State<LogrosPage> createState() => _LogrosPageState();
}

class _LogrosPageState extends State<LogrosPage> {
  List<Logro>? _logros;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  /// Si una fuente falla (p. ej. almacenamiento no disponible), cuenta vacía.
  Future<List<T>> _seguro<T>(Future<List<T>> Function() leer) async {
    try {
      return await leer();
    } catch (_) {
      return <T>[];
    }
  }

  Future<void> _cargar() async {
    final michis = await _seguro(widget.michis.getAll);
    final recuerdos = await _seguro(widget.recuerdos.getAll);
    final pesos = await _seguro(widget.pesos.getAll);
    if (!mounted) return;
    setState(
      () => _logros = calcularLogros(
        michis: michis,
        recuerdos: recuerdos,
        pesos: pesos,
        hoy: widget.ahora(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🏆 Logros michi')),
      body: PawBackground(child: _contenido(context)),
    );
  }

  Widget _contenido(BuildContext context) {
    final logros = _logros;
    if (logros == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final textTheme = Theme.of(context).textTheme;
    final hechos = logros.where((l) => l.desbloqueado).length;
    return RefreshIndicator(
      onRefresh: _cargar,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Column(
                children: [
                  Text(
                    '$hechos de ${logros.length} logros 🏆',
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: logros.isEmpty ? 0 : hechos / logros.length,
                      minHeight: 10,
                    ),
                  ),
                  if (hechos == logros.length) ...[
                    const SizedBox(height: 8),
                    const Text('¡Eres el humano favorito de tus michis! 😻'),
                  ],
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 200,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.78,
              ),
              itemCount: logros.length,
              itemBuilder: (_, i) => InsigniaLogro(logro: logros[i]),
            ),
          ),
        ],
      ),
    );
  }
}

/// Matriz que convierte a escala de grises (para logros bloqueados).
const _grises = ColorFilter.matrix([
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0, //
]);

/// Tarjeta de un logro: a color si está desbloqueado, gris con progreso si no.
class InsigniaLogro extends StatelessWidget {
  const InsigniaLogro({super.key, required this.logro});

  final Logro logro;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final abierto = logro.desbloqueado;
    final emoji = FittedBox(
      child: Text(logro.emoji, style: const TextStyle(fontSize: 44)),
    );
    return Semantics(
      label:
          '${logro.titulo}: '
          '${abierto ? 'desbloqueado' : 'bloqueado, ${logro.actual} de ${logro.meta}'}',
      excludeSemantics: true,
      child: Card(
        color: abierto ? scheme.primaryContainer : scheme.surfaceContainerHigh,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: abierto
                      ? emoji
                      : Opacity(
                          opacity: 0.4,
                          child: ColorFiltered(
                            colorFilter: _grises,
                            child: emoji,
                          ),
                        ),
                ),
              ),
              Text(
                logro.titulo,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: abierto ? null : scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                logro.descripcion,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              if (abierto)
                Text(
                  '¡Desbloqueado! ✨',
                  style: textTheme.labelMedium?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                )
              else ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: logro.progreso,
                    minHeight: 6,
                    color: scheme.outline,
                    backgroundColor: scheme.outlineVariant.withValues(
                      alpha: 0.4,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${logro.actual}/${logro.meta}',
                  style: textTheme.labelSmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
