import 'package:flutter/material.dart';

import '../../../core/widgets/paw_background.dart';

import '../../editor_foto/presentation/editor_foto_page.dart';

import '../../../app/servicios.dart';
import '../../michis/domain/michi.dart';
import '../domain/recuerdo.dart';
import 'widgets/calificacion_huellitas.dart';
import 'widgets/foto_recuerdo.dart';
import 'widgets/selector_michi.dart';

/// Vista previa de la foto recién tomada: se califica y se guarda.
class NuevoRecuerdoPage extends StatefulWidget {
  const NuevoRecuerdoPage({
    super.key,
    required this.fotoPath,
    required this.repository,
    this.michiRepository,
  });

  final String fotoPath;
  final RecuerdoRepository repository;

  /// Michis para etiquetar. Por defecto `AppServicios.instancia.michis`.
  final MichiRepository? michiRepository;

  @override
  State<NuevoRecuerdoPage> createState() => _NuevoRecuerdoPageState();
}

class _NuevoRecuerdoPageState extends State<NuevoRecuerdoPage> {
  final _nota = TextEditingController();
  int _calificacion = 0;
  bool _guardando = false;

  /// Foto actual: la original o la versión decorada en el editor.
  late String _foto = widget.fotoPath;
  List<Michi> _michis = const [];
  String? _michiId;

  @override
  void initState() {
    super.initState();
    cargarMichisSeguro(widget.michiRepository ?? AppServicios.instancia.michis)
        .then((michis) {
          if (mounted) setState(() => _michis = michis);
        });
  }

  @override
  void dispose() {
    _nota.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      final recuerdo = await widget.repository.add(
        sourcePath: _foto,
        calificacion: _calificacion,
        nota: _nota.text.trim(),
        michiId: _michiId,
      );
      if (mounted) Navigator.of(context).pop(recuerdo);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar el recuerdo 😿')),
      );
    }
  }

  Future<void> _decorar() async {
    final decorada = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => EditorFotoPage(fotoPath: _foto)),
    );
    if (decorada != null && mounted) setState(() => _foto = decorada);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo recuerdo')),
      body: PawBackground(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: FotoRecuerdo(path: _foto),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: OutlinedButton.icon(
                onPressed: _guardando ? null : _decorar,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Decorar ✨'),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                '¿Qué tan michi-bonita quedó?',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: CalificacionHuellitas(
                valor: _calificacion,
                tamano: 40,
                mostrarEtiqueta: true,
                onChanged: (v) => setState(() => _calificacion = v),
              ),
            ),
            if (_michis.isNotEmpty) ...[
              const SizedBox(height: 20),
              SelectorMichi(
                michis: _michis,
                seleccionado: _michiId,
                onChanged: (id) => setState(() => _michiId = id),
              ),
            ],
            const SizedBox(height: 20),
            TextField(
              controller: _nota,
              maxLength: 120,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nota (opcional)',
                hintText: 'Ej. Siesta con Pelusa',
                prefixIcon: Icon(Icons.edit_note),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _calificacion == 0 || _guardando ? null : _guardar,
              icon: _guardando
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.favorite),
              label: const Text('Guardar recuerdo'),
            ),
          ],
        ),
      ),
    );
  }
}
