import 'package:flutter/material.dart';

import '../../../core/widgets/mosaico_inicio.dart';
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
    return StreamBuilder<List<CancionPlaylist>>(
      stream: _playlist,
      builder: (context, playlist) => StreamBuilder<List<RecordAdivina>>(
        stream: _records,
        builder: (context, records) {
          if (playlist.hasError) {
            return MosaicoInicio(
              key: const Key('tarjeta-adivina'),
              emoji: '❓',
              titulo: 'Adivina la canción',
              subtitulo: 'No se pudo cargar la playlist',
              onTap: _abrir,
            );
          }
          final uid = widget.musica.autorActual?.uid ?? 'local';
          final canciones = [
            for (final c in playlist.data ?? const <CancionPlaylist>[])
              c.cancion,
          ];
          RecordAdivina? mio;
          for (final r in records.data ?? const <RecordAdivina>[]) {
            if (r.autor.uid == uid) mio = r;
          }
          return MosaicoInicio(
            key: const Key('tarjeta-adivina'),
            emoji: '❓',
            titulo: 'Adivina la canción',
            subtitulo: TarjetaAdivina.subtitulo(
              playlist: canciones,
              miRecord: mio,
            ),
            onTap: _abrir,
          );
        },
      ),
    );
  }
}
