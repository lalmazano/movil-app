import 'package:flutter/material.dart';

import '../../../app/servicios.dart';
import '../../michis/domain/michi.dart';
import '../domain/recuerdo.dart';
import '../domain/recuerdo_acciones.dart';
import 'widgets/calificacion_huellitas.dart';
import 'widgets/foto_recuerdo.dart';
import 'widgets/selector_michi.dart';

/// Ver un recuerdo, cambiar su calificación o borrarlo.
///
/// Al cerrar devuelve `true` si hubo cambios.
class RecuerdoDetallePage extends StatefulWidget {
  const RecuerdoDetallePage({
    super.key,
    required this.recuerdo,
    required this.repository,
    required this.acciones,
    this.michiRepository,
  });

  final Recuerdo recuerdo;
  final RecuerdoRepository repository;
  final RecuerdoAcciones acciones;

  /// Michis para etiquetar. Por defecto `AppServicios.instancia.michis`.
  final MichiRepository? michiRepository;

  @override
  State<RecuerdoDetallePage> createState() => _RecuerdoDetallePageState();
}

class _RecuerdoDetallePageState extends State<RecuerdoDetallePage> {
  late Recuerdo _recuerdo = widget.recuerdo;
  bool _cambio = false;
  bool _ocupado = false;
  List<Michi> _michis = const [];

  @override
  void initState() {
    super.initState();
    cargarMichisSeguro(widget.michiRepository ?? AppServicios.instancia.michis)
        .then((michis) {
          if (mounted) setState(() => _michis = michis);
        });
  }

  void _aviso(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _ejecutar(Future<void> Function() accion) async {
    if (_ocupado) return;
    setState(() => _ocupado = true);
    try {
      await accion();
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _guardarEnGaleria() => _ejecutar(() async {
    try {
      await widget.acciones.guardarEnGaleria(_recuerdo);
      _aviso('Guardada en tu galería, álbum "Michis" 😸');
    } on PermisoGaleriaDenegado {
      _aviso('Necesito permiso para guardar en tu galería 😿');
    } catch (_) {
      _aviso('No se pudo guardar en la galería 😿');
    }
  });

  Future<void> _compartir() => _ejecutar(() async {
    try {
      await widget.acciones.compartir(_recuerdo);
    } catch (_) {
      _aviso('No se pudo compartir 😿');
    }
  });

  Future<void> _calificar(int valor) async {
    final actualizado = _recuerdo.copyWith(calificacion: valor);
    setState(() {
      _recuerdo = actualizado;
      _cambio = true;
    });
    await widget.repository.update(actualizado);
  }

  Future<void> _etiquetar(String? michiId) async {
    final actualizado = _recuerdo.copyWith(michiId: () => michiId);
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
            if (_michis.isNotEmpty) ...[
              const SizedBox(height: 20),
              SelectorMichi(
                michis: _michis,
                seleccionado: _recuerdo.michiId,
                onChanged: _etiquetar,
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _ocupado ? null : _guardarEnGaleria,
                    icon: const Icon(Icons.download),
                    label: const Text('Guardar en galería'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _ocupado ? null : _compartir,
                    icon: const Icon(Icons.share),
                    label: const Text('Compartir'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Comparte por WhatsApp o cualquier otra app 💬',
              textAlign: TextAlign.center,
              style: textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
