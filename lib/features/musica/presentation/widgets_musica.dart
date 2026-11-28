import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/buscador_musica.dart';
import '../data/itunes_client.dart';
import '../domain/cancion.dart';
import 'reproductor.dart';

/// Portada cuadrada redondeada (con nota musical si no hay imagen).
class PortadaCancion extends StatelessWidget {
  const PortadaCancion({super.key, required this.cancion, this.lado = 48});

  final Cancion? cancion;
  final double lado;

  @override
  Widget build(BuildContext context) {
    final url = cancion?.portadaUrl;
    final respaldo = Container(
      width: lado,
      height: lado,
      color: Theme.of(context).colorScheme.secondaryContainer,
      alignment: Alignment.center,
      child: Text('🎵', style: TextStyle(fontSize: lado * 0.45)),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(lado / 6),
      child: url == null
          ? respaldo
          : Image.network(
              url,
              width: lado,
              height: lado,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => respaldo,
            ),
    );
  }
}

/// Botón ▶/⏸ para escuchar la muestra de 30 s.
class BotonPreview extends StatelessWidget {
  const BotonPreview({super.key, required this.cancion, this.tamano = 24});

  final Cancion cancion;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    if (cancion.previewUrl == null) return const SizedBox.shrink();
    final r = Reproductor.instancia;
    return ListenableBuilder(
      listenable: r,
      builder: (context, _) {
        final esta = r.actual == cancion;
        return IconButton(
          key: ValueKey('preview-${cancion.clave}'),
          tooltip: esta ? 'Detener' : 'Escuchar muestra',
          iconSize: tamano,
          visualDensity: VisualDensity.compact,
          icon: Icon(esta ? Icons.stop_circle : Icons.play_circle_fill),
          onPressed: () => r.alternar(cancion),
        );
      },
    );
  }
}

/// Fila compacta: portada, título, artista y botón de muestra.
class FilaCancion extends StatelessWidget {
  const FilaCancion({
    super.key,
    required this.cancion,
    this.onTap,
    this.trailing,
    this.subtitulo,
  });

  final Cancion cancion;
  final VoidCallback? onTap;
  final Widget? trailing;
  final String? subtitulo;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListTile(
      onTap: onTap,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.only(left: 12, right: 4),
      leading: PortadaCancion(cancion: cancion, lado: 44),
      title: Text(cancion.titulo, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        subtitulo ?? cancion.artista,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: textTheme.bodySmall,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          BotonPreview(cancion: cancion),
          ?trailing,
        ],
      ),
    );
  }
}

/// Abre la canción completa en Spotify, YouTube Music o Apple Music.
Future<void> mostrarAbrirCancion(BuildContext context, Cancion cancion) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) {
        Future<void> abrir(Uri url) async {
          Navigator.pop(sheet);
          final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
          if (!ok && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No se pudo abrir la canción')),
            );
          }
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilaCancion(cancion: cancion),
              const Divider(height: 1),
              ListTile(
                leading: const _LogoMarca(
                  FontAwesomeIcons.spotify,
                  Color(0xFF1DB954),
                ),
                title: const Text('Escuchar en Spotify'),
                onTap: () => abrir(cancion.spotifyUrl),
              ),
              ListTile(
                leading: const _LogoMarca(
                  FontAwesomeIcons.youtube,
                  Color(0xFFFF0000),
                ),
                title: const Text('Escuchar en YouTube Music'),
                onTap: () => abrir(cancion.youtubeMusicUrl),
              ),
              if (cancion.deezerUrl case final deezer?)
                ListTile(
                  leading: const _LogoMarca(
                    FontAwesomeIcons.deezer,
                    Color(0xFFA238FF),
                  ),
                  title: const Text('Escuchar en Deezer'),
                  onTap: () => abrir(deezer),
                ),
              if (cancion.appleUrl case final apple?)
                ListTile(
                  leading: const _LogoMarca(
                    FontAwesomeIcons.apple,
                    Color(0xFFFA243C),
                  ),
                  title: const Text('Escuchar en Apple Music'),
                  onTap: () => abrir(Uri.parse(apple)),
                ),
            ],
          ),
        );
      },
    );

/// Logo de una app de música, con su color.
class _LogoMarca extends StatelessWidget {
  const _LogoMarca(this.icono, this.color);

  final FaIconData icono;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 32,
    child: Center(child: FaIcon(icono, color: color, size: 26)),
  );
}

/// Buscador de canciones (iTunes y Deezer). Devuelve la elegida o null.
Future<Cancion?> mostrarBuscadorCanciones(
  BuildContext context, {
  String titulo = '🎵 Buscar canción',
}) async {
  final elegida = await showModalBottomSheet<Cancion>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _BuscadorCanciones(titulo: titulo),
  );
  unawaited(Reproductor.instancia.detener());
  return elegida;
}

class _BuscadorCanciones extends StatefulWidget {
  const _BuscadorCanciones({required this.titulo});

  final String titulo;

  @override
  State<_BuscadorCanciones> createState() => _BuscadorCancionesState();
}

class _BuscadorCancionesState extends State<_BuscadorCanciones> {
  final _texto = TextEditingController();
  Timer? _espera;
  List<Cancion>? _resultados;
  String? _error;
  bool _buscando = false;
  int _consulta = 0;

  @override
  void dispose() {
    _espera?.cancel();
    _texto.dispose();
    super.dispose();
  }

  void _cambio(String _) {
    _espera?.cancel();
    _espera = Timer(const Duration(milliseconds: 450), _buscar);
  }

  Future<void> _buscar() async {
    final termino = _texto.text.trim();
    final n = ++_consulta;
    if (termino.isEmpty) {
      setState(() {
        _resultados = null;
        _error = null;
      });
      return;
    }
    setState(() => _buscando = true);
    try {
      final r = await buscarEnAmbas(termino);
      if (!mounted || n != _consulta) return;
      setState(() {
        _resultados = r;
        _error = null;
      });
    } on ItunesException catch (e) {
      if (!mounted || n != _consulta) return;
      setState(() => _error = e.mensaje);
    } finally {
      if (mounted && n == _consulta) setState(() => _buscando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final resultados = _resultados;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          children: [
            Text(widget.titulo, style: textTheme.titleMedium),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: TextField(
                key: const Key('campo-buscar-cancion'),
                controller: _texto,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: _cambio,
                onSubmitted: (_) => _buscar(),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Canción o artista',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _buscando
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            Expanded(
              child: resultados == null
                  ? Center(
                      child: Text(
                        'Escribe para buscar en iTunes y Deezer 🎶',
                        style: textTheme.bodyMedium,
                      ),
                    )
                  : resultados.isEmpty
                  ? Center(
                      child: Text(
                        'Sin resultados',
                        style: textTheme.bodyMedium,
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.viewPaddingOf(context).bottom,
                      ),
                      itemCount: resultados.length,
                      itemBuilder: (context, i) => FilaCancion(
                        key: ValueKey('resultado-${resultados[i].clave}'),
                        cancion: resultados[i],
                        subtitulo:
                            '${resultados[i].artista} · '
                            '${resultados[i].esDeezer ? 'Deezer' : 'iTunes'}',
                        onTap: () => Navigator.pop(context, resultados[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
