import 'package:flutter/material.dart';

import '../../../core/widgets/paw_background.dart';
import '../../recuerdos/domain/recuerdo.dart';
import '../domain/michi.dart';
import 'michi_form_page.dart';
import 'widgets/michi_avatar.dart';
import 'widgets/michi_textos.dart';

/// Perfil de un michi: edad, recuerdos juntos, editar y borrar.
///
/// Al cerrar devuelve `true` si hubo cambios.
class MichiPerfilPage extends StatefulWidget {
  const MichiPerfilPage({
    super.key,
    required this.michi,
    required this.repository,
    required this.recuerdoRepository,
    this.selectorFoto = selectorFotoMichiPorDefecto,
    this.hoy,
  });

  final Michi michi;
  final MichiRepository repository;
  final RecuerdoRepository recuerdoRepository;
  final SelectorFotoMichi selectorFoto;

  /// Fecha de hoy (para pruebas). Por defecto `DateTime.now()`.
  final DateTime? hoy;

  @override
  State<MichiPerfilPage> createState() => _MichiPerfilPageState();
}

class _MichiPerfilPageState extends State<MichiPerfilPage> {
  late Michi _michi = widget.michi;
  int? _recuerdos;
  bool _cambio = false;

  @override
  void initState() {
    super.initState();
    _contarRecuerdos();
  }

  Future<void> _contarRecuerdos() async {
    try {
      final todos = await widget.recuerdoRepository.getAll();
      final n = todos.where((r) => r.michiId == _michi.id).length;
      if (mounted) setState(() => _recuerdos = n);
    } catch (_) {
      if (mounted) setState(() => _recuerdos = 0);
    }
  }

  Future<void> _editar() async {
    final editado = await Navigator.of(context).push<Michi>(
      MaterialPageRoute(
        builder: (_) => MichiFormPage(
          repository: widget.repository,
          michi: _michi,
          selectorFoto: widget.selectorFoto,
        ),
      ),
    );
    if (editado != null && mounted) {
      setState(() {
        _michi = editado;
        _cambio = true;
      });
    }
  }

  Future<void> _borrar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿Borrar a ${_michi.nombre}? 🙀'),
        content: const Text(
          'Se borrará su perfil. Sus recuerdos se conservan, pero sin etiqueta.',
        ),
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
    if (confirmar != true) return;
    await widget.repository.delete(_michi.id);
    // Quitar la etiqueta de los recuerdos donde salía.
    try {
      final recuerdos = await widget.recuerdoRepository.getAll();
      for (final r in recuerdos.where((r) => r.michiId == _michi.id)) {
        await widget.recuerdoRepository.update(r.copyWith(michiId: () => null));
      }
    } catch (_) {
      // Si falla, los recuerdos quedan con una etiqueta que ya no se muestra.
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hoy = widget.hoy ?? DateTime.now();
    final edad = describirEdad(_michi, hoy);
    final nacimiento = _michi.nacimiento;
    final recuerdos = _recuerdos;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_cambio);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_michi.nombre),
          actions: [
            IconButton(
              tooltip: 'Editar',
              icon: const Icon(Icons.edit),
              onPressed: _editar,
            ),
            IconButton(
              tooltip: 'Borrar',
              icon: const Icon(Icons.delete_outline),
              onPressed: _borrar,
            ),
          ],
        ),
        body: PawBackground(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Center(child: MichiAvatar.de(_michi, radius: 72)),
              const SizedBox(height: 16),
              Text(
                '${_michi.nombre} ${_michi.emoji}',
                textAlign: TextAlign.center,
                style: textTheme.headlineMedium,
              ),
              if (_michi.raza.isNotEmpty)
                Text(
                  _michi.raza,
                  textAlign: TextAlign.center,
                  style: textTheme.titleMedium,
                ),
              if (_michi.esCumpleanos(hoy)) ...[
                const SizedBox(height: 12),
                Text(
                  '🎂 ¡Hoy es su cumpleaños! 🎉',
                  textAlign: TextAlign.center,
                  style: textTheme.titleLarge,
                ),
              ],
              const SizedBox(height: 24),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.cake_outlined),
                      title: Text(edad ?? 'Edad desconocida'),
                      subtitle: Text(
                        nacimiento == null
                            ? 'Agrega su fecha de nacimiento'
                            : 'Nació el ${formatearDia(nacimiento)}',
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.photo_library_outlined),
                      title: Text(
                        recuerdos == null
                            ? 'Contando recuerdos...'
                            : recuerdos == 1
                            ? '1 recuerdo juntos'
                            : '$recuerdos recuerdos juntos',
                      ),
                      subtitle: const Text('Fotos donde sale este michi 📸'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
