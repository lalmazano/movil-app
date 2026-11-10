import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/widgets/paw_background.dart';
import '../domain/recuerdo.dart';
import 'nuevo_recuerdo_page.dart';
import 'recuerdo_detalle_page.dart';
import 'widgets/calificacion_huellitas.dart';
import 'widgets/foto_recuerdo.dart';

/// Elige una foto y devuelve su ruta (o null si se canceló).
typedef SelectorFoto = Future<String?> Function(
  ImageSource origen,
  CameraDevice camara,
);

Future<String?> _selectorPorDefecto(
  ImageSource origen,
  CameraDevice camara,
) async {
  final foto = await ImagePicker().pickImage(
    source: origen,
    preferredCameraDevice: camara,
    maxWidth: 2048,
    imageQuality: 85,
  );
  return foto?.path;
}

/// Galería de fotos con el michi.
class RecuerdosPage extends StatefulWidget {
  const RecuerdosPage({
    super.key,
    required this.repository,
    this.selectorFoto = _selectorPorDefecto,
  });

  final RecuerdoRepository repository;
  final SelectorFoto selectorFoto;

  @override
  State<RecuerdosPage> createState() => _RecuerdosPageState();
}

class _RecuerdosPageState extends State<RecuerdosPage> {
  List<Recuerdo>? _recuerdos;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final recuerdos = await widget.repository.getAll();
    if (mounted) setState(() => _recuerdos = recuerdos);
  }

  Future<void> _nuevaFoto() async {
    final opcion = await showModalBottomSheet<(ImageSource, CameraDevice)>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_front),
              title: const Text('Selfie con mi michi'),
              onTap: () => Navigator.pop(context, (
                ImageSource.camera,
                CameraDevice.front,
              )),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Cámara trasera'),
              onTap: () => Navigator.pop(context, (
                ImageSource.camera,
                CameraDevice.rear,
              )),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.pop(context, (
                ImageSource.gallery,
                CameraDevice.rear,
              )),
            ),
          ],
        ),
      ),
    );
    if (opcion == null || !mounted) return;

    String? path;
    try {
      path = await widget.selectorFoto(opcion.$1, opcion.$2);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir la cámara. Revisa los permisos 😿'),
        ),
      );
      return;
    }
    if (path == null || !mounted) return;

    final guardado = await Navigator.of(context).push<Recuerdo>(
      MaterialPageRoute(
        builder: (_) =>
            NuevoRecuerdoPage(fotoPath: path!, repository: widget.repository),
      ),
    );
    if (guardado != null) {
      await _cargar();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('¡Recuerdo guardado! 😻')));
      }
    }
  }

  Future<void> _abrir(Recuerdo recuerdo) async {
    final cambio = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RecuerdoDetallePage(
          recuerdo: recuerdo,
          repository: widget.repository,
        ),
      ),
    );
    if (cambio == true) await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('📸 Mis recuerdos michi')),
      floatingActionButton: kIsWeb
          ? null
          : FloatingActionButton.extended(
              onPressed: _nuevaFoto,
              icon: const Icon(Icons.add_a_photo),
              label: const Text('Tomar foto'),
            ),
      body: PawBackground(child: _contenido(context)),
    );
  }

  Widget _contenido(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    if (kIsWeb) {
      return const _Mensaje(
        emoji: '📱',
        texto: 'Los recuerdos están disponibles en la app de Android e iOS.',
      );
    }
    final recuerdos = _recuerdos;
    if (recuerdos == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (recuerdos.isEmpty) {
      return const _Mensaje(
        emoji: '📸🐱',
        texto: 'Aún no hay recuerdos.\n¡Tómate una foto con tu michi!',
      );
    }
    final promedio =
        recuerdos.map((r) => r.calificacion).reduce((a, b) => a + b) /
        recuerdos.length;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          sliver: SliverToBoxAdapter(
            child: Text(
              '${recuerdos.length} '
              '${recuerdos.length == 1 ? 'recuerdo' : 'recuerdos'} · '
              'promedio ${promedio.toStringAsFixed(1)} 🐾',
              textAlign: TextAlign.center,
              style: textTheme.titleMedium,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.72,
            ),
            itemCount: recuerdos.length,
            itemBuilder: (context, i) => _TarjetaRecuerdo(
              recuerdo: recuerdos[i],
              onTap: () => _abrir(recuerdos[i]),
            ),
          ),
        ),
      ],
    );
  }
}

class _TarjetaRecuerdo extends StatelessWidget {
  const _TarjetaRecuerdo({required this.recuerdo, required this.onTap});

  final Recuerdo recuerdo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: FotoRecuerdo(path: recuerdo.imagePath)),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
              child: Column(
                children: [
                  CalificacionHuellitas(
                    valor: recuerdo.calificacion,
                    tamano: 18,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    recuerdo.nota.isEmpty
                        ? formatearFecha(recuerdo.fecha)
                        : recuerdo.nota,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Mensaje extends StatelessWidget {
  const _Mensaje({required this.emoji, required this.texto});

  final String emoji;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 12),
            Text(
              texto,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}
