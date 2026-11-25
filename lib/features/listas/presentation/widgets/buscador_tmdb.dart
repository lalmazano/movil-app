import 'package:flutter/material.dart';

import '../../../../core/tmdb/tmdb_client.dart';
import '../../domain/item_lista.dart';

/// Película elegida en TMDB: su título y los datos para guardar.
typedef SeleccionTmdb = ({String titulo, InfoPelicula info});

/// Abre el buscador de TMDB. Devuelve la película elegida (ya con duración
/// si se pudo obtener el detalle) o null si se cancela.
Future<SeleccionTmdb?> mostrarBuscadorTmdb(
  BuildContext context, {
  required String apiKey,
  String consulta = '',
}) => showDialog<SeleccionTmdb>(
  context: context,
  builder: (_) => _BuscadorTmdb(apiKey: apiKey, consulta: consulta),
);

class _BuscadorTmdb extends StatefulWidget {
  const _BuscadorTmdb({required this.apiKey, required this.consulta});

  final String apiKey;
  final String consulta;

  @override
  State<_BuscadorTmdb> createState() => _BuscadorTmdbState();
}

class _BuscadorTmdbState extends State<_BuscadorTmdb> {
  late final TmdbClient _cliente = TmdbClient.crear(widget.apiKey);
  late final _texto = TextEditingController(text: widget.consulta);
  List<ResultadoTmdb>? _resultados;
  String? _error;
  bool _cargando = false;

  /// Para ignorar respuestas de búsquedas viejas.
  int _busqueda = 0;

  @override
  void initState() {
    super.initState();
    if (widget.consulta.trim().isNotEmpty) _buscar();
  }

  @override
  void dispose() {
    _texto.dispose();
    _cliente.cerrar();
    super.dispose();
  }

  Future<void> _buscar() async {
    final consulta = _texto.text.trim();
    if (consulta.isEmpty) return;
    final n = ++_busqueda;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final r = await _cliente.buscar(consulta);
      if (!mounted || n != _busqueda) return;
      setState(() => _resultados = r);
    } on TmdbException catch (e) {
      if (!mounted || n != _busqueda) return;
      setState(() => _error = e.mensaje);
    } finally {
      if (mounted && n == _busqueda) setState(() => _cargando = false);
    }
  }

  /// Pide el detalle (duración); si falla, usa lo que trajo la búsqueda.
  Future<void> _elegir(ResultadoTmdb r) async {
    setState(() => _cargando = true);
    InfoPelicula info;
    try {
      info = await _cliente.detalle(r.id);
    } on TmdbException {
      info = r.info;
    }
    if (!mounted) return;
    Navigator.of(context).pop((titulo: r.titulo, info: info));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final resultados = _resultados;
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 520),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('🎞️ Buscar en TMDB', style: textTheme.titleMedium),
              const SizedBox(height: 10),
              TextField(
                key: const Key('campo-buscar-tmdb'),
                controller: _texto,
                autofocus: widget.consulta.trim().isEmpty,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _buscar(),
                decoration: InputDecoration(
                  hintText: 'Título de la película',
                  isDense: true,
                  suffixIcon: IconButton(
                    tooltip: 'Buscar',
                    icon: const Icon(Icons.search),
                    onPressed: _buscar,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (_cargando) const LinearProgressIndicator(minHeight: 2),
              if (_error case final error?)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    error,
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                )
              else if (resultados != null && resultados.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Sin resultados',
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall,
                  ),
                ),
              if (resultados != null && resultados.isNotEmpty)
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: resultados.length,
                    itemBuilder: (_, i) {
                      final r = resultados[i];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        enabled: !_cargando,
                        leading: PosterTmdb(url: r.posterUrl),
                        title: Text(
                          r.titulo,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: r.anio == null ? null : Text('${r.anio}'),
                        onTap: () => _elegir(r),
                      );
                    },
                  ),
                ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Póster redondeado de TMDB; si no hay o no carga, muestra un recuadro.
class PosterTmdb extends StatelessWidget {
  const PosterTmdb({
    super.key,
    required this.url,
    this.ancho = 32,
    this.alto = 48,
    this.radio = 4,
  });

  final String? url;
  final double ancho;
  final double alto;
  final double radio;

  @override
  Widget build(BuildContext context) {
    final vacio = Container(
      width: ancho,
      height: alto,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(Icons.movie_outlined, size: ancho * 0.5),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radio),
      child: url == null
          ? vacio
          : Image.network(
              url!,
              width: ancho,
              height: alto,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => vacio,
            ),
    );
  }
}
