import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/widgets/club_logo.dart';
import '../../../core/widgets/iconos_club.dart';
import '../../../core/widgets/paw_background.dart';
import '../data/catalogo_disney.dart';
import '../domain/config_club.dart';
import '../domain/item_lista.dart';
import 'config_scope.dart';
import 'item_detalle_page.dart';
import 'widgets/campo_busqueda.dart';
import 'widgets/dialogo_calificar.dart';
import 'widgets/item_form_sheet.dart';
import 'widgets/repetible.dart';
import 'widgets/ruleta_sheet.dart';
import 'widgets/tarjeta_item.dart';

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
  late final Stream<ConfigClub> _config = widget.repository.watchConfig();
  late final Stream<List<String>> _categoriasStream = widget.repository
      .watchCategorias(widget.tipo);
  late List<String> _categorias = widget.tipo.categorias;
  _Filtro _filtro = _Filtro.pendientes;
  String? _categoria;
  List<ItemLista> _ultimos = const [];

  /// Búsqueda por título y nota (null si el buscador está cerrado).
  TextEditingController? _busqueda;
  String _consulta = '';
  final _random = Random();

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
    final nuevo = await mostrarFormularioItem(
      context,
      tipo: _tipo,
      categorias: _categorias,
      // Solo películas; sin clave no se muestra la búsqueda en TMDB.
      claveTmdb:
          _tipo == TipoLista.peliculas && ConfigClubScope.of(context).posters
          ? widget.repository.tmdbApiKey()
          : null,
    );
    if (nuevo == null || !mounted) return;
    _escribir(
      () => widget.repository.add(
        _tipo,
        nuevo.item,
        pelicula: nuevo.pelicula,
        repetible: nuevo.repetible,
      ),
    );
  }

  Future<void> _editar(ItemLista item) async {
    final cambios = await mostrarFormularioItem(
      context,
      tipo: _tipo,
      categorias: _categorias,
      inicial: item,
      // Solo películas; sin clave no se muestra la búsqueda en TMDB.
      claveTmdb:
          _tipo == TipoLista.peliculas && ConfigClubScope.of(context).posters
          ? widget.repository.tmdbApiKey()
          : null,
    );
    if (cambios == null || !mounted) return;
    _escribir(
      () => widget.repository.update(
        _tipo,
        item.copyWith(
          titulo: cambios.item.titulo,
          categoria: cambios.item.categoria,
          nota: cambios.item.nota,
          pelicula: () => cambios.pelicula,
          repetible: cambios.repetible,
        ),
      ),
    );
  }

  void _abrir(ItemLista item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ItemDetallePage(
          tipo: _tipo,
          itemId: item.id,
          repository: widget.repository,
          onEditar: _editar,
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
            content: TextoConGatito(
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
      // Con sesión iniciada, pregunta qué tal estuvo (en modo local no).
      if (widget.repository.autorActual != null &&
          ConfigClubScope.of(context).calificaciones) {
        calificarItem(
          context,
          repository: widget.repository,
          tipo: _tipo,
          item: item,
        );
      }
    }
  }

  /// Repetibles (🔁): confirma y suma una vez; siguen pendientes. No hay
  /// "deshacer" porque el contador solo se guarda sumando.
  Future<void> _otraVez(ItemLista item) async {
    if (!await confirmarOtraVez(context, item) || !mounted) return;
    _escribir(() => widget.repository.registrarVez(_tipo, item.id));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: TextoConGatito('¡Otra vez! Ya van ${item.veces + 1} 🫘'),
        ),
      );
    // Con sesión iniciada, pregunta qué tal estuvo (en modo local no).
    if (widget.repository.autorActual != null &&
        ConfigClubScope.of(context).calificaciones) {
      calificarItem(
        context,
        repository: widget.repository,
        tipo: _tipo,
        item: item,
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
  void dispose() {
    _busqueda?.dispose();
    super.dispose();
  }

  void _abrirBusqueda() => setState(() => _busqueda = TextEditingController());

  void _cerrarBusqueda() {
    final busqueda = _busqueda;
    setState(() {
      _busqueda = null;
      _consulta = '';
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => busqueda?.dispose());
  }

  /// "¿Qué vemos/hacemos hoy?": elige un pendiente al azar y lo abre.
  Future<void> _ruleta() async {
    final elegido = await mostrarRuleta(
      context,
      tipo: _tipo,
      items: _ultimos,
      categorias: _categorias,
      random: _random,
    );
    if (elegido != null && mounted) _abrir(elegido);
  }

  @override
  Widget build(BuildContext context) {
    final busqueda = _busqueda;
    return PopScope(
      canPop: busqueda == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cerrarBusqueda();
      },
      child: _pantalla(context, busqueda),
    );
  }

  Widget _pantalla(BuildContext context, TextEditingController? busqueda) {
    return Scaffold(
      appBar: AppBar(
        leading: busqueda == null
            ? null
            : IconButton(
                tooltip: 'Cerrar búsqueda',
                icon: const Icon(Icons.arrow_back),
                onPressed: _cerrarBusqueda,
              ),
        title: busqueda == null
            ? TituloSeccion(Secciones.deLista(_tipo), _tipo.titulo)
            : CampoBusqueda(
                controller: busqueda,
                onChanged: (q) => setState(() => _consulta = q),
              ),
        actions: [
          if (busqueda == null) ...[
            if (ConfigClubScope.of(context).buscar)
              IconButton(
                tooltip: 'Buscar',
                icon: const Icon(Icons.search_rounded),
                onPressed: _abrirBusqueda,
              ),
            if (ConfigClubScope.of(context).ruleta)
              IconButton(
                tooltip: tituloRuleta(_tipo),
                icon: const Icon(Icons.casino_rounded),
                onPressed: _ruleta,
              ),
            if (_tipo == TipoLista.peliculas)
              IconButton(
                tooltip: 'Cargar lista Disney',
                icon: const Icon(Icons.auto_awesome_rounded),
                onPressed: _cargarDisney,
              ),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _agregar,
        icon: const Icon(Icons.add),
        label: const Text('Agregar'),
      ),
      body: PawBackground(
        child: StreamBuilder<ConfigClub>(
          stream: _config,
          builder: (context, config) {
            if (config.data?.esVisible(_tipo) == false) {
              return const _Mensaje(
                emoji: '🙈',
                texto: 'Esta lista está oculta por ahora.',
              );
            }
            return _lista(context);
          },
        ),
      ),
    );
  }

  Widget _lista(BuildContext context) {
    return StreamBuilder<List<String>>(
      stream: _categoriasStream,
      builder: (context, cats) {
        if (cats.data case final c?) _categorias = c;
        return _listaItems(context);
      },
    );
  }

  Widget _listaItems(BuildContext context) {
    return StreamBuilder<List<ItemLista>>(
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
    );
  }

  Widget _contenido(BuildContext context, List<ItemLista> items) {
    if (items.isEmpty) {
      return _Mensaje(emoji: _tipo.emoji, texto: _tipo.vacio);
    }
    // Los repetibles (🔁) siempre están pendientes y, si ya los hicieron
    // alguna vez, también aparecen en hechos.
    final config = ConfigClubScope.of(context);
    bool pendiente(ItemLista i) => usaRepetible(i, config) || !i.hecho;
    bool hecho(ItemLista i) => usaRepetible(i, config) ? i.veces > 0 : i.hecho;
    final pendientes = items.where(pendiente).length;
    final hechos = items.where(hecho).length;
    final categorias = [
      for (final c in _categorias)
        if (items.any((i) => i.categoria == c)) c,
      ...{
        for (final i in items)
          if (!_categorias.contains(i.categoria)) i.categoria,
      },
    ];
    final categoria = categorias.contains(_categoria) ? _categoria : null;
    final visibles = items.where((i) {
      final porFiltro = switch (_filtro) {
        _Filtro.pendientes => pendiente(i),
        _Filtro.hechos => hecho(i),
        _Filtro.todos => true,
      };
      return porFiltro &&
          (categoria == null || i.categoria == categoria) &&
          coincideBusqueda(i, _consulta);
    }).toList();
    final buscando = _consulta.trim().isNotEmpty;

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
                  label: _Etiqueta('Pendientes $pendientes'),
                ),
                ButtonSegment(
                  value: _Filtro.hechos,
                  label: _Etiqueta('${_tipo.accionHecho}s $hechos'),
                ),
                ButtonSegment(
                  value: _Filtro.todos,
                  label: _Etiqueta('Todo ${items.length}'),
                ),
              ],
              selected: {_filtro},
              showSelectedIcon: false,
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onSelectionChanged: (s) => setState(() => _filtro = s.first),
            ),
          ),
        ),
        if (categorias.length > 1)
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  for (final c in [null, ...categorias])
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(c ?? 'Todas'),
                        labelStyle: Theme.of(context).textTheme.bodySmall,
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        showCheckmark: false,
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
            child: buscando
                ? _Mensaje(
                    emoji: '🔍',
                    texto: 'Nada coincide con «${_consulta.trim()}»',
                  )
                : _Mensaje(
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
                TarjetaItem(
                  item: item,
                  onMarcar: (v) => _marcar(item, v),
                  onOtraVez: () => _otraVez(item),
                  onAbrir: () => _abrir(item),
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
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$hechos de $total $etiqueta',
                    style: textTheme.titleSmall,
                  ),
                ),
                Text(
                  '${(avance * 100).round()} %',
                  style: textTheme.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(value: avance, minHeight: 8),
            ),
          ],
        ),
      ),
    );
  }
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
            emojiOGatito(emoji, 64),
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

/// Texto de un filtro: una sola línea que se encoge si no cabe.
class _Etiqueta extends StatelessWidget {
  const _Etiqueta(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    child: Text(texto, maxLines: 1, softWrap: false),
  );
}
