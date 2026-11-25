import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../config_scope.dart';
import '../../domain/item_lista.dart';
import 'comprimir_foto.dart';
import 'visor_foto.dart';

/// Sección "Recuerdos" en el detalle del elemento: cuadrícula de fotos
/// guardadas en Firestore y botón para agregar más.
class SeccionFotos extends StatefulWidget {
  const SeccionFotos({
    super.key,
    required this.tipo,
    required this.item,
    required this.repository,
    this.selector,
    this.reductor,
  });

  final TipoLista tipo;
  final ItemLista item;
  final ListaRepository repository;

  /// Cómo se eligen las fotos; si es null se usa [selectorPorDefecto].
  final SelectorBytes? selector;

  /// Cómo se reducen las fotos pesadas; si es null se usa [reducirFoto].
  final ReductorFoto? reductor;

  /// Selector global (las pruebas lo reemplazan para no usar la cámara).
  static SelectorBytes selectorPorDefecto = seleccionarConImagePicker;

  @override
  State<SeccionFotos> createState() => _SeccionFotosState();
}

class _SeccionFotosState extends State<SeccionFotos> {
  late Stream<List<FotoItem>> _fotos = _escuchar();
  var _guardando = false;

  Stream<List<FotoItem>> _escuchar() =>
      widget.repository.watchFotos(widget.tipo, widget.item.id);

  @override
  void didUpdateWidget(SeccionFotos oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id ||
        oldWidget.repository != widget.repository) {
      _fotos = _escuchar();
    }
  }

  void _aviso(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _agregar() async {
    final origen = kIsWeb
        ? ImageSource.gallery
        : await showModalBottomSheet<ImageSource>(
            context: context,
            showDragHandle: true,
            builder: (context) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.photo_camera),
                    title: const Text('Cámara'),
                    onTap: () => Navigator.pop(context, ImageSource.camera),
                  ),
                  ListTile(
                    leading: const Icon(Icons.photo_library),
                    title: const Text('Galería'),
                    onTap: () => Navigator.pop(context, ImageSource.gallery),
                  ),
                ],
              ),
            ),
          );
    if (origen == null || !mounted) return;

    setState(() => _guardando = true);
    try {
      final selector = widget.selector ?? SeccionFotos.selectorPorDefecto;
      final elegida = await selector(origen);
      if (elegida == null) return;
      final bytes = await (widget.reductor ?? reducirFoto)(elegida);
      if (bytes == null || bytes.length > maxBytesFoto) {
        _aviso('La foto es muy pesada');
        return;
      }
      await widget.repository.agregarFoto(widget.tipo, widget.item.id, bytes);
    } catch (e) {
      _aviso('No se pudo guardar la foto: $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ConfigClubScope.of(context).fotos) return const SizedBox.shrink();
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
        child: StreamBuilder<List<FotoItem>>(
          stream: _fotos,
          builder: (context, snap) {
            final fotos = snap.data ?? const <FotoItem>[];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Recuerdos 📷', style: textTheme.titleMedium),
                    ),
                    if (_guardando)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else
                      TextButton.icon(
                        key: const Key('boton-agregar-foto'),
                        onPressed: _agregar,
                        icon: const Icon(Icons.add_a_photo_outlined),
                        label: const Text('Agregar foto'),
                      ),
                  ],
                ),
                if (fotos.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, right: 8),
                    child: Text(
                      snap.hasError
                          ? 'No se pudieron cargar las fotos.'
                          : 'Aún no hay fotos de este recuerdo.',
                      style: textTheme.bodySmall,
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(top: 4, right: 8),
                    child: _Cuadricula(
                      fotos: fotos,
                      onAbrir: (i) => abrirVisorFotos(
                        context,
                        fotos: fotos,
                        inicial: i,
                        onBorrar: _borrar,
                      ),
                      onBorrar: (foto) async {
                        if (await confirmarBorrarFoto(context)) {
                          await _borrar(foto);
                        }
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _borrar(FotoItem foto) async {
    try {
      await widget.repository.borrarFoto(widget.tipo, widget.item.id, foto.id);
    } catch (e) {
      _aviso('No se pudo borrar la foto: $e');
    }
  }
}

class _Cuadricula extends StatelessWidget {
  const _Cuadricula({
    required this.fotos,
    required this.onAbrir,
    required this.onBorrar,
  });

  final List<FotoItem> fotos;
  final void Function(int indice) onAbrir;
  final void Function(FotoItem foto) onBorrar;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, restricciones) {
        // Decodifica las miniaturas al tamaño en pantalla, no a 1600 px.
        final lado = restricciones.maxWidth / 3;
        final cache = (lado * MediaQuery.devicePixelRatioOf(context)).ceil();
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
          ),
          itemCount: fotos.length,
          itemBuilder: (context, i) {
            final foto = fotos[i];
            return ClipRRect(
              key: ValueKey('miniatura-${foto.id}'),
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: () => onAbrir(i),
                onLongPress: () => onBorrar(foto),
                child: Hero(
                  tag: 'foto-${foto.id}',
                  child: Image.memory(
                    foto.bytes,
                    fit: BoxFit.cover,
                    cacheWidth: cache,
                    gaplessPlayback: true,
                    errorBuilder: (_, _, _) =>
                        const Center(child: Icon(Icons.broken_image)),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
