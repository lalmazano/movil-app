import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../listas/presentation/config_scope.dart';
import '../domain/musica_repository.dart';
import 'reproductor.dart';
import 'widgets_musica.dart';

/// Cómo se ordena la playlist.
enum OrdenPlaylist { recientes, corazones }

/// Ordena una copia de [canciones]: de la más nueva a la más vieja, o por
/// cantidad de ❤️ (empates: la más nueva primero).
List<CancionPlaylist> ordenarPlaylist(
  List<CancionPlaylist> canciones,
  OrdenPlaylist orden,
) {
  int porFecha(CancionPlaylist a, CancionPlaylist b) =>
      b.agregadaEn.compareTo(a.agregadaEn);
  return [...canciones]..sort(
    orden == OrdenPlaylist.recientes
        ? porFecha
        : (a, b) {
            final c = b.corazones.length.compareTo(a.corazones.length);
            return c != 0 ? c : porFecha(a, b);
          },
  );
}

/// Fecha como dd/mm/aaaa.
String fechaPlaylist(DateTime f) =>
    '${f.day.toString().padLeft(2, '0')}/'
    '${f.month.toString().padLeft(2, '0')}/${f.year}';

/// 📀 La playlist compartida del club.
class PlaylistPage extends StatefulWidget {
  const PlaylistPage({super.key, required this.musica, this.azar});

  final MusicaRepository musica;

  /// Para elegir canción al azar (inyectable en pruebas).
  final Random? azar;

  @override
  State<PlaylistPage> createState() => _PlaylistPageState();
}

class _PlaylistPageState extends State<PlaylistPage> {
  /// Se crea solo cuando la bandera está activa.
  Stream<List<CancionPlaylist>>? _playlist;
  OrdenPlaylist _orden = OrdenPlaylist.recientes;
  late final Random _azar = widget.azar ?? Random();

  MusicaRepository get _musica => widget.musica;

  @override
  void dispose() {
    unawaited(Reproductor.instancia.detener());
    super.dispose();
  }

  void _avisar(String texto) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _agregar() async {
    final cancion = await mostrarBuscadorCanciones(
      context,
      titulo: '🎶 Agregar a la playlist',
    );
    if (cancion == null || !mounted) return;
    try {
      final nueva = await _musica.agregar(cancion);
      if (!mounted) return;
      _avisar(nueva ? '¡Agregada! 🎶' : 'Ya está en la playlist');
    } catch (_) {
      if (mounted) _avisar('No se pudo agregar la canción');
    }
  }

  Future<void> _corazon(CancionPlaylist c) async {
    try {
      await _musica.alternarCorazon(c.id);
    } catch (_) {
      if (mounted) _avisar('No se pudo guardar tu ❤️');
    }
  }

  Future<void> _quitar(CancionPlaylist c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: const Text('¿Quitar de la playlist?'),
        content: Text('"${c.cancion.titulo}" ya no estará en sus canciones.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogo, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogo, true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      if (Reproductor.instancia.actual == c.cancion) {
        unawaited(Reproductor.instancia.detener());
      }
      await _musica.quitar(c.id);
      if (mounted) _avisar('Quitada de la playlist');
    } catch (_) {
      if (mounted) _avisar('No se pudo quitar la canción');
    }
  }

  Future<void> _opciones(CancionPlaylist c) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.remove_circle_outline),
            title: const Text('Quitar de la playlist'),
            onTap: () {
              Navigator.pop(sheet);
              _quitar(c);
            },
          ),
        ],
      ),
    ),
  );

  void _alAzar(List<CancionPlaylist> canciones) {
    if (canciones.isEmpty) return;
    final c = canciones[_azar.nextInt(canciones.length)];
    mostrarAbrirCancion(context, c.cancion);
  }

  @override
  Widget build(BuildContext context) {
    if (!ConfigClubScope.of(context).playlist) {
      return Scaffold(
        appBar: AppBar(title: const Text('📀 Nuestras canciones')),
        body: const Center(child: Text('La playlist está desactivada')),
      );
    }
    return StreamBuilder<List<CancionPlaylist>>(
      stream: _playlist ??= _musica.watchPlaylist(),
      builder: (context, snap) {
        final canciones = ordenarPlaylist(snap.data ?? const [], _orden);
        final porCorazones = _orden == OrdenPlaylist.corazones;
        return Scaffold(
          appBar: AppBar(
            title: const Text('📀 Nuestras canciones'),
            actions: [
              if (canciones.isNotEmpty)
                IconButton(
                  key: const Key('playlist-azar'),
                  tooltip: '🎲 ¿Qué escuchamos?',
                  icon: const Text('🎲', style: TextStyle(fontSize: 22)),
                  onPressed: () => _alAzar(canciones),
                ),
              IconButton(
                key: const Key('playlist-orden'),
                tooltip: porCorazones
                    ? 'Ordenar por más recientes'
                    : 'Ordenar por más ❤️',
                icon: Icon(porCorazones ? Icons.favorite : Icons.schedule),
                onPressed: () => setState(
                  () => _orden = porCorazones
                      ? OrdenPlaylist.recientes
                      : OrdenPlaylist.corazones,
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _agregar,
            icon: const Icon(Icons.add),
            label: const Text('Agregar canción'),
          ),
          body: snap.hasError
              ? const _Mensaje(
                  emoji: '😿',
                  texto: 'No se pudo cargar la playlist',
                )
              : !snap.hasData
              ? const Center(child: CircularProgressIndicator())
              : canciones.isEmpty
              ? const _Mensaje(
                  emoji: '🎶',
                  texto:
                      'Todavía no hay canciones.\n'
                      'Agreguen la primera: la de su primera cita, '
                      'la que cantan en el carro…',
                )
              : ListView(
                  padding: const EdgeInsets.only(bottom: 88),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Text(
                        '${textoCancionesPlaylist(canciones.length)} · '
                        '${porCorazones ? 'Más ❤️' : 'Más recientes'}',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                    for (final c in canciones)
                      _FilaPlaylist(
                        key: ValueKey('playlist-${c.id}'),
                        entrada: c,
                        uidActual: _musica.autorActual?.uid,
                        onCorazon: () => _corazon(c),
                        onOpciones: () => _opciones(c),
                      ),
                  ],
                ),
        );
      },
    );
  }
}

/// "1 canción" / "12 canciones".
String textoCancionesPlaylist(int n) => n == 1 ? '1 canción' : '$n canciones';

class _Mensaje extends StatelessWidget {
  const _Mensaje({required this.emoji, required this.texto});

  final String emoji;
  final String texto;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(
            texto,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    ),
  );
}

/// Fila de la playlist: portada, título, artista, quién la agregó, ❤️ y ▶.
class _FilaPlaylist extends StatelessWidget {
  const _FilaPlaylist({
    super.key,
    required this.entrada,
    required this.uidActual,
    required this.onCorazon,
    required this.onOpciones,
  });

  final CancionPlaylist entrada;
  final String? uidActual;
  final VoidCallback onCorazon;
  final VoidCallback onOpciones;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;
    final cancion = entrada.cancion;
    final mia = uidActual != null && entrada.agregadaPor?.uid == uidActual;
    final meGusta = uidActual != null && entrada.corazones.contains(uidActual);
    final quien = entrada.agregadaPor?.nombreCorto;
    return ListTile(
      onTap: () => mostrarAbrirCancion(context, cancion),
      onLongPress: mia ? onOpciones : null,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.only(left: 12, right: 4),
      leading: PortadaCancion(cancion: cancion, lado: 48),
      title: Text(cancion.titulo, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            cancion.artista,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall,
          ),
          Text(
            [
              if (quien != null) 'Agregada por $quien',
              fechaPlaylist(entrada.agregadaEn),
            ].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.labelSmall?.copyWith(
              color: esquema.onSurfaceVariant,
            ),
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          BotonPreview(cancion: cancion),
          InkWell(
            key: ValueKey('corazon-${entrada.id}'),
            borderRadius: BorderRadius.circular(20),
            onTap: onCorazon,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    meGusta ? Icons.favorite : Icons.favorite_border,
                    size: 20,
                    color: meGusta ? Colors.redAccent : esquema.outline,
                    semanticLabel: meGusta ? 'Quitar mi ❤️' : 'Darle ❤️',
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${entrada.corazones.length}',
                    key: ValueKey('corazones-${entrada.id}'),
                    style: textTheme.labelLarge,
                  ),
                ],
              ),
            ),
          ),
          if (mia)
            IconButton(
              tooltip: 'Opciones',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.more_vert, size: 20),
              onPressed: onOpciones,
            ),
        ],
      ),
    );
  }
}
