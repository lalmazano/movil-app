import 'package:flutter/material.dart';

import '../../domain/item_lista.dart';

/// Hoja para crear o editar un elemento. Devuelve el [NuevoItem] o null.
Future<NuevoItem?> mostrarFormularioItem(
  BuildContext context, {
  required TipoLista tipo,
  required List<String> categorias,
  ItemLista? inicial,
}) => showModalBottomSheet<NuevoItem>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) =>
      _ItemFormSheet(tipo: tipo, categorias: categorias, inicial: inicial),
);

class _ItemFormSheet extends StatefulWidget {
  const _ItemFormSheet({
    required this.tipo,
    required this.categorias,
    this.inicial,
  });

  final TipoLista tipo;
  final List<String> categorias;
  final ItemLista? inicial;

  @override
  State<_ItemFormSheet> createState() => _ItemFormSheetState();
}

class _ItemFormSheetState extends State<_ItemFormSheet> {
  late final _titulo = TextEditingController(text: widget.inicial?.titulo);
  late final _nota = TextEditingController(text: widget.inicial?.nota);

  /// Si el elemento tiene una categoría que ya no existe, se conserva.
  late final List<String> _opciones = [
    ...widget.categorias,
    if (widget.inicial case final i?
        when !widget.categorias.contains(i.categoria))
      i.categoria,
  ];
  late String _categoria = widget.inicial?.categoria ?? _opciones.last;

  @override
  void dispose() {
    _titulo.dispose();
    _nota.dispose();
    super.dispose();
  }

  void _guardar() {
    final titulo = _titulo.text.trim();
    if (titulo.isEmpty) return;
    Navigator.of(context)
        .pop((titulo: titulo, categoria: _categoria, nota: _nota.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final editando = widget.inicial != null;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${widget.tipo.emoji} ${editando ? 'Editar' : 'Agregar a'} '
                '${widget.tipo.titulo.toLowerCase()}',
                style: textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('campo-titulo'),
                controller: _titulo,
                autofocus: !editando,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Título',
                  hintText: widget.tipo.pista,
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              Text('Categoría', style: textTheme.labelLarge),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final c in _opciones)
                    ChoiceChip(
                      label: Text(c),
                      labelStyle: textTheme.bodySmall,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      showCheckmark: false,
                      selected: c == _categoria,
                      onSelected: (_) => setState(() => _categoria = c),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nota,
                textCapitalization: TextCapitalization.sentences,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Nota (opcional)',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const Key('boton-guardar-item'),
                onPressed: _titulo.text.trim().isEmpty ? null : _guardar,
                icon: Icon(editando ? Icons.save : Icons.add),
                label: Text(editando ? 'Guardar' : 'Agregar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
