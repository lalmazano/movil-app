import 'package:flutter/material.dart';

import '../../domain/item_lista.dart';

/// Resultado del diálogo de calificación.
typedef RespuestaCalificacion = ({int huellitas, String comentario});

/// Pregunta "¿Qué tal estuvo?" con 1–5 huellitas y un comentario opcional.
/// Devuelve null si se omite o se cierra.
Future<RespuestaCalificacion?> mostrarDialogoCalificar(
  BuildContext context, {
  required String titulo,
  Calificacion? inicial,
}) => showDialog<RespuestaCalificacion>(
  context: context,
  builder: (_) => _DialogoCalificar(titulo: titulo, inicial: inicial),
);

/// Muestra el diálogo y, si se guarda, califica como [ListaRepository.autorActual].
/// No hace nada en modo local (sin autor).
Future<void> calificarItem(
  BuildContext context, {
  required ListaRepository repository,
  required TipoLista tipo,
  required ItemLista item,
}) async {
  final autor = repository.autorActual;
  if (autor == null) return;
  final messenger = ScaffoldMessenger.of(context);
  final r = await mostrarDialogoCalificar(
    context,
    titulo: item.titulo,
    inicial: item.calificaciones[autor.uid],
  );
  if (r == null) return;
  try {
    await repository.calificar(
      tipo,
      item.id,
      Calificacion(
        autor: autor,
        huellitas: r.huellitas,
        comentario: r.comentario,
      ),
    );
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(content: Text('No se pudo guardar. Revisa la conexión')),
    );
  }
}

class _DialogoCalificar extends StatefulWidget {
  const _DialogoCalificar({required this.titulo, this.inicial});

  final String titulo;
  final Calificacion? inicial;

  @override
  State<_DialogoCalificar> createState() => _DialogoCalificarState();
}

class _DialogoCalificarState extends State<_DialogoCalificar> {
  late int _huellitas = widget.inicial?.huellitas ?? 0;
  late final _comentario = TextEditingController(
    text: widget.inicial?.comentario ?? '',
  );

  @override
  void dispose() {
    _comentario.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('¿Qué tal estuvo?'),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.titulo,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                InkResponse(
                  key: Key('huellita-$i'),
                  radius: 20,
                  onTap: () => setState(() => _huellitas = i),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Opacity(
                      opacity: i <= _huellitas ? 1 : 0.25,
                      child: const Text('🐾', style: TextStyle(fontSize: 26)),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('campo-comentario'),
            controller: _comentario,
            maxLength: 140,
            maxLines: 2,
            minLines: 1,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Comentario (opcional)',
              isDense: true,
              counterText: '',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Omitir'),
        ),
        FilledButton(
          onPressed: _huellitas < 1
              ? null
              : () => Navigator.pop<RespuestaCalificacion>(context, (
                  huellitas: _huellitas,
                  comentario: _comentario.text.trim(),
                )),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
