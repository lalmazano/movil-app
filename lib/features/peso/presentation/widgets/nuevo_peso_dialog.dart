import 'package:flutter/material.dart';

import '../../domain/registro_peso.dart';

/// Datos capturados por [NuevoPesoDialog].
typedef NuevoPeso = ({double kg, DateTime fecha, String nota});

/// Diálogo para registrar un pesaje. Devuelve un [NuevoPeso] o null.
class NuevoPesoDialog extends StatefulWidget {
  const NuevoPesoDialog({super.key, required this.hoy});

  final DateTime hoy;

  @override
  State<NuevoPesoDialog> createState() => _NuevoPesoDialogState();
}

class _NuevoPesoDialogState extends State<NuevoPesoDialog> {
  final _form = GlobalKey<FormState>();
  final _kg = TextEditingController();
  final _nota = TextEditingController();
  late DateTime _fecha = DateUtils.dateOnly(widget.hoy);

  @override
  void dispose() {
    _kg.dispose();
    _nota.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2000),
      lastDate: DateUtils.dateOnly(widget.hoy),
      helpText: '¿Cuándo lo pesaste?',
    );
    if (elegida != null) setState(() => _fecha = elegida);
  }

  void _guardar() {
    if (!_form.currentState!.validate()) return;
    Navigator.pop<NuevoPeso>(context, (
      kg: redondearKg(parsearPeso(_kg.text)!),
      fecha: _fecha,
      nota: _nota.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final f = _fecha;
    return AlertDialog(
      title: const Text('Nuevo pesaje ⚖️'),
      content: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: const Key('campo_kg'),
                controller: _kg,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Peso',
                  suffixText: 'kg',
                ),
                validator: validarPeso,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('campo_nota'),
                controller: _nota,
                decoration: const InputDecoration(labelText: 'Nota (opcional)'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _elegirFecha,
                icon: const Icon(Icons.calendar_today),
                label: Text(
                  '${f.day.toString().padLeft(2, '0')}/'
                  '${f.month.toString().padLeft(2, '0')}/${f.year}',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _guardar, child: const Text('Guardar')),
      ],
    );
  }
}
