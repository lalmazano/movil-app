import 'package:flutter/material.dart';

import '../../../core/widgets/mosaico_inicio.dart';
import '../../listas/domain/item_lista.dart';
import '../../listas/presentation/config_scope.dart';
import '../domain/fechas_repository.dart';
import 'fechas_page.dart';

/// Tarjeta en el inicio con la próxima fecha importante:
/// "📆 Cumpleaños de Ana · Faltan 12 días". Se oculta con la bandera `fechas`
/// de config/app en false. Al tocarla se abre [FechasPage].
class TarjetaFechas extends StatelessWidget {
  const TarjetaFechas({super.key, required this.repository});

  final ListaRepository repository;

  /// Texto de la tarjeta (null si no hay ninguna fecha por venir).
  static String? texto(List<FechaImportante> fechas, DateTime hoy) {
    final f = siguienteFecha(fechas, hoy);
    return f == null ? null : '📆 ${f.titulo} · ${f.cuentaRegresiva(hoy)}';
  }

  @override
  Widget build(BuildContext context) {
    if (!ConfigClubScope.of(context).fechas) return const SizedBox.shrink();
    return _Contenido(fechas: repository.fechas);
  }
}

class _Contenido extends StatefulWidget {
  const _Contenido({required this.fechas});

  final FechasRepository fechas;

  @override
  State<_Contenido> createState() => _ContenidoState();
}

class _ContenidoState extends State<_Contenido> {
  late final _stream = widget.fechas.watch();

  void _abrir() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => FechasPage(repository: widget.fechas),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FechaImportante>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return MosaicoInicio(
            key: const Key('tarjeta-fechas'),
            emoji: '📆',
            titulo: 'Fechas',
            subtitulo: 'No se pudieron cargar',
            onTap: _abrir,
          );
        }
        final fechas = snap.data ?? const <FechaImportante>[];
        final hoy = widget.fechas.hoy();
        final siguiente = siguienteFecha(fechas, hoy);
        final cercana = siguiente?.esCercana(hoy) ?? false;
        final texto = TarjetaFechas.texto(fechas, hoy)?.replaceFirst('📆 ', '');
        return MosaicoInicio(
          key: const Key('tarjeta-fechas'),
          emoji: '📆',
          titulo: 'Fechas',
          subtitulo:
              texto ??
              (fechas.isEmpty
                  ? 'Agrega sus fechas importantes'
                  : 'No hay fechas próximas'),
          destacado: cercana,
          onTap: _abrir,
        );
      },
    );
  }
}
