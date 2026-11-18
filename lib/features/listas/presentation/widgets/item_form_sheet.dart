import 'package:flutter/material.dart';

import '../../domain/item_lista.dart';

/// Hoja para crear o editar un elemento. Devuelve el [NuevoItem] o null.
Future<NuevoItem?> mostrarFormularioItem(
  BuildContext context, {
  required TipoLista tipo,
  ItemLista? inicial,
}) => showModalBottomSheet<NuevoItem>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _ItemFormSheet(tipo: tipo, inicial: inicial),
);

class _ItemFormSheet extends StatefulWidget {
  const _ItemFormSheet({required this.tipo, this.inicial});

  final TipoLista tipo;
  final ItemLista? inicial;

  @override
  State<_ItemFormSheet> createState() => _ItemFormSheetState();
}

class _ItemFormSheetState extends State<_ItemFormSheet> {
  late final _titulo = TextEditingController(text: widget.inicial?.titulo);
  late final _nota = TextEditingController(text: widget.inicial?.nota);
  late String _categoria =
      widget.tipo.categorias.contains(widget.inicial?.categoria)
      ? widget.inicial!.categoria
      : widget.tipo.categoriaPorDefecto;

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
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${widget.tipo.emoji} ${editando ? 'Editar' : 'Agregar a'} '
            '${widget.tipo.titulo.toLowerCase()}',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
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
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final c in widget.tipo.categorias)
                ChoiceChip(
                  label: Text(c),
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
            decoration: const InputDecoration(labelText: 'Nota (opcional)'),
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
    );
  }
}
