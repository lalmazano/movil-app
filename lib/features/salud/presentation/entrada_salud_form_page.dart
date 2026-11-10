import 'package:flutter/material.dart';

import '../../../core/storage/json_store.dart';
import '../../../core/widgets/paw_background.dart';
import '../../michis/domain/michi.dart';
import '../../recordatorios/domain/recordatorio.dart';
import '../../recordatorios/domain/servicio_recordatorios.dart';
import '../../recordatorios/presentation/formato_fecha.dart';
import '../../recordatorios/presentation/recordatorio_form_page.dart';
import '../domain/entrada_salud.dart';

/// Crear o editar una entrada del diario de salud. Devuelve true si cambió
/// algo.
class EntradaSaludFormPage extends StatefulWidget {
  const EntradaSaludFormPage({
    super.key,
    required this.repository,
    required this.michis,
    required this.reloj,
    this.existente,
    this.michiInicial,
    this.recordatorios,
  });

  final SaludRepository repository;
  final List<Michi> michis;
  final DateTime Function() reloj;
  final EntradaSalud? existente;

  /// Michi preseleccionado para una entrada nueva.
  final String? michiInicial;

  /// Si se indica, una vacuna guardada ofrece "Crear recordatorio".
  final ServicioRecordatorios? recordatorios;

  @override
  State<EntradaSaludFormPage> createState() => _EntradaSaludFormPageState();
}

class _EntradaSaludFormPageState extends State<EntradaSaludFormPage> {
  late TipoSalud _tipo;
  late final TextEditingController _titulo;
  late final TextEditingController _notas;
  late final TextEditingController _costo;
  String? _michiId;
  late DateTime _fecha;
  bool _guardando = false;

  bool get _editando => widget.existente != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existente;
    _tipo = e?.tipo ?? TipoSalud.visitaVeterinario;
    _titulo = TextEditingController(text: e?.titulo ?? '');
    _notas = TextEditingController(text: e?.notas ?? '');
    _costo = TextEditingController(
      text: e?.costo == null ? '' : formatearCosto(e!.costo!),
    );
    final michi = e?.michiId ?? widget.michiInicial;
    _michiId = widget.michis.any((m) => m.id == michi) ? michi : null;
    final ahora = widget.reloj();
    _fecha = e?.fecha ?? DateTime(ahora.year, ahora.month, ahora.day);
  }

  @override
  void dispose() {
    _titulo.dispose();
    _notas.dispose();
    _costo.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final ahora = widget.reloj();
    final elegido = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(ahora.year - 30),
      lastDate: DateTime(ahora.year + 5),
    );
    if (elegido != null) setState(() => _fecha = elegido);
  }

  Future<void> _guardar() async {
    final titulo = _titulo.text.trim();
    final costoTexto = _costo.text.trim();
    final costo = leerCosto(costoTexto);
    if (costoTexto.isNotEmpty && costo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El costo no es un número válido 🙀')),
      );
      return;
    }
    setState(() => _guardando = true);
    await widget.repository.guardar(
      EntradaSalud(
        id: widget.existente?.id ?? nuevoId(),
        tipo: _tipo,
        fecha: _fecha,
        titulo: titulo.isEmpty ? _tipo.etiqueta : titulo,
        michiId: _michiId,
        notas: _notas.text.trim(),
        costo: costo,
      ),
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _eliminar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Borrar del diario?'),
        content: const Text('Esta entrada se borrará para siempre 😿'),
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
    await widget.repository.delete(widget.existente!.id);
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _crearRecordatorio() async {
    final servicio = widget.recordatorios!;
    final ahora = servicio.reloj();
    var fecha = DateTime(_fecha.year + 1, _fecha.month, _fecha.day, 10);
    if (!fecha.isAfter(ahora)) {
      fecha = DateTime(ahora.year, ahora.month, ahora.day + 1, 10);
    }
    final titulo = _titulo.text.trim();
    final creado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RecordatorioFormPage(
          servicio: servicio,
          michis: widget.michis,
          plantilla: Recordatorio(
            id: '',
            tipo: TipoRecordatorio.vacuna,
            titulo: titulo.isEmpty ? 'Refuerzo de vacuna' : 'Refuerzo: $titulo',
            michiId: _michiId,
            fecha: fecha,
          ),
        ),
      ),
    );
    if (creado == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recordatorio de vacuna creado ⏰💉')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final puedeRecordar =
        widget.recordatorios != null && _tipo == TipoSalud.vacuna;
    return Scaffold(
      appBar: AppBar(
        title: Text(_editando ? 'Editar entrada' : 'Nueva entrada'),
        actions: [
          if (_editando)
            IconButton(
              tooltip: 'Borrar',
              icon: const Icon(Icons.delete_outline),
              onPressed: _eliminar,
            ),
        ],
      ),
      body: PawBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Text('Tipo', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in TipoSalud.values)
                  ChoiceChip(
                    label: Text('${t.emoji} ${t.etiqueta}'),
                    selected: _tipo == t,
                    onSelected: (_) => setState(() => _tipo = t),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              initialValue: _michiId,
              decoration: const InputDecoration(labelText: 'Michi'),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('🐾 Sin michi'),
                ),
                for (final m in widget.michis)
                  DropdownMenuItem(
                    value: m.id,
                    child: Text('${m.emoji} ${m.nombre}'),
                  ),
              ],
              onChanged: (v) => setState(() => _michiId = v),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('salud_titulo'),
              controller: _titulo,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Título',
                hintText: 'Ej.: Vacuna triple felina',
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Fecha'),
              subtitle: Text(fechaCorta(_fecha)),
              onTap: _elegirFecha,
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('salud_notas'),
              controller: _notas,
              minLines: 2,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Notas',
                hintText: 'Peso, dosis, qué dijo el veterinario…',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('salud_costo'),
              controller: _costo,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Costo (opcional)',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _guardando ? null : _guardar,
              icon: const Icon(Icons.save),
              label: const Text('Guardar entrada'),
            ),
            if (puedeRecordar) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _crearRecordatorio,
                icon: const Icon(Icons.alarm_add),
                label: const Text('Crear recordatorio'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
