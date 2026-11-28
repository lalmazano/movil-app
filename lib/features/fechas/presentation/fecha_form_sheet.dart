import 'package:flutter/material.dart';

import '../domain/fecha_importante.dart';

/// Lo que devuelve la hoja: la fecha a guardar, o [eliminar] en true.
typedef FormularioFecha = ({NuevaFecha? fecha, bool eliminar});

/// Hoja para crear o editar una fecha importante. Con [inicial] se edita y
/// aparece el botón de eliminar (con confirmación).
Future<FormularioFecha?> mostrarFormularioFecha(
  BuildContext context, {
  FechaImportante? inicial,
  required DateTime hoy,
}) => showModalBottomSheet<FormularioFecha>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => _FechaFormSheet(inicial: inicial, hoy: hoy),
);

class _FechaFormSheet extends StatefulWidget {
  const _FechaFormSheet({this.inicial, required this.hoy});

  final FechaImportante? inicial;
  final DateTime hoy;

  @override
  State<_FechaFormSheet> createState() => _FechaFormSheetState();
}

class _FechaFormSheetState extends State<_FechaFormSheet> {
  late final _titulo = TextEditingController(text: widget.inicial?.titulo);
  late String _emoji = widget.inicial?.emoji ?? emojisFecha.first;
  late DateTime? _fecha = widget.inicial?.fecha;
  late bool _anual = widget.inicial?.anual ?? true;
  late bool _contarAnios = widget.inicial?.contarAnios ?? false;
  String? _error;

  @override
  void dispose() {
    _titulo.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final hoy = widget.hoy;
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fecha ?? hoy,
      firstDate: DateTime(1900),
      lastDate: DateTime(hoy.year + 50),
      helpText: 'Elige la fecha',
      cancelText: 'Cancelar',
      confirmText: 'Listo',
    );
    if (elegida != null && mounted) {
      setState(() {
        _fecha = elegida;
        _error = null;
      });
    }
  }

  void _guardar() {
    final titulo = _titulo.text.trim();
    final fecha = _fecha;
    final error = titulo.isEmpty
        ? 'Escribe un título'
        : titulo.length > 80
        ? 'Máximo 80 caracteres'
        : fecha == null
        ? 'Elige la fecha'
        : null;
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop((
      fecha: NuevaFecha(
        titulo: titulo,
        fecha: fecha!,
        anual: _anual,
        emoji: _emoji,
        contarAnios: _anual && _contarAnios,
      ),
      eliminar: false,
    ));
  }

  Future<void> _eliminar() async {
    final ok = await confirmarEliminarFecha(context, widget.inicial!);
    if (ok && mounted) {
      Navigator.of(context).pop((fecha: null, eliminar: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final fecha = _fecha;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.inicial == null ? '📆 Nueva fecha' : '📆 Editar fecha',
              style: textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('fecha-titulo'),
              controller: _titulo,
              autofocus: widget.inicial == null,
              maxLength: 80,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Título',
                hintText: 'Ej. Cumpleaños de Ana',
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            Wrap(
              spacing: 6,
              children: [
                for (final e in emojisFecha)
                  ChoiceChip(
                    label: Text(e, style: const TextStyle(fontSize: 18)),
                    selected: e == _emoji,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _emoji = e),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ListTile(
              key: const Key('fecha-elegir'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(
                fecha == null ? 'Elegir la fecha' : formatoFecha(fecha),
              ),
              trailing: const Icon(Icons.edit_calendar),
              onTap: _elegirFecha,
            ),
            SwitchListTile(
              key: const Key('fecha-anual'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Se repite cada año'),
              subtitle: const Text('Cumpleaños, aniversarios…'),
              value: _anual,
              onChanged: (v) => setState(() => _anual = v),
            ),
            if (_anual)
              SwitchListTile(
                key: const Key('fecha-contar-anios'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Contar los años'),
                subtitle: Text(
                  fecha == null
                      ? 'Muestra cuántos años cumple'
                      : 'Desde ${fecha.year}: "cumple N años"',
                ),
                value: _contarAnios,
                onChanged: (v) => setState(() => _contarAnios = v),
              ),
            if (_error case final error?)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(error, style: TextStyle(color: scheme.error)),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (widget.inicial != null)
                  TextButton.icon(
                    onPressed: _eliminar,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Eliminar'),
                    style: TextButton.styleFrom(foregroundColor: scheme.error),
                  ),
                const Spacer(),
                FilledButton(
                  key: const Key('fecha-guardar'),
                  onPressed: _guardar,
                  child: const Text('Guardar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Pregunta antes de borrar una fecha. Devuelve true si se confirma.
Future<bool> confirmarEliminarFecha(
  BuildContext context,
  FechaImportante fecha,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar la fecha?'),
        content: Text('Se borrará «${fecha.titulo}» para los dos.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    ) ??
    false;
