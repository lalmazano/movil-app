import 'package:flutter/material.dart';

import '../domain/recuerdo.dart';
import 'widgets/calificacion_huellitas.dart';
import 'widgets/foto_recuerdo.dart';

/// Ver un recuerdo, cambiar su calificación o borrarlo.
///
/// Al cerrar devuelve `true` si hubo cambios.
class RecuerdoDetallePage extends StatefulWidget {
  const RecuerdoDetallePage({
    super.key,
    required this.recuerdo,
    required this.repository,
  });

  final Recuerdo recuerdo;
  final RecuerdoRepository repository;

  @override
  State<RecuerdoDetallePage> createState() => _RecuerdoDetallePageState();
}

class _RecuerdoDetallePageState extends State<RecuerdoDetallePage> {
  late Recuerdo _recuerdo = widget.recuerdo;
  bool _cambio = false;

  Future<void> _calificar(int valor) async {
    final actualizado = _recuerdo.copyWith(calificacion: valor);
    setState(() {
      _recuerdo = actualizado;
      _cambio = true;
    });
    await widget.repository.update(actualizado);
  }

  Future<void> _borrar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Borrar recuerdo? 🙀'),
        content: const Text('La foto se eliminará de la app.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    await widget.repository.delete(_recuerdo.id);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_cambio);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Recuerdo'),
          actions: [
            IconButton(
              tooltip: 'Borrar',
              icon: const Icon(Icons.delete_outline),
              onPressed: _borrar,
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: FotoRecuerdo(
                path: _recuerdo.imagePath,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 16),
            if (_recuerdo.nota.isNotEmpty)
              Text(
                _recuerdo.nota,
                textAlign: TextAlign.center,
                style: textTheme.titleLarge,
              ),
            Text(
              formatearFecha(_recuerdo.fecha),
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Center(
              child: CalificacionHuellitas(
                valor: _recuerdo.calificacion,
                mostrarEtiqueta: true,
                onChanged: _calificar,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
