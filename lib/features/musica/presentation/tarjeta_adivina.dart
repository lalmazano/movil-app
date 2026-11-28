import 'package:flutter/material.dart';

import '../../listas/domain/item_lista.dart';
import '../../listas/presentation/config_scope.dart';
import '../domain/adivina_juego.dart';
import '../domain/musica_repository.dart';
import 'adivina_page.dart';

/// Tarjeta en el inicio con el juego "❓ Adivina la canción": muestra mi
/// récord ("Tu récord: 4/5") o avisa si faltan canciones en la playlist. Se
/// oculta con la bandera `adivina` de config/app en false. Al tocarla se abre
/// [AdivinaPage].
class TarjetaAdivina extends StatelessWidget {
  const TarjetaAdivina({super.key, required this.repository});

  final ListaRepository repository;

  /// Texto debajo del título según la playlist y mi récord.
  static String subtitulo({
    required List<Cancion> playlist,
    required RecordAdivina? miRecord,
  }) {
    final rondas = AdivinaJuego.rondasPosibles(playlist);
    if (rondas == 0) {
      return 'Necesitan al menos ${AdivinaJuego.minimoCanciones} canciones '
          'en la playlist';
    }
    if (miRecord == null) return '🎧 ¿Quién tiene mejor oído?';
    return 'Tu récord: ${miRecord.mejor}/$rondas';
  }

  @override
  Widget build(BuildContext context) {
    if (!ConfigClubScope.of(context).adivina) return const SizedBox.shrink();
    return _Contenido(musica: repository.musica);
  }
}

class _Contenido extends StatefulWidget {
  const _Contenido({required this.musica});

  final MusicaRepository musica;

  @override
  State<_Contenido> createState() => _ContenidoState();
}

class _ContenidoState extends State<_Contenido> {
  late final _playlist = widget.musica.watchPlaylist();
  late final _records = widget.musica.watchRecords();

  void _abrir() => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => AdivinaPage(musica: widget.musica)),
  );

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return StreamBuilder<List<CancionPlaylist>>(
      stream: _playlist,
      builder: (context, playlist) => StreamBuilder<List<RecordAdivina>>(
        stream: _records,
        builder: (context, records) {
          // Si falla la lectura (p. ej. reglas sin publicar) no se muestra.
          if (playlist.hasError) return const SizedBox.shrink();
          final uid = widget.musica.autorActual?.uid ?? 'local';
          final canciones = [
            for (final c in playlist.data ?? const <CancionPlaylist>[])
              c.cancion,
          ];
          RecordAdivina? mio;
          for (final r in records.data ?? const <RecordAdivina>[]) {
            if (r.autor.uid == uid) mio = r;
          }
          return Card(
            key: const Key('tarjeta-adivina'),
            margin: const EdgeInsets.only(bottom: 12),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: _abrir,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '❓ Adivina la canción',
                            style: textTheme.titleSmall,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            TarjetaAdivina.subtitulo(
                              playlist: canciones,
                              miRecord: mio,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.play_arrow_rounded),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
