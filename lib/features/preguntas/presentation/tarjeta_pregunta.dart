import 'package:flutter/material.dart';

import '../../listas/domain/item_lista.dart';
import '../../listas/presentation/config_scope.dart';
import '../../listas/presentation/widgets/huellitas.dart';
import '../domain/preguntas_repository.dart';
import 'pregunta_page.dart';

/// Tarjeta en el inicio con la pregunta del día. Se oculta si la bandera
/// `preguntas` de config/app es false o si no hay sesión (sin identidad no
/// hay respuestas propias).
class TarjetaPregunta extends StatefulWidget {
  const TarjetaPregunta({super.key, required this.repository});

  final ListaRepository repository;

  @override
  State<TarjetaPregunta> createState() => _TarjetaPreguntaState();
}

class _TarjetaPreguntaState extends State<TarjetaPregunta> {
  PreguntasRepository get _preguntas => widget.repository.preguntas;

  /// Día del stream actual; si cambia (pasó la medianoche) se vuelve a pedir.
  String? _dia;
  Stream<DiaPregunta>? _stream;
  Future<Autor?>? _pareja;

  void _preparar() {
    final hoy = _preguntas.hoy;
    if (_dia == hoy && _stream != null) return;
    _dia = hoy;
    _preguntas.asegurarHoy().catchError((Object e) {
      // Sin conexión: la pregunta del banco se muestra igual.
      debugPrint('No se pudo crear la pregunta del día: $e');
    });
    _stream = _preguntas.watchDia(hoy);
    _pareja ??= _preguntas.pareja().catchError((Object _) => null);
  }

  @override
  Widget build(BuildContext context) {
    if (!ConfigClubScope.of(context).preguntas ||
        widget.repository.autorActual == null) {
      return const SizedBox.shrink();
    }
    _preparar();
    final textTheme = Theme.of(context).textTheme;
    return Card(
      key: const Key('tarjeta-pregunta'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PreguntaPage(repository: _preguntas, dia: _dia!),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: FutureBuilder<Autor?>(
            future: _pareja,
            builder: (context, pareja) => StreamBuilder<DiaPregunta>(
              stream: _stream,
              builder: (context, snap) {
                final dia = snap.data;
                final otro = nombreOtro(
                  dia?.otras.firstOrNull?.autor ?? pareja.data,
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '🎲 Pregunta del día',
                            style: textTheme.labelLarge,
                          ),
                        ),
                        const Icon(Icons.chevron_right, size: 20),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dia?.pregunta ?? '…',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (dia != null && !dia.cargando) ...[
                      const SizedBox(height: 4),
                      if (!dia.respondi)
                        _Estado('✍️ Responde para ver la respuesta de $otro')
                      else if (dia.otras.isEmpty)
                        _Estado('⏳ Esperando a $otro…')
                      else
                        _AmbasRespuestas(respuestas: [dia.mia!, ...dia.otras]),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Nombre corto de la otra persona, o uno cariñoso si aún no se conoce.
String nombreOtro(Autor? otro) {
  final nombre = otro?.nombre?.trim() ?? '';
  return nombre.isEmpty ? 'la otra persona' : otro!.nombreCorto;
}

class _Estado extends StatelessWidget {
  const _Estado(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Text(
    texto,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: Theme.of(context).textTheme.bodySmall
        ?.copyWith(fontStyle: FontStyle.italic),
  );
}

/// Las respuestas en una sola línea: avatar y texto corto de cada uno.
class _AmbasRespuestas extends StatelessWidget {
  const _AmbasRespuestas({required this.respuestas});

  final List<Respuesta> respuestas;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final (i, r) in respuestas.indexed) ...[
        if (i > 0) const SizedBox(width: 10),
        Expanded(child: _RespuestaCorta(respuesta: r)),
      ],
    ],
  );
}

class _RespuestaCorta extends StatelessWidget {
  const _RespuestaCorta({required this.respuesta});

  final Respuesta respuesta;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      AvatarAutor(autor: respuesta.autor, radio: 9),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          respuesta.texto,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    ],
  );
}
