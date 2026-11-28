import 'package:flutter/material.dart';

import '../../listas/presentation/config_scope.dart';
import '../../listas/presentation/widgets/huellitas.dart';
import '../domain/banco_preguntas.dart';
import '../domain/preguntas_repository.dart';
import 'pregunta_page.dart' show fechaLegible;

/// Preguntas propuestas por el club: se pueden agregar desde aquí y salen
/// como pregunta del día antes que las de la app o las de internet.
class BancoPreguntasPage extends StatefulWidget {
  const BancoPreguntasPage({super.key, required this.repository});

  final PreguntasRepository repository;

  @override
  State<BancoPreguntasPage> createState() => _BancoPreguntasPageState();
}

class _BancoPreguntasPageState extends State<BancoPreguntasPage> {
  late final _propuestas = widget.repository.watchPropuestas();

  Future<void> _proponer() async {
    final texto = await showDialog<String>(
      context: context,
      builder: (_) => const _DialogoProponer(),
    );
    if (texto == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.repository.proponer(texto);
      messenger.showSnackBar(
        const SnackBar(content: Text('¡Pregunta agregada al banco! 💡')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo guardar: ${_mensaje(e)}')),
      );
    }
  }

  Future<void> _borrar(PreguntaPropuesta p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Borrar la pregunta?'),
        content: Text(p.texto),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.repository.borrarPropuesta(p.id);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo borrar: ${_mensaje(e)}')),
      );
    }
  }

  static String _mensaje(Object e) =>
      e is ArgumentError ? '${e.message}' : '$e';

  @override
  Widget build(BuildContext context) {
    final config = ConfigClubScope.of(context);
    final textTheme = Theme.of(context).textTheme;
    final yo = widget.repository.autorActual?.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('💡 Banco de preguntas')),
      floatingActionButton: yo == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _proponer,
              icon: const Icon(Icons.add),
              label: const Text('Proponer'),
            ),
      body: StreamBuilder<List<PreguntaPropuesta>>(
        stream: _propuestas,
        builder: (context, snap) {
          final todas = snap.data ?? const <PreguntaPropuesta>[];
          final espera = todas.where((p) => !p.usada).toList()
            ..sort((a, b) => a.creadaEn.compareTo(b.creadaEn));
          final usadas = todas.where((p) => p.usada).toList()
            ..sort((a, b) => b.usadaEn!.compareTo(a.usadaEn!));
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    'Las preguntas que propongan salen primero, en orden. '
                    'Cuando no hay propuestas, la app usa sus '
                    '${bancoTamano()} preguntas'
                    '${config.preguntasInternet ? ' y, un día sí y uno no, '
                              'preguntas de internet en español' : ''}.',
                    style: textTheme.bodySmall,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text('En espera (${espera.length})', style: textTheme.titleSmall),
              if (espera.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No hay propuestas. ¡Agrega una con "Proponer"!',
                    style: textTheme.bodyMedium,
                  ),
                ),
              for (final (i, p) in espera.indexed)
                _TarjetaPropuesta(
                  propuesta: p,
                  detalle: i == 0
                      ? 'Sale en la próxima pregunta del día'
                      : 'Turno ${i + 1}',
                  propia: p.autor?.uid == yo,
                  onBorrar: () => _borrar(p),
                ),
              if (usadas.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Ya salieron', style: textTheme.titleSmall),
                for (final p in usadas)
                  _TarjetaPropuesta(
                    propuesta: p,
                    detalle: 'Salió el ${fechaLegible(_clave(p.usadaEn!))}',
                    propia: p.autor?.uid == yo,
                    onBorrar: () => _borrar(p),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }

  static String _clave(DateTime f) => claveDia(f);
}

/// Cuántas preguntas trae la app.
int bancoTamano() => bancoPreguntas.length;

class _TarjetaPropuesta extends StatelessWidget {
  const _TarjetaPropuesta({
    required this.propuesta,
    required this.detalle,
    required this.propia,
    required this.onBorrar,
  });

  final PreguntaPropuesta propuesta;
  final String detalle;
  final bool propia;
  final VoidCallback onBorrar;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final autor = propuesta.autor;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        visualDensity: VisualDensity.compact,
        leading: autor == null
            ? const Text('💡', style: TextStyle(fontSize: 22))
            : AvatarAutor(autor: autor, radio: 14),
        title: Text(propuesta.texto),
        subtitle: Text(
          '${autor == null ? '' : 'De ${autor.nombreCorto} · '}$detalle',
          style: textTheme.bodySmall,
        ),
        trailing: propia
            ? IconButton(
                tooltip: 'Borrar',
                icon: const Icon(Icons.delete_outline),
                onPressed: onBorrar,
              )
            : null,
      ),
    );
  }
}

class _DialogoProponer extends StatefulWidget {
  const _DialogoProponer();

  @override
  State<_DialogoProponer> createState() => _DialogoProponerState();
}

class _DialogoProponerState extends State<_DialogoProponer> {
  final _texto = TextEditingController();

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final valida =
        _texto.text.trim().length >= minCaracteresPropuesta &&
        _texto.text.trim().length <= maxCaracteresPropuesta;
    return AlertDialog(
      title: const Text('💡 Proponer pregunta'),
      content: TextField(
        key: const Key('campo-propuesta'),
        controller: _texto,
        autofocus: true,
        minLines: 2,
        maxLines: 4,
        maxLength: maxCaracteresPropuesta,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          hintText: '¿Cuál es tu lugar favorito para estar juntos?',
        ),
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('boton-proponer'),
          onPressed: valida
              ? () => Navigator.pop(context, _texto.text.trim())
              : null,
          child: const Text('Agregar'),
        ),
      ],
    );
  }
}
