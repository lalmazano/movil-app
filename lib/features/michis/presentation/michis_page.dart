import 'package:flutter/material.dart';

import '../../../core/widgets/paw_background.dart';
import '../../recuerdos/domain/recuerdo.dart';
import '../domain/michi.dart';
import 'michi_form_page.dart';
import 'michi_perfil_page.dart';
import 'widgets/michi_avatar.dart';
import 'widgets/michi_textos.dart';

/// Lista de los michis de la casa.
class MichisPage extends StatefulWidget {
  const MichisPage({
    super.key,
    required this.repository,
    required this.recuerdoRepository,
    this.selectorFoto = selectorFotoMichiPorDefecto,
    this.hoy,
  });

  final MichiRepository repository;
  final RecuerdoRepository recuerdoRepository;
  final SelectorFotoMichi selectorFoto;

  /// Fecha de hoy (para pruebas). Por defecto `DateTime.now()`.
  final DateTime? hoy;

  @override
  State<MichisPage> createState() => _MichisPageState();
}

class _MichisPageState extends State<MichisPage> {
  List<Michi>? _michis;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    List<Michi> michis;
    try {
      michis = await widget.repository.getAll();
    } catch (_) {
      michis = [];
    }
    if (mounted) setState(() => _michis = michis);
  }

  Future<void> _nuevo() async {
    final creado = await Navigator.of(context).push<Michi>(
      MaterialPageRoute(
        builder: (_) => MichiFormPage(
          repository: widget.repository,
          selectorFoto: widget.selectorFoto,
        ),
      ),
    );
    if (creado == null) return;
    await _cargar();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡Bienvenido a la familia, ${creado.nombre}! 😻'),
        ),
      );
    }
  }

  Future<void> _abrir(Michi michi) async {
    final cambio = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MichiPerfilPage(
          michi: michi,
          repository: widget.repository,
          recuerdoRepository: widget.recuerdoRepository,
          selectorFoto: widget.selectorFoto,
          hoy: widget.hoy,
        ),
      ),
    );
    if (cambio == true) await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🐾 Mis michis')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _nuevo,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo michi'),
      ),
      body: PawBackground(child: _contenido(context)),
    );
  }

  Widget _contenido(BuildContext context) {
    final michis = _michis;
    if (michis == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (michis.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            '🐱\nAún no hay michis registrados.\n¡Agrega al primero!',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      );
    }
    final hoy = widget.hoy ?? DateTime.now();
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: michis.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final michi = michis[i];
        final detalles = [
          if (michi.raza.isNotEmpty) michi.raza,
          ?describirEdad(michi, hoy),
        ];
        return Card(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: MichiAvatar.de(michi, radius: 28),
            title: Text(
              michi.esCumpleanos(hoy) ? '${michi.nombre} 🎂' : michi.nombre,
            ),
            subtitle: detalles.isEmpty ? null : Text(detalles.join(' · ')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _abrir(michi),
          ),
        );
      },
    );
  }
}
