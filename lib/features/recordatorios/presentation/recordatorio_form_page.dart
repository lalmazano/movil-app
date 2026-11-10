import 'package:flutter/material.dart';

import '../../../core/storage/json_store.dart';
import '../../../core/widgets/paw_background.dart';
import '../../michis/domain/michi.dart';
import '../domain/recordatorio.dart';
import '../domain/servicio_recordatorios.dart';
import 'formato_fecha.dart';

/// Crear o editar un recordatorio. Devuelve true (con `Navigator.pop`) si se
/// guardó o se borró algo.
class RecordatorioFormPage extends StatefulWidget {
  const RecordatorioFormPage({
    super.key,
    required this.servicio,
    required this.michis,
    this.existente,
    this.plantilla,
  });

  final ServicioRecordatorios servicio;
  final List<Michi> michis;

  /// Recordatorio a editar, o null para crear uno nuevo.
  final Recordatorio? existente;

  /// Valores iniciales para uno nuevo (por ejemplo, desde el diario de salud).
  final Recordatorio? plantilla;

  @override
  State<RecordatorioFormPage> createState() => _RecordatorioFormPageState();
}

class _RecordatorioFormPageState extends State<RecordatorioFormPage> {
  late TipoRecordatorio _tipo;
  late final TextEditingController _titulo;
  String? _michiId;
  late DateTime _fecha;
  late Repeticion _repeticion;
  late bool _activo;
  bool _guardando = false;

  bool get _editando => widget.existente != null;

  @override
  void initState() {
    super.initState();
    final base = widget.existente ?? widget.plantilla;
    final ahora = widget.servicio.reloj();
    _tipo = base?.tipo ?? TipoRecordatorio.comida;
    _titulo = TextEditingController(text: base?.titulo ?? '');
    _michiId = widget.michis.any((m) => m.id == base?.michiId)
        ? base!.michiId
        : null;
    _fecha =
        base?.fecha ??
        DateTime(ahora.year, ahora.month, ahora.day, ahora.hour + 1);
    _repeticion = base?.repeticion ?? Repeticion.unaVez;
    _activo = base?.activo ?? true;
  }

  @override
  void dispose() {
    _titulo.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final ahora = widget.servicio.reloj();
    final elegido = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(ahora.year - 5),
      lastDate: DateTime(ahora.year + 10),
      helpText: 'Elige el día',
    );
    if (elegido == null) return;
    setState(
      () => _fecha = DateTime(
        elegido.year,
        elegido.month,
        elegido.day,
        _fecha.hour,
        _fecha.minute,
      ),
    );
  }

  Future<void> _elegirHora() async {
    final elegido = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_fecha),
      helpText: 'Elige la hora',
    );
    if (elegido == null) return;
    setState(
      () => _fecha = DateTime(
        _fecha.year,
        _fecha.month,
        _fecha.day,
        elegido.hour,
        elegido.minute,
      ),
    );
  }

  Future<void> _guardar() async {
    final ahora = widget.servicio.reloj();
    if (_repeticion == Repeticion.unaVez && !_fecha.isAfter(ahora) && _activo) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esa hora ya pasó 😿 Elige una fecha futura.'),
        ),
      );
      return;
    }
    setState(() => _guardando = true);
    final titulo = _titulo.text.trim();
    final r = Recordatorio(
      id: widget.existente?.id ?? nuevoId(),
      tipo: _tipo,
      titulo: titulo.isEmpty ? _tipo.etiqueta : titulo,
      michiId: _michiId,
      fecha: _fecha,
      repeticion: _repeticion,
      activo: _activo,
    );
    await widget.servicio.guardar(r);
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _eliminar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Borrar recordatorio?'),
        content: const Text('Tu michi ya no recibirá este aviso 🙀'),
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
    await widget.servicio.eliminar(widget.existente!);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_editando ? 'Editar recordatorio' : 'Nuevo recordatorio'),
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
            Text('¿Qué hay que recordar?', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in TipoRecordatorio.values)
                  ChoiceChip(
                    label: Text('${t.emoji} ${t.etiqueta}'),
                    selected: _tipo == t,
                    onSelected: (_) => setState(() => _tipo = t),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titulo,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Título',
                hintText: 'Ej.: ${_tipo.etiqueta} de la mañana',
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              initialValue: _michiId,
              decoration: const InputDecoration(labelText: 'Michi'),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('🐾 Todos los michis'),
                ),
                for (final m in widget.michis)
                  DropdownMenuItem(
                    value: m.id,
                    child: Text('${m.emoji} ${m.nombre}'),
                  ),
              ],
              onChanged: (v) => setState(() => _michiId = v),
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.calendar_today),
                    title: const Text('Día'),
                    subtitle: Text(fechaCorta(_fecha)),
                    onTap: _elegirFecha,
                  ),
                  ListTile(
                    leading: const Icon(Icons.access_time),
                    title: const Text('Hora'),
                    subtitle: Text(horaCorta(_fecha)),
                    onTap: _elegirHora,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('Repetir', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final r in Repeticion.values)
                  ChoiceChip(
                    label: Text(r.etiqueta),
                    selected: _repeticion == r,
                    onSelected: (_) => setState(() => _repeticion = r),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Activo'),
              subtitle: const Text('Avisarme con una notificación 🔔'),
              value: _activo,
              onChanged: (v) => setState(() => _activo = v),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _guardando ? null : _guardar,
              icon: const Icon(Icons.alarm_add),
              label: const Text('Guardar recordatorio'),
            ),
          ],
        ),
      ),
    );
  }
}
