import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../core/widgets/paw_background.dart';
import '../domain/editor_estado.dart';
import 'exportar_composicion.dart';
import 'widgets/marco_foto.dart';
import 'widgets/sticker_vista.dart';

/// Editor para decorar una foto con marcos y stickers de michi.
///
/// Al tocar "Listo" hace `pop` con la ruta del PNG decorado; al cancelar,
/// hace `pop` con `null`.
class EditorFotoPage extends StatefulWidget {
  const EditorFotoPage({super.key, required this.fotoPath, this.dirSalida});

  final String fotoPath;

  /// Carpeta donde guardar el resultado. Por defecto, la temporal del sistema.
  final Future<Directory> Function()? dirSalida;

  @override
  State<EditorFotoPage> createState() => _EditorFotoPageState();
}

class _EditorFotoPageState extends State<EditorFotoPage> {
  /// Lado de un sticker con escala 1, como fracción del ancho del lienzo.
  static const double _ladoBase = 0.22;

  final _estado = EditorEstado();
  final _lienzoKey = GlobalKey();
  bool _exportando = false;

  double _escalaInicial = 1;
  double _rotacionInicial = 0;

  @override
  void dispose() {
    _estado.dispose();
    super.dispose();
  }

  Future<void> _listo() async {
    if (_exportando) return;
    setState(() => _exportando = true);
    try {
      final lienzo =
          _lienzoKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final dir =
          await (widget.dirSalida?.call() ??
              Future.value(Directory.systemTemp));
      final path = await exportarComposicion(lienzo, dir);
      if (mounted) Navigator.of(context).pop(path);
    } catch (_) {
      if (!mounted) return;
      setState(() => _exportando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar la foto decorada 😿')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _estado,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Cancelar',
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text('Decorar ✨'),
          actions: [
            IconButton(
              icon: const Icon(Icons.undo),
              tooltip: 'Deshacer',
              onPressed: _estado.puedeDeshacer ? _estado.deshacer : null,
            ),
            IconButton(
              icon: const Icon(Icons.layers_clear),
              tooltip: 'Limpiar',
              onPressed: _estado.estaVacio ? null : _estado.limpiar,
            ),
          ],
        ),
        body: PawBackground(
          child: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Center(
                      child: AspectRatio(aspectRatio: 3 / 4, child: _lienzo()),
                    ),
                  ),
                ),
                _barraSeleccion(),
                _selectorMarcos(),
                _bandejaStickers(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const ValueKey('editor-listo'),
                      onPressed: _exportando ? null : _listo,
                      icon: _exportando
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check),
                      label: const Text('Listo'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _lienzo() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tamano = constraints.biggest;
        final seleccionado = _estado.seleccionado;
        return Stack(
          children: [
            RepaintBoundary(
              key: _lienzoKey,
              child: ClipRect(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _estado.seleccionar(null),
                        child: MarcoFoto(
                          marco: _estado.marco,
                          foto: _Foto(path: widget.fotoPath),
                        ),
                      ),
                    ),
                    for (final s in _estado.stickers)
                      _posicionar(
                        s,
                        tamano,
                        GestureDetector(
                          key: ValueKey('sticker-${s.id}'),
                          onTap: () => _estado.seleccionar(s.id),
                          onLongPress: () => _estado.eliminar(s.id),
                          onScaleStart: (_) {
                            _escalaInicial = s.escala;
                            _rotacionInicial = s.rotacion;
                            _estado.comenzarGesto(s.id);
                          },
                          onScaleUpdate: (d) {
                            _estado.mover(
                              s.id,
                              Offset(
                                d.focalPointDelta.dx / tamano.width,
                                d.focalPointDelta.dy / tamano.height,
                              ),
                            );
                            _estado.transformar(
                              s.id,
                              escala: _escalaInicial * d.scale,
                              rotacion: _rotacionInicial + d.rotation,
                            );
                          },
                          onScaleEnd: (_) => _estado.terminarGesto(),
                          child: StickerVista(
                            sticker: s.sticker,
                            lado: _lado(s, tamano),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // El recuadro de selección queda fuera del RepaintBoundary para
            // que no aparezca en la imagen exportada.
            if (seleccionado != null)
              _posicionar(
                seleccionado,
                tamano,
                IgnorePointer(
                  child: Container(
                    key: const ValueKey('seleccion-sticker'),
                    width: _lado(seleccionado, tamano) + 8,
                    height: _lado(seleccionado, tamano) + 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 4),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  double _lado(StickerColocado s, Size tamano) =>
      tamano.width * _ladoBase * s.escala;

  Widget _posicionar(StickerColocado s, Size tamano, Widget hijo) {
    return Positioned(
      key: ValueKey('pos-${s.id}'),
      left: s.posicion.dx * tamano.width,
      top: s.posicion.dy * tamano.height,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: Transform.rotate(angle: s.rotacion, child: hijo),
      ),
    );
  }

  Widget _barraSeleccion() {
    final seleccionado = _estado.seleccionado;
    return AnimatedSize(
      duration: const Duration(milliseconds: 150),
      child: seleccionado == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Arrastra, pellizca o gira el sticker 🐾',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  TextButton.icon(
                    key: const ValueKey('quitar-sticker'),
                    onPressed: () => _estado.eliminar(seleccionado.id),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Quitar'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _selectorMarcos() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          for (final m in Marco.values)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                key: ValueKey('chip-marco-${m.name}'),
                label: Text('${m.emoji} ${m.etiqueta}'),
                selected: _estado.marco == m,
                onSelected: (_) => _estado.cambiarMarco(m),
              ),
            ),
        ],
      ),
    );
  }

  Widget _bandejaStickers() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 72,
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      decoration: BoxDecoration(
        color: scheme.secondary.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(24),
      ),
      child: ListView(
        key: const ValueKey('bandeja-stickers'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          for (final sticker in StickersMichi.catalogo)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: InkResponse(
                key: ValueKey('bandeja-$sticker'),
                radius: 30,
                onTap: () => _estado.agregar(sticker),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: StickerVista(sticker: sticker, lado: 44),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Foto a pantalla completa, con un michi de respaldo si no carga.
class _Foto extends StatelessWidget {
  const _Foto({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      cacheWidth: 1440,
      errorBuilder: (context, error, stack) => ColoredBox(
        color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
        child: const Center(child: Text('🐱', style: TextStyle(fontSize: 64))),
      ),
    );
  }
}
