import 'package:flutter/material.dart';

import '../../domain/item_lista.dart';
import 'buscador_tmdb.dart';

/// Lo que devuelve el formulario: el elemento y, en películas, los datos de
/// TMDB vinculados (null si no tiene o se desvinculó).
typedef FormularioItem = ({NuevoItem item, InfoPelicula? pelicula});

/// Hoja para crear o editar un elemento. Devuelve un [FormularioItem] o null.
///
/// En películas, si [claveTmdb] trae una clave, se puede buscar en TMDB
/// para vincular póster y datos. Sin clave no aparece nada de TMDB.
Future<FormularioItem?> mostrarFormularioItem(
  BuildContext context, {
  required TipoLista tipo,
  required List<String> categorias,
  ItemLista? inicial,
  Future<String?>? claveTmdb,
}) => showModalBottomSheet<FormularioItem>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => _ItemFormSheet(
    tipo: tipo,
    categorias: categorias,
    inicial: inicial,
    claveTmdb: tipo == TipoLista.peliculas ? claveTmdb : null,
  ),
);

class _ItemFormSheet extends StatefulWidget {
  const _ItemFormSheet({
    required this.tipo,
    required this.categorias,
    this.inicial,
    this.claveTmdb,
  });

  final TipoLista tipo;
  final List<String> categorias;
  final ItemLista? inicial;
  final Future<String?>? claveTmdb;

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

  /// Clave de TMDB (null mientras carga o si no hay).
  String? _clave;

  /// Película de TMDB vinculada y el título con el que se mostró.
  late InfoPelicula? _pelicula = widget.inicial?.pelicula;
  late String _tituloTmdb = widget.inicial?.titulo ?? '';

  @override
  void initState() {
    super.initState();
    widget.claveTmdb
        ?.then((clave) {
          final c = clave?.trim();
          if (mounted && c != null && c.isNotEmpty) {
            setState(() => _clave = c);
          }
        })
        .catchError((Object _) {});
  }

  Future<void> _buscarTmdb() async {
    final clave = _clave;
    if (clave == null) return;
    final seleccion = await mostrarBuscadorTmdb(
      context,
      apiKey: clave,
      consulta: _titulo.text.trim(),
    );
    if (seleccion == null || !mounted) return;
    final actual = _titulo.text.trim();
    var usarTitulo = actual.isEmpty;
    if (!usarTitulo && actual.toLowerCase() != seleccion.titulo.toLowerCase()) {
      usarTitulo =
          await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('¿Usar el título de TMDB?'),
              content: Text('Cambiar «$actual» por «${seleccion.titulo}».'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Dejar el mío'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Usar el de TMDB'),
                ),
              ],
            ),
          ) ??
          false;
      if (!mounted) return;
    }
    setState(() {
      if (usarTitulo) _titulo.text = seleccion.titulo;
      _pelicula = seleccion.info;
      _tituloTmdb = seleccion.titulo;
    });
  }

  @override
  void dispose() {
    _titulo.dispose();
    _nota.dispose();
    super.dispose();
  }

  void _guardar() {
    final titulo = _titulo.text.trim();
    if (titulo.isEmpty) return;
    final FormularioItem resultado = (
      item: (titulo: titulo, categoria: _categoria, nota: _nota.text.trim()),
      pelicula: _pelicula,
    );
    Navigator.of(context).pop(resultado);
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
                  suffixIcon: _clave == null
                      ? null
                      : IconButton(
                          key: const Key('boton-buscar-tmdb'),
                          tooltip: 'Buscar en TMDB',
                          icon: const Icon(Icons.travel_explore),
                          onPressed: _buscarTmdb,
                        ),
                ),
              ),
              if (_pelicula case final p?)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: InputChip(
                      key: const Key('chip-tmdb'),
                      label: Text(
                        '🎞️ $_tituloTmdb${p.anio == null ? '' : ' (${p.anio})'}',
                        overflow: TextOverflow.ellipsis,
                      ),
                      labelStyle: textTheme.bodySmall,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      deleteButtonTooltipMessage: 'Desvincular de TMDB',
                      onDeleted: () => setState(() => _pelicula = null),
                    ),
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
