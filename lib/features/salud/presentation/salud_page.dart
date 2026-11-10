import 'package:flutter/material.dart';

import '../../../core/widgets/paw_background.dart';
import '../../michis/domain/michi.dart';
import '../../recordatorios/domain/servicio_recordatorios.dart';
import '../../recordatorios/presentation/formato_fecha.dart';
import '../domain/entrada_salud.dart';
import 'entrada_salud_form_page.dart';

/// Diario de salud: visitas, vacunas, medicinas y notas de cada michi.
class SaludPage extends StatefulWidget {
  const SaludPage({
    super.key,
    required this.repository,
    required this.michis,
    this.recordatorios,
    this.reloj = DateTime.now,
  });

  final SaludRepository repository;
  final MichiRepository michis;

  /// Para el botón "Crear recordatorio" en vacunas (opcional).
  final ServicioRecordatorios? recordatorios;
  final DateTime Function() reloj;

  @override
  State<SaludPage> createState() => _SaludPageState();
}

class _SaludPageState extends State<SaludPage> {
  List<EntradaSalud>? _entradas;
  List<Michi> _michis = const [];
  String? _filtroMichi;
  TipoSalud? _filtroTipo;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final entradas = await widget.repository.getAll();
    List<Michi> michis;
    try {
      michis = await widget.michis.getAll();
    } catch (_) {
      michis = const [];
    }
    if (!mounted) return;
    setState(() {
      _entradas = entradas;
      _michis = michis;
      if (!michis.any((m) => m.id == _filtroMichi)) _filtroMichi = null;
    });
  }

  Future<void> _abrir([EntradaSalud? existente]) async {
    final cambio = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EntradaSaludFormPage(
          repository: widget.repository,
          michis: _michis,
          reloj: widget.reloj,
          existente: existente,
          michiInicial: _filtroMichi,
          recordatorios: widget.recordatorios,
        ),
      ),
    );
    if (cambio == true) await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🩺 Diario de salud')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrir(),
        icon: const Icon(Icons.add),
        label: const Text('Anotar'),
      ),
      body: PawBackground(child: _contenido(context)),
    );
  }

  Widget _contenido(BuildContext context) {
    final todas = _entradas;
    if (todas == null) return const Center(child: CircularProgressIndicator());
    final visibles = filtrarEntradas(
      todas,
      michiId: _filtroMichi,
      tipo: _filtroTipo,
    );
    final michis = {for (final m in _michis) m.id: m};
    final total = visibles.fold<double>(0, (s, e) => s + (e.costo ?? 0));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        if (_michis.isNotEmpty)
          DropdownButtonFormField<String?>(
            key: const ValueKey('filtro_michi'),
            initialValue: _filtroMichi,
            decoration: const InputDecoration(
              labelText: 'Michi',
              isDense: true,
            ),
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('🐾 Todos los michis'),
              ),
              for (final m in _michis)
                DropdownMenuItem(
                  value: m.id,
                  child: Text('${m.emoji} ${m.nombre}'),
                ),
            ],
            onChanged: (v) => setState(() => _filtroMichi = v),
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final t in TipoSalud.values)
              FilterChip(
                label: Text('${t.emoji} ${t.etiqueta}'),
                selected: _filtroTipo == t,
                onSelected: (v) => setState(() => _filtroTipo = v ? t : null),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (todas.isEmpty)
          const _Vacio(
            texto: 'El diario está vacío.\nAnota la primera visita o vacuna 🩺',
          )
        else if (visibles.isEmpty)
          const _Vacio(texto: 'Nada con ese filtro 🙀')
        else ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '${visibles.length} '
              '${visibles.length == 1 ? 'entrada' : 'entradas'}'
              '${total > 0 ? ' · gasto ${formatearCosto(total)}' : ''} 🐾',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          for (final e in visibles)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                onTap: () => _abrir(e),
                leading: CircleAvatar(
                  child: Text(
                    e.tipo.emoji,
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
                title: Text(e.titulo),
                subtitle: Text(
                  [
                    fechaCorta(e.fecha),
                    if (michis[e.michiId] case final m?)
                      '${m.emoji} ${m.nombre}',
                    if (e.notas.isNotEmpty) e.notas,
                  ].join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: e.costo == null
                    ? null
                    : Text(
                        '💰 ${formatearCosto(e.costo!)}',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
              ),
            ),
        ],
      ],
    );
  }
}

class _Vacio extends StatelessWidget {
  const _Vacio({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
    child: Column(
      children: [
        const Text('🩺🐱', style: TextStyle(fontSize: 56)),
        const SizedBox(height: 12),
        Text(
          texto,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    ),
  );
}
