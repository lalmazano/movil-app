import 'package:flutter/material.dart';

import '../../../core/widgets/paw_background.dart';
import '../data/catalogo_disney.dart';
import '../domain/item_lista.dart';
import 'widgets/item_form_sheet.dart';

enum _Filtro { pendientes, hechos, todos }

/// Pantalla de una lista (películas, deseos o planes para hacer juntos).
class ListaPage extends StatefulWidget {
  const ListaPage({super.key, required this.tipo, required this.repository});

  final TipoLista tipo;
  final ListaRepository repository;

  @override
  State<ListaPage> createState() => _ListaPageState();
}

class _ListaPageState extends State<ListaPage> {
  late final Stream<List<ItemLista>> _items = widget.repository.watch(
    widget.tipo,
  );
  _Filtro _filtro = _Filtro.pendientes;
  String? _categoria;
  List<ItemLista> _ultimos = const [];

  TipoLista get _tipo => widget.tipo;

  /// Ejecuta una escritura sin bloquear la pantalla (Firestore confirma en
  /// segundo plano) y avisa si falla.
  void _escribir(Future<void> Function() accion) {
    final messenger = ScaffoldMessenger.of(context);
    accion().catchError((Object _) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No se pudo guardar. Revisa la conexión')),
      );
    });
  }

  Future<void> _agregar() async {
    final nuevo = await mostrarFormularioItem(context, tipo: _tipo);
    if (nuevo == null || !mounted) return;
    _escribir(() => widget.repository.add(_tipo, nuevo));
  }

  Future<void> _editar(ItemLista item) async {
    final cambios = await mostrarFormularioItem(
      context,
      tipo: _tipo,
      inicial: item,
    );
    if (cambios == null || !mounted) return;
    _escribir(
      () => widget.repository.update(
        _tipo,
        item.copyWith(
          titulo: cambios.titulo,
          categoria: cambios.categoria,
          nota: cambios.nota,
        ),
      ),
    );
  }

  Future<void> _borrar(ItemLista item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Borrar?'),
        content: Text('Se quitará "${item.titulo}" de la lista.'),
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
    if (ok == true && mounted) {
      _escribir(() => widget.repository.delete(_tipo, item.id));
    }
  }

  void _marcar(ItemLista item, bool hecho) {
    _escribir(() => widget.repository.setHecho(_tipo, item.id, hecho));
    if (hecho) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              '¡${item.titulo}: ${_tipo.accionHecho.toLowerCase()}! 🫘',
            ),
            action: SnackBarAction(
              label: 'Deshacer',
              onPressed: () => _escribir(
                () => widget.repository.setHecho(_tipo, item.id, false),
              ),
            ),
          ),
        );
    }
  }

  Future<void> _cargarDisney() async {
    final faltantes = peliculasFaltantes(_ultimos);
    final messenger = ScaffoldMessenger.of(context);
    if (faltantes.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Ya tienen toda la lista Disney ✨')),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🏰 Reto Disney'),
        content: Text(
          'Se agregarán ${faltantes.length} películas Disney y Pixar '
          'organizadas por categoría.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    _escribir(() => widget.repository.addMany(_tipo, faltantes));
    messenger.showSnackBar(
      SnackBar(content: Text('${faltantes.length} películas agregadas 🍿')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${_tipo.emoji} ${_tipo.titulo}'),
        actions: [
          if (_tipo == TipoLista.peliculas)
            IconButton(
              tooltip: 'Cargar lista Disney',
              icon: const Icon(Icons.auto_awesome),
              onPressed: _cargarDisney,
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _agregar,
        icon: const Icon(Icons.add),
        label: const Text('Agregar'),
      ),
      body: PawBackground(
        child: StreamBuilder<List<ItemLista>>(
          stream: _items,
          builder: (context, snap) {
            if (snap.hasError) {
              return _Mensaje(
                emoji: '😿',
                texto: 'No se pudo cargar la lista.\n${snap.error}',
              );
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            _ultimos = snap.data!;
            return _contenido(context, _ultimos);
          },
        ),
      ),
    );
  }

  Widget _contenido(BuildContext context, List<ItemLista> items) {
    if (items.isEmpty) {
      return _Mensaje(emoji: _tipo.emoji, texto: _tipo.vacio);
    }
    final hechos = items.where((i) => i.hecho).length;
    final categorias = [
      for (final c in _tipo.categorias)
        if (items.any((i) => i.categoria == c)) c,
      ...{
        for (final i in items)
          if (!_tipo.categorias.contains(i.categoria)) i.categoria,
      },
    ];
    final categoria = categorias.contains(_categoria) ? _categoria : null;
    final visibles = items.where((i) {
      final porFiltro = switch (_filtro) {
        _Filtro.pendientes => !i.hecho,
        _Filtro.hechos => i.hecho,
        _Filtro.todos => true,
      };
      return porFiltro && (categoria == null || i.categoria == categoria);
    }).toList();

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _Progreso(
              hechos: hechos,
              total: items.length,
              etiqueta: _tipo.hechos,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SegmentedButton<_Filtro>(
              segments: [
                ButtonSegment(
                  value: _Filtro.pendientes,
                  label: Text('Pendientes (${items.length - hechos})'),
                ),
                ButtonSegment(
                  value: _Filtro.hechos,
                  label: Text('${_tipo.accionHecho}s ($hechos)'),
                ),
                const ButtonSegment(value: _Filtro.todos, label: Text('Todo')),
              ],
              selected: {_filtro},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _filtro = s.first),
            ),
          ),
        ),
        if (categorias.length > 1)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 56,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                children: [
                  for (final c in [null, ...categorias])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(c ?? 'Todas'),
                        selected: c == categoria,
                        onSelected: (_) => setState(() => _categoria = c),
                      ),
                    ),
                ],
              ),
            ),
          ),
        if (visibles.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _Mensaje(
              emoji: _filtro == _Filtro.hechos ? '🫘' : '🎉',
              texto: _filtro == _Filtro.hechos
                  ? 'Todavía no hay nada ${_tipo.accionHecho.toLowerCase()}.'
                  : '¡Nada pendiente aquí!',
            ),
          )
        else
          ..._secciones(categorias, visibles),
        const SliverToBoxAdapter(child: SizedBox(height: 96)),
      ],
    );
  }

  List<Widget> _secciones(List<String> categorias, List<ItemLista> visibles) {
    return [
      for (final c in categorias)
        if (visibles.any((i) => i.categoria == c)) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
              child: Text(
                c,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SliverList.list(
            children: [
              for (final item in visibles.where((i) => i.categoria == c))
                _TarjetaItem(
                  item: item,
                  onMarcar: (v) => _marcar(item, v),
                  onEditar: () => _editar(item),
                  onBorrar: () => _borrar(item),
                ),
            ],
          ),
        ],
    ];
  }
}

class _Progreso extends StatelessWidget {
  const _Progreso({
    required this.hechos,
    required this.total,
    required this.etiqueta,
  });

  final int hechos;
  final int total;
  final String etiqueta;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final avance = total == 0 ? 0.0 : hechos / total;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$hechos de $total $etiqueta',
                    style: textTheme.titleMedium,
                  ),
                ),
                Text(
                  '${(avance * 100).round()} %',
                  style: textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(value: avance, minHeight: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class _TarjetaItem extends StatelessWidget {
  const _TarjetaItem({
    required this.item,
    required this.onMarcar,
    required this.onEditar,
    required this.onBorrar,
  });

  final ItemLista item;
  final ValueChanged<bool> onMarcar;
  final VoidCallback onEditar;
  final VoidCallback onBorrar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitulo = [
      if (item.nota.isNotEmpty) item.nota,
      if (item.hecho && item.hechoEn != null) '✓ ${_fecha(item.hechoEn!)}',
    ].join(' · ');
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 8, right: 4),
        leading: Checkbox(
          value: item.hecho,
          shape: const CircleBorder(),
          onChanged: (v) => onMarcar(v ?? false),
        ),
        title: Text(
          item.titulo,
          style: item.hecho
              ? TextStyle(
                  decoration: TextDecoration.lineThrough,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                )
              : null,
        ),
        subtitle: subtitulo.isEmpty ? null : Text(subtitulo),
        onTap: () => onMarcar(!item.hecho),
        trailing: PopupMenuButton<VoidCallback>(
          onSelected: (accion) => accion(),
          itemBuilder: (_) => [
            PopupMenuItem(value: onEditar, child: const Text('Editar')),
            PopupMenuItem(value: onBorrar, child: const Text('Borrar')),
          ],
        ),
      ),
    );
  }

  static String _fecha(DateTime f) =>
      '${f.day.toString().padLeft(2, '0')}/'
      '${f.month.toString().padLeft(2, '0')}/${f.year}';
}

class _Mensaje extends StatelessWidget {
  const _Mensaje({required this.emoji, required this.texto});

  final String emoji;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 12),
            Text(
              texto,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}
