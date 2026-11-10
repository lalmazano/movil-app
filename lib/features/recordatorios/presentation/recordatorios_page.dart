import 'package:flutter/material.dart';

import '../../../core/widgets/paw_background.dart';
import '../../michis/domain/michi.dart';
import '../domain/recordatorio.dart';
import '../domain/servicio_recordatorios.dart';
import 'formato_fecha.dart';
import 'recordatorio_form_page.dart';

/// Lista de recordatorios: próximos y pasados.
class RecordatoriosPage extends StatefulWidget {
  const RecordatoriosPage({super.key, required this.servicio});

  final ServicioRecordatorios servicio;

  @override
  State<RecordatoriosPage> createState() => _RecordatoriosPageState();
}

class _RecordatoriosPageState extends State<RecordatoriosPage> {
  List<Recordatorio>? _recordatorios;
  List<Michi> _michis = const [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final recordatorios = await widget.servicio.getAll();
    List<Michi> michis;
    try {
      michis = await widget.servicio.michis.getAll();
    } catch (_) {
      michis = const [];
    }
    if (mounted) {
      setState(() {
        _recordatorios = recordatorios;
        _michis = michis;
      });
    }
  }

  Future<void> _abrirFormulario([Recordatorio? existente]) async {
    final cambio = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RecordatorioFormPage(
          servicio: widget.servicio,
          michis: _michis,
          existente: existente,
        ),
      ),
    );
    if (cambio == true) {
      await _cargar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Listo! Tu michi te lo agradece 😻')),
        );
      }
    }
  }

  Future<void> _alternar(Recordatorio r, bool activo) async {
    await widget.servicio.alternar(r, activo);
    await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('⏰ Recordatorios')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(),
        icon: const Icon(Icons.alarm_add),
        label: const Text('Nuevo'),
      ),
      body: PawBackground(child: _contenido(context)),
    );
  }

  Widget _contenido(BuildContext context) {
    final todos = _recordatorios;
    if (todos == null) return const Center(child: CircularProgressIndicator());
    if (todos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('⏰🐱', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 12),
              Text(
                'No hay recordatorios.\n'
                '¡Que no se te pase la comida ni la vacuna!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      );
    }
    final ahora = widget.servicio.reloj();
    final proximos = [
      for (final r in todos)
        if (r.proximaOcurrencia(ahora) case final p?) (r, p),
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    final pasados =
        todos.where((r) => r.proximaOcurrencia(ahora) == null).toList()
          ..sort((a, b) => b.fecha.compareTo(a.fecha));
    final nombres = {for (final m in _michis) m.id: m};

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        if (proximos.isNotEmpty) ...[
          const _Encabezado('⏰ Próximos'),
          for (final (r, p) in proximos)
            _TarjetaRecordatorio(
              recordatorio: r,
              michi: nombres[r.michiId],
              cuando: p,
              onTap: () => _abrirFormulario(r),
              onActivo: (v) => _alternar(r, v),
            ),
        ],
        if (pasados.isNotEmpty) ...[
          const _Encabezado('🕰️ Pasados'),
          for (final r in pasados)
            _TarjetaRecordatorio(
              recordatorio: r,
              michi: nombres[r.michiId],
              cuando: r.fecha,
              onTap: () => _abrirFormulario(r),
            ),
        ],
      ],
    );
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
    child: Text(texto, style: Theme.of(context).textTheme.titleLarge),
  );
}

class _TarjetaRecordatorio extends StatelessWidget {
  const _TarjetaRecordatorio({
    required this.recordatorio,
    required this.michi,
    required this.cuando,
    required this.onTap,
    this.onActivo,
  });

  final Recordatorio recordatorio;
  final Michi? michi;
  final DateTime cuando;
  final VoidCallback onTap;
  final ValueChanged<bool>? onActivo;

  @override
  Widget build(BuildContext context) {
    final r = recordatorio;
    final apagado = onActivo != null && !r.activo;
    final partes = [
      michi == null ? '🐾 Todos' : '${michi!.emoji} ${michi!.nombre}',
      r.repeticion.etiqueta,
    ];
    return Opacity(
      opacity: apagado ? 0.55 : 1,
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          onTap: onTap,
          leading: CircleAvatar(
            child: Text(r.tipo.emoji, style: const TextStyle(fontSize: 22)),
          ),
          title: Text(r.titulo),
          subtitle: Text('${fechaHora(cuando)}\n${partes.join(' · ')}'),
          isThreeLine: true,
          trailing: onActivo == null
              ? null
              : Switch(value: r.activo, onChanged: onActivo),
        ),
      ),
    );
  }
}
