import 'package:flutter/material.dart';

import '../../listas/domain/item_lista.dart';
import '../../listas/presentation/widgets/huellitas.dart';
import '../domain/preguntas_repository.dart';
import 'banco_preguntas_page.dart';
import 'tarjeta_pregunta.dart' show nombreOtro;

const _meses = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

/// "28 de noviembre" (y el año si no es el actual).
String fechaLegible(String dia, {DateTime? hoy}) {
  final f = fechaDeClave(dia);
  if (f == null) return dia;
  final anio = (hoy ?? DateTime.now()).year;
  return '${f.day} de ${_meses[f.month - 1]}'
      '${f.year == anio ? '' : ' de ${f.year}'}';
}

/// Pregunta de un día: la pregunta, mi respuesta (editable), la del otro en
/// cuanto respondo y, si es la de hoy, los días anteriores.
class PreguntaPage extends StatefulWidget {
  const PreguntaPage({super.key, required this.repository, required this.dia});

  final PreguntasRepository repository;

  /// Clave `aaaa-mm-dd`.
  final String dia;

  @override
  State<PreguntaPage> createState() => _PreguntaPageState();
}

class _PreguntaPageState extends State<PreguntaPage> {
  late final _stream = widget.repository.watchDia(widget.dia);
  late final _esHoy = widget.dia == widget.repository.hoy;
  late final _historial = _esHoy
      ? widget.repository.watchHistorial()
      : const Stream<List<DiaPregunta>>.empty();
  late final _pareja = widget.repository.pareja().catchError(
    (Object _) => null,
  );
  final _texto = TextEditingController();
  var _editando = false;
  var _guardando = false;

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final texto = _texto.text.trim();
    if (texto.isEmpty) return;
    setState(() => _guardando = true);
    try {
      await widget.repository.responder(widget.dia, texto);
      if (mounted) setState(() => _editando = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _editar(Respuesta mia) => setState(() {
    _texto.text = mia.texto;
    _editando = true;
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _esHoy ? '🎲 Pregunta del día' : '🎲 ${fechaLegible(widget.dia)}',
        ),
        actions: [
          IconButton(
            tooltip: 'Banco de preguntas',
            icon: const Icon(Icons.lightbulb_outline),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    BancoPreguntasPage(repository: widget.repository),
              ),
            ),
          ),
        ],
      ),
      body: FutureBuilder<Autor?>(
        future: _pareja,
        builder: (context, pareja) => StreamBuilder<DiaPregunta>(
          stream: _stream,
          builder: (context, snap) {
            final dia = snap.data;
            if (dia == null) {
              return const Center(child: CircularProgressIndicator());
            }
            final otro = nombreOtro(
              dia.otras.firstOrNull?.autor ?? pareja.data,
            );
            final mia = dia.mia;
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      dia.pregunta,
                      textAlign: TextAlign.center,
                      style: textTheme.titleLarge,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Tu respuesta', style: textTheme.titleMedium),
                const SizedBox(height: 8),
                if (dia.cargando)
                  const LinearProgressIndicator()
                else if (mia == null || _editando)
                  _CampoRespuesta(
                    controller: _texto,
                    guardando: _guardando,
                    editando: mia != null,
                    onGuardar: _guardar,
                    onCancelar: mia == null
                        ? null
                        : () => setState(() => _editando = false),
                  )
                else
                  _TarjetaRespuesta(
                    respuesta: mia,
                    onEditar: () => _editar(mia),
                  ),
                const SizedBox(height: 20),
                Text('Respuesta de $otro', style: textTheme.titleMedium),
                const SizedBox(height: 8),
                if (dia.cargando)
                  const SizedBox.shrink()
                else if (mia == null)
                  _Aviso('🔒 Responde para ver la respuesta de $otro')
                else if (dia.otras.isEmpty)
                  _Aviso('⏳ Esperando a $otro…')
                else
                  for (final r in dia.otras) _TarjetaRespuesta(respuesta: r),
                if (_esHoy) ...[
                  const SizedBox(height: 28),
                  Text('Días anteriores', style: textTheme.titleMedium),
                  const SizedBox(height: 8),
                  StreamBuilder<List<DiaPregunta>>(
                    stream: _historial,
                    builder: (context, snap) {
                      final dias = snap.data ?? const <DiaPregunta>[];
                      if (dias.isEmpty) {
                        return const _Aviso(
                          'Aquí irán las preguntas de otros días 🫘',
                        );
                      }
                      return Column(
                        children: [
                          for (final d in dias)
                            _DiaAnterior(
                              dia: d,
                              otro: otro,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => PreguntaPage(
                                    repository: widget.repository,
                                    dia: d.dia,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CampoRespuesta extends StatelessWidget {
  const _CampoRespuesta({
    required this.controller,
    required this.guardando,
    required this.editando,
    required this.onGuardar,
    this.onCancelar,
  });

  final TextEditingController controller;
  final bool guardando;
  final bool editando;
  final VoidCallback onGuardar;
  final VoidCallback? onCancelar;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      TextField(
        key: const Key('campo-respuesta'),
        controller: controller,
        minLines: 2,
        maxLines: 6,
        maxLength: maxCaracteresRespuesta,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          hintText: 'Escribe lo que sientas…',
          border: OutlineInputBorder(),
        ),
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (onCancelar != null)
            TextButton(onPressed: onCancelar, child: const Text('Cancelar')),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: guardando ? null : onGuardar,
            icon: const Icon(Icons.favorite),
            label: Text(editando ? 'Guardar' : 'Responder'),
          ),
        ],
      ),
    ],
  );
}

class _TarjetaRespuesta extends StatelessWidget {
  const _TarjetaRespuesta({required this.respuesta, this.onEditar});

  final Respuesta respuesta;
  final VoidCallback? onEditar;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AvatarAutor(autor: respuesta.autor, radio: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  respuesta.autor.nombreCorto,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 2),
                Text(respuesta.texto),
              ],
            ),
          ),
          if (onEditar != null)
            IconButton(
              tooltip: 'Editar respuesta',
              icon: const Icon(Icons.edit_outlined),
              onPressed: onEditar,
            ),
        ],
      ),
    ),
  );
}

class _Aviso extends StatelessWidget {
  const _Aviso(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Text(
      texto,
      style: Theme.of(context).textTheme.bodyMedium
          ?.copyWith(fontStyle: FontStyle.italic),
    ),
  );
}

class _DiaAnterior extends StatelessWidget {
  const _DiaAnterior({
    required this.dia,
    required this.otro,
    required this.onTap,
  });

  final DiaPregunta dia;
  final String otro;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(fechaLegible(dia.dia), style: textTheme.labelMedium),
              const SizedBox(height: 2),
              Text(
                dia.pregunta,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              if (dia.mia case final mia?)
                for (final r in [mia, ...dia.otras])
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AvatarAutor(autor: r.autor, radio: 9),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            r.texto,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  )
              else
                Text(
                  'No respondiste. Toca para responder y ver la de $otro.',
                  style: textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
