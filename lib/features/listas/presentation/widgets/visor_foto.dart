import 'package:flutter/material.dart';

import '../../domain/item_lista.dart';
import 'tarjeta_item.dart' show fechaCorta;

/// Pregunta antes de borrar una foto.
Future<bool> confirmarBorrarFoto(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('¿Borrar esta foto?'),
      content: const Text('Se borrará para los dos y no se puede deshacer.'),
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
  return ok ?? false;
}

/// Abre las fotos a pantalla completa, empezando por la [inicial].
Future<void> abrirVisorFotos(
  BuildContext context, {
  required List<FotoItem> fotos,
  required int inicial,
  required Future<void> Function(FotoItem foto) onBorrar,
}) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) =>
        VisorFoto(fotos: fotos, inicial: inicial, onBorrar: onBorrar),
  ),
);

/// Visor a pantalla completa: fondo negro, zoom con los dedos y deslizar
/// para pasar de una foto a otra.
class VisorFoto extends StatefulWidget {
  const VisorFoto({
    super.key,
    required this.fotos,
    required this.onBorrar,
    this.inicial = 0,
  });

  final List<FotoItem> fotos;
  final int inicial;
  final Future<void> Function(FotoItem foto) onBorrar;

  @override
  State<VisorFoto> createState() => _VisorFotoState();
}

class _VisorFotoState extends State<VisorFoto> {
  late final _fotos = [...widget.fotos];
  late final _paginas = PageController(initialPage: widget.inicial);
  late var _actual = widget.inicial;

  @override
  void dispose() {
    _paginas.dispose();
    super.dispose();
  }

  Future<void> _borrarActual() async {
    final foto = _fotos[_actual];
    if (!await confirmarBorrarFoto(context)) return;
    await widget.onBorrar(foto);
    if (!mounted) return;
    if (_fotos.length == 1) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _fotos.removeAt(_actual);
      if (_actual >= _fotos.length) _actual = _fotos.length - 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final foto = _fotos[_actual];
    final autor = foto.autor?.nombreCorto;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '${_actual + 1} de ${_fotos.length}',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          IconButton(
            tooltip: 'Borrar foto',
            icon: const Icon(Icons.delete_outline),
            onPressed: _borrarActual,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _paginas,
              itemCount: _fotos.length,
              onPageChanged: (i) => setState(() => _actual = i),
              itemBuilder: (context, i) => InteractiveViewer(
                maxScale: 5,
                child: Center(
                  child: Hero(
                    tag: 'foto-${_fotos[i].id}',
                    child: Image.memory(
                      _fotos[i].bytes,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.broken_image,
                        color: Colors.white54,
                        size: 48,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                '${autor == null ? 'Agregada' : 'Agregada por $autor'}'
                ' el ${fechaCorta(foto.creadoEn)}',
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
