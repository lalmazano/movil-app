import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../domain/michi.dart';
import 'widgets/michi_avatar.dart';
import 'widgets/michi_textos.dart';

/// Elige una foto de perfil y devuelve su ruta (o null si se canceló).
typedef SelectorFotoMichi = Future<String?> Function(ImageSource origen);

Future<String?> selectorFotoMichiPorDefecto(ImageSource origen) async {
  final foto = await ImagePicker().pickImage(
    source: origen,
    maxWidth: 1024,
    imageQuality: 85,
  );
  return foto?.path;
}

/// Crear un michi nuevo o editar uno existente ([michi] no nulo).
///
/// Al guardar cierra devolviendo el `Michi` guardado.
class MichiFormPage extends StatefulWidget {
  const MichiFormPage({
    super.key,
    required this.repository,
    this.michi,
    this.selectorFoto = selectorFotoMichiPorDefecto,
  });

  final MichiRepository repository;
  final Michi? michi;
  final SelectorFotoMichi selectorFoto;

  @override
  State<MichiFormPage> createState() => _MichiFormPageState();
}

class _MichiFormPageState extends State<MichiFormPage> {
  final _form = GlobalKey<FormState>();
  late final _nombre = TextEditingController(text: widget.michi?.nombre);
  late final _raza = TextEditingController(text: widget.michi?.raza);
  late DateTime? _nacimiento = widget.michi?.nacimiento;
  late String _emoji = widget.michi?.emoji ?? emojisMichi.first;
  String? _fotoNueva;
  bool _guardando = false;

  bool get _editando => widget.michi != null;

  @override
  void dispose() {
    _nombre.dispose();
    _raza.dispose();
    super.dispose();
  }

  void _aviso(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _elegirFoto() async {
    final origen = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (origen == null || !mounted) return;
    try {
      final path = await widget.selectorFoto(origen);
      if (path != null && mounted) setState(() => _fotoNueva = path);
    } catch (_) {
      _aviso('No se pudo abrir la cámara. Revisa los permisos 😿');
    }
  }

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final fecha = await showDatePicker(
      context: context,
      initialDate: _nacimiento ?? DateTime(hoy.year - 1, hoy.month, hoy.day),
      firstDate: DateTime(1990),
      lastDate: hoy,
      helpText: '¿Cuándo nació?',
    );
    if (fecha != null) setState(() => _nacimiento = fecha);
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _guardando = true);
    final nombre = _nombre.text.trim();
    final raza = _raza.text.trim();
    try {
      final michi = widget.michi;
      final guardado = michi == null
          ? await widget.repository.add(
              nombre: nombre,
              fotoOrigen: _fotoNueva,
              nacimiento: _nacimiento,
              raza: raza,
              emoji: _emoji,
            )
          : await widget.repository.update(
              michi.copyWith(
                nombre: nombre,
                raza: raza,
                emoji: _emoji,
                nacimiento: () => _nacimiento,
              ),
              fotoOrigen: _fotoNueva,
            );
      if (mounted) Navigator.of(context).pop(guardado);
    } catch (_) {
      if (!mounted) return;
      setState(() => _guardando = false);
      _aviso('No se pudo guardar al michi 😿');
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final nacimiento = _nacimiento;
    return Scaffold(
      appBar: AppBar(title: Text(_editando ? 'Editar michi' : 'Nuevo michi')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Stack(
                children: [
                  MichiAvatar(
                    fotoPath: _fotoNueva ?? widget.michi?.fotoPath,
                    emoji: _emoji,
                    radius: 64,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: IconButton.filled(
                      tooltip: 'Cambiar foto',
                      onPressed: _elegirFoto,
                      icon: const Icon(Icons.add_a_photo),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _nombre,
              textCapitalization: TextCapitalization.words,
              maxLength: 30,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                hintText: 'Ej. Pelusa',
                prefixIcon: Icon(Icons.pets),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? '¿Cómo se llama tu michi? 🐾'
                  : null,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _raza,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Raza (opcional)',
                hintText: 'Ej. Siamés, criollo...',
                prefixIcon: Icon(Icons.category_outlined),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.cake_outlined),
                title: const Text('Fecha de nacimiento'),
                subtitle: Text(
                  nacimiento == null ? 'Sin indicar' : formatearDia(nacimiento),
                ),
                onTap: _elegirFecha,
                trailing: nacimiento == null
                    ? null
                    : IconButton(
                        tooltip: 'Quitar fecha',
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => _nacimiento = null),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Su emoji', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in emojisMichi)
                  ChoiceChip(
                    label: Text(e, style: const TextStyle(fontSize: 24)),
                    selected: e == _emoji,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _emoji = e),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _guardando ? null : _guardar,
              icon: _guardando
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.favorite),
              label: Text(_editando ? 'Guardar cambios' : 'Guardar michi'),
            ),
          ],
        ),
      ),
    );
  }
}
