import 'package:flutter/material.dart';

import '../../../core/widgets/paw_background.dart';
import '../../michis/domain/michi.dart';
import '../domain/registro_peso.dart';
import 'widgets/grafica_peso.dart';
import 'widgets/nuevo_peso_dialog.dart';

/// Formato corto dd/MM/aaaa.
String formatearDia(DateTime f) {
  String dos(int n) => n.toString().padLeft(2, '0');
  return '${dos(f.day)}/${dos(f.month)}/${f.year}';
}

/// Control de peso de cada michi: gráfica, último pesaje y lista.
class PesoPage extends StatefulWidget {
  const PesoPage({
    super.key,
    required this.michis,
    required this.pesos,
    this.ahora = DateTime.now,
  });

  final MichiRepository michis;
  final PesoRepository pesos;
  final DateTime Function() ahora;

  @override
  State<PesoPage> createState() => _PesoPageState();
}

class _PesoPageState extends State<PesoPage> {
  List<Michi>? _michis;
  String? _seleccionado;
  List<RegistroPeso> _registros = const [];

  @override
  void initState() {
    super.initState();
    _cargarMichis();
  }

  Future<void> _cargarMichis() async {
    final michis = await widget.michis.getAll();
    if (!mounted) return;
    setState(() {
      _michis = michis;
      _seleccionado = michis.firstOrNull?.id;
    });
    await _cargarRegistros();
  }

  Future<void> _cargarRegistros() async {
    final id = _seleccionado;
    final registros = id == null
        ? <RegistroPeso>[]
        : await widget.pesos.deMichi(id);
    if (mounted && id == _seleccionado) {
      setState(() => _registros = ordenarPorFecha(registros));
    }
  }

  void _elegir(String id) {
    setState(() {
      _seleccionado = id;
      _registros = const [];
    });
    _cargarRegistros();
  }

  Future<void> _agregar() async {
    final id = _seleccionado;
    if (id == null) return;
    final nuevo = await showDialog<NuevoPeso>(
      context: context,
      builder: (_) => NuevoPesoDialog(hoy: widget.ahora()),
    );
    if (nuevo == null) return;
    await widget.pesos.add(
      michiId: id,
      fecha: nuevo.fecha,
      kg: nuevo.kg,
      nota: nuevo.nota,
    );
    await _cargarRegistros();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('¡Peso registrado! ⚖️😺')));
    }
  }

  Future<void> _borrar(RegistroPeso registro) async {
    await widget.pesos.delete(registro.id);
    await _cargarRegistros();
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Registro borrado 🧹')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final hayMichi = _seleccionado != null;
    return Scaffold(
      appBar: AppBar(title: const Text('⚖️ Control de peso')),
      floatingActionButton: hayMichi
          ? FloatingActionButton.extended(
              onPressed: _agregar,
              icon: const Icon(Icons.add),
              label: const Text('Registrar peso'),
            )
          : null,
      body: PawBackground(child: _contenido(context)),
    );
  }

  Widget _contenido(BuildContext context) {
    final michis = _michis;
    if (michis == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (michis.isEmpty) {
      return const _Mensaje(
        emoji: '🐱❓',
        texto:
            'Aún no tienes michis registrados.\n'
            'Crea uno en "Mis michis" para empezar a pesarlo.',
      );
    }
    final textTheme = Theme.of(context).textTheme;
    final cambio = calcularCambioPeso(_registros);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final m in michis)
              ChoiceChip(
                label: Text('${m.emoji} ${m.nombre}'),
                selected: m.id == _seleccionado,
                onSelected: (_) => _elegir(m.id),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (cambio == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: _Mensaje(
              emoji: '⚖️🐾',
              texto: 'Sin pesajes todavía.\n¡Sube a tu michi a la báscula!',
            ),
          )
        else ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text('Último peso', style: textTheme.labelLarge),
                  Text(
                    '${cambio.ultimo.kg.toStringAsFixed(2)} kg',
                    style: textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(formatearDia(cambio.ultimo.fecha)),
                  if (cambio.descripcion case final d?) ...[
                    const SizedBox(height: 4),
                    Text('$d vs. anterior', style: textTheme.titleMedium),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 20, 20, 8),
              child: SizedBox(
                height: 220,
                child: GraficaPeso(registros: _registros),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text('Historial', style: textTheme.titleMedium),
          for (final r in _registros.reversed)
            Card(
              child: ListTile(
                leading: const Text('🐾', style: TextStyle(fontSize: 24)),
                title: Text('${r.kg.toStringAsFixed(2)} kg'),
                subtitle: Text(
                  r.nota.isEmpty
                      ? formatearDia(r.fecha)
                      : '${formatearDia(r.fecha)} · ${r.nota}',
                ),
                trailing: IconButton(
                  tooltip: 'Borrar registro',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _borrar(r),
                ),
              ),
            ),
        ],
      ],
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
            Text(emoji, style: const TextStyle(fontSize: 56)),
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
