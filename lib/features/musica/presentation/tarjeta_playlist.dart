import 'package:flutter/material.dart';

import '../../listas/domain/item_lista.dart';
import '../../listas/presentation/config_scope.dart';
import '../domain/musica_repository.dart';
import 'playlist_page.dart';
import 'widgets_musica.dart';

/// Tarjeta "📀 Nuestras canciones" en el inicio. Se oculta si la bandera
/// `playlist` de config/app es false.
class TarjetaPlaylist extends StatefulWidget {
  const TarjetaPlaylist({super.key, required this.repository});

  final ListaRepository repository;

  @override
  State<TarjetaPlaylist> createState() => _TarjetaPlaylistState();
}

class _TarjetaPlaylistState extends State<TarjetaPlaylist> {
  /// Se crea solo cuando la bandera está activa (si no, las reglas
  /// rechazarían la lectura).
  Stream<List<CancionPlaylist>>? _playlist;

  MusicaRepository get _musica => widget.repository.musica;

  @override
  Widget build(BuildContext context) {
    if (!ConfigClubScope.of(context).playlist) return const SizedBox.shrink();
    final textTheme = Theme.of(context).textTheme;
    return Card(
      key: const Key('tarjeta-playlist'),
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PlaylistPage(musica: _musica),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: StreamBuilder<List<CancionPlaylist>>(
            stream: _playlist ??= _musica.watchPlaylist(),
            builder: (context, snap) {
              final canciones = snap.data ?? const <CancionPlaylist>[];
              final subtitulo = snap.hasError
                  ? 'No se pudo cargar la playlist'
                  : !snap.hasData
                  ? 'Cargando…'
                  : canciones.isEmpty
                  ? 'Agreguen su primera canción 🎶'
                  : textoCancionesPlaylist(canciones.length);
              return Row(
                children: [
                  const Text('📀', style: TextStyle(fontSize: 32)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nuestras canciones',
                          style: textTheme.titleMedium,
                        ),
                        Text(subtitulo, style: textTheme.bodyMedium),
                      ],
                    ),
                  ),
                  if (canciones.isNotEmpty)
                    _PortadasEncimadas(
                      canciones: [for (final c in canciones.take(4)) c.cancion],
                    ),
                  const Icon(Icons.chevron_right),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Hasta 4 portadas pequeñas, una encima de otra.
class _PortadasEncimadas extends StatelessWidget {
  const _PortadasEncimadas({required this.canciones});

  final List<Cancion> canciones;

  static const _lado = 30.0;
  static const _paso = 18.0;

  @override
  Widget build(BuildContext context) {
    final fondo = Theme.of(context).colorScheme.surface;
    return SizedBox(
      width: _lado + _paso * (canciones.length - 1),
      height: _lado + 4,
      child: Stack(
        children: [
          // La más nueva queda encima (a la izquierda).
          for (var i = canciones.length - 1; i >= 0; i--)
            Positioned(
              left: _paso * i,
              top: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: fondo,
                  borderRadius: BorderRadius.circular(_lado / 5),
                  border: Border.all(color: fondo, width: 2),
                ),
                child: PortadaCancion(cancion: canciones[i], lado: _lado),
              ),
            ),
        ],
      ),
    );
  }
}
