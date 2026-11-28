import 'package:flutter/material.dart';

import '../../../core/widgets/paw_background.dart';
import '../domain/fechas_repository.dart';
import 'fecha_form_sheet.dart';

/// Todas las fechas importantes, de la más cercana a la más lejana. Las que
/// faltan 7 días o menos se resaltan.
class FechasPage extends StatefulWidget {
  const FechasPage({super.key, required this.repository});

  final FechasRepository repository;

  @override
  State<FechasPage> createState() => _FechasPageState();
}

class _FechasPageState extends State<FechasPage> {
  late final _fechas = widget.repository.watch();

  FechasRepository get repo => widget.repository;

  Future<void> _avisar(Future<void> Function() accion, String error) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await accion();
    } catch (e) {
      debugPrint('$error: $e');
      messenger.showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _agregar() async {
    final r = await mostrarFormularioFecha(context, hoy: repo.hoy());
    if (r?.fecha case final f?) {
      await _avisar(() => repo.add(f), 'No se pudo guardar la fecha');
    }
  }

  Future<void> _editar(FechaImportante fecha) async {
    final r = await mostrarFormularioFecha(
      context,
      inicial: fecha,
      hoy: repo.hoy(),
    );
    if (r == null) return;
    if (r.eliminar) {
      await _avisar(() => repo.delete(fecha.id), 'No se pudo eliminar');
    } else if (r.fecha case final f?) {
      await _avisar(() => repo.update(fecha.id, f), 'No se pudo guardar');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('📆 Fechas importantes')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _agregar,
        icon: const Icon(Icons.add),
        label: const Text('Agregar'),
      ),
      body: PawBackground(
        child: StreamBuilder<List<FechaImportante>>(
          stream: _fechas,
          builder: (context, snap) {
            if (snap.hasError) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No se pudieron cargar las fechas 😿',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final fechas = snap.data!;
            if (fechas.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'Aún no hay fechas.\n¡Agreguen cumpleaños, aniversarios '
                    'y viajes para contar los días! 🫘',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              );
            }
            final hoy = repo.hoy();
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
              itemCount: fechas.length,
              itemBuilder: (context, i) {
                final f = fechas[i];
                return Dismissible(
                  key: ValueKey(f.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: const Icon(Icons.delete_outline),
                  ),
                  confirmDismiss: (_) => confirmarEliminarFecha(context, f),
                  onDismissed: (_) =>
                      _avisar(() => repo.delete(f.id), 'No se pudo eliminar'),
                  child: _TarjetaFecha(
                    fecha: f,
                    hoy: hoy,
                    onTap: () => _editar(f),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _TarjetaFecha extends StatelessWidget {
  const _TarjetaFecha({
    required this.fecha,
    required this.hoy,
    required this.onTap,
  });

  final FechaImportante fecha;
  final DateTime hoy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final cercana = fecha.esCercana(hoy);
    final pasada = fecha.diasRestantes(hoy) < 0;
    final cuando = [
      formatoFecha(fecha.proxima(hoy)),
      if (fecha.anual) 'cada año',
    ].join(' · ');
    return Card(
      key: ValueKey('fecha-${fecha.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      color: cercana ? scheme.primaryContainer : null,
      child: ListTile(
        onTap: onTap,
        leading: Text(fecha.emoji, style: const TextStyle(fontSize: 30)),
        title: Text(
          fecha.titulo,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: pasada
              ? TextStyle(color: scheme.onSurface.withValues(alpha: 0.6))
              : null,
        ),
        subtitle: Text(
          '$cuando\n${fecha.cuentaRegresiva(hoy)}',
          style: textTheme.bodySmall?.copyWith(height: 1.4),
        ),
        isThreeLine: true,
        trailing: cercana
            ? Icon(Icons.celebration, color: scheme.primary)
            : const Icon(Icons.chevron_right),
      ),
    );
  }
}
