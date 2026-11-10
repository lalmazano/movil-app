import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/servicios.dart';
import '../../../core/widgets/paw_background.dart';
import '../../michis/domain/michi.dart';
import '../../michis/presentation/widgets/michi_avatar.dart';
import '../data/dispositivo_recuerdo_acciones.dart';
import '../domain/recuerdo.dart';
import '../domain/recuerdo_acciones.dart';
import 'nuevo_recuerdo_page.dart';
import 'recuerdo_detalle_page.dart';
import 'widgets/calificacion_huellitas.dart';
import 'widgets/foto_recuerdo.dart';
import 'widgets/selector_michi.dart';

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

/// Orden de la galería.
enum OrdenRecuerdos {
  recientes('Más recientes', Icons.arrow_downward),
  antiguos('Más antiguos', Icons.arrow_upward),
  mejores('Mejor calificadas', Icons.star);

  const OrdenRecuerdos(this.etiqueta, this.icono);

  final String etiqueta;
  final IconData icono;
}

const _meses = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

/// "noviembre 2026".
String nombreMes(DateTime mes) => '${_meses[mes.month - 1]} ${mes.year}';

/// Galería de fotos con el michi.
class RecuerdosPage extends StatefulWidget {
  const RecuerdosPage({
    super.key,
    required this.repository,
    this.michiRepository,
    this.selectorFoto = _selectorPorDefecto,
    this.acciones = const DispositivoRecuerdoAcciones(),
  });

  final RecuerdoRepository repository;

  /// Michis para etiquetar y filtrar. Por defecto `AppServicios.instancia.michis`.
  final MichiRepository? michiRepository;
  final RecuerdoAcciones acciones;
  final SelectorFoto selectorFoto;

  @override
  State<RecuerdosPage> createState() => _RecuerdosPageState();
}

class _RecuerdosPageState extends State<RecuerdosPage> {
  List<Recuerdo>? _recuerdos;
  List<Michi> _michis = const [];
  OrdenRecuerdos _orden = OrdenRecuerdos.recientes;
  String? _filtroMichi;

  /// Primer día del mes filtrado, o null para todos.
  DateTime? _filtroMes;

  MichiRepository get _michiRepository =>
      widget.michiRepository ?? AppServicios.instancia.michis;

  bool get _hayFiltros => _filtroMichi != null || _filtroMes != null;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final recuerdos = await widget.repository.getAll();
    if (!mounted) return;
    setState(() => _recuerdos = recuerdos);
    // Los michis se cargan aparte para no retrasar la galería.
    final michis = await cargarMichisSeguro(_michiRepository);
    if (!mounted) return;
    setState(() {
      _michis = michis;
      if (!michis.any((m) => m.id == _filtroMichi)) _filtroMichi = null;
    });
  }

  Michi? _michiDe(Recuerdo r) =>
      _michis.where((m) => m.id == r.michiId).firstOrNull;

  List<Recuerdo> _visibles(List<Recuerdo> todos) {
    final mes = _filtroMes;
    final lista = [
      for (final r in todos)
        if ((_filtroMichi == null || r.michiId == _filtroMichi) &&
            (mes == null ||
                (r.fecha.year == mes.year && r.fecha.month == mes.month)))
          r,
    ];
    switch (_orden) {
      case OrdenRecuerdos.recientes:
        lista.sort((a, b) => b.fecha.compareTo(a.fecha));
      case OrdenRecuerdos.antiguos:
        lista.sort((a, b) => a.fecha.compareTo(b.fecha));
      case OrdenRecuerdos.mejores:
        lista.sort((a, b) {
          final c = b.calificacion.compareTo(a.calificacion);
          return c != 0 ? c : b.fecha.compareTo(a.fecha);
        });
    }
    return lista;
  }

  Future<void> _elegirOrden() async {
    final orden = await showModalBottomSheet<OrdenRecuerdos>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final o in OrdenRecuerdos.values)
              ListTile(
                leading: Icon(o.icono),
                title: Text(o.etiqueta),
                trailing: o == _orden ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(context, o),
              ),
          ],
        ),
      ),
    );
    if (orden != null && mounted) setState(() => _orden = orden);
  }

  Future<void> _elegirMes(List<Recuerdo> todos) async {
    final meses = {
      for (final r in todos) DateTime(r.fecha.year, r.fecha.month),
    }.toList()..sort((a, b) => b.compareTo(a));
    // Se usa un registro para distinguir "todos los meses" de "cancelar".
    final elegido = await showModalBottomSheet<(DateTime?,)>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.all_inclusive),
              title: const Text('Todos los meses'),
              trailing: _filtroMes == null ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(context, (null,)),
            ),
            for (final m in meses)
              ListTile(
                leading: const Icon(Icons.calendar_month),
                title: Text(nombreMes(m)),
                trailing: m == _filtroMes ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(context, (m,)),
              ),
          ],
        ),
      ),
    );
    if (elegido != null && mounted) setState(() => _filtroMes = elegido.$1);
  }

  void _limpiarFiltros() => setState(() {
    _filtroMichi = null;
    _filtroMes = null;
  });

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
        builder: (_) => NuevoRecuerdoPage(
          fotoPath: path!,
          repository: widget.repository,
          michiRepository: _michiRepository,
        ),
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
          acciones: widget.acciones,
          michiRepository: _michiRepository,
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
    final visibles = _visibles(recuerdos);
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          sliver: SliverToBoxAdapter(child: _filtros(recuerdos)),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          sliver: SliverToBoxAdapter(
            child: Text(
              _resumen(visibles),
              textAlign: TextAlign.center,
              style: textTheme.titleMedium,
            ),
          ),
        ),
        if (visibles.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _Mensaje(
              emoji: '🔍🐱',
              texto: 'Ningún recuerdo coincide con los filtros.',
              accion: TextButton.icon(
                onPressed: _limpiarFiltros,
                icon: const Icon(Icons.filter_alt_off),
                label: const Text('Quitar filtros'),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.72,
              ),
              itemCount: visibles.length,
              itemBuilder: (context, i) => _TarjetaRecuerdo(
                recuerdo: visibles[i],
                michi: _michiDe(visibles[i]),
                onTap: () => _abrir(visibles[i]),
              ),
            ),
          ),
      ],
    );
  }

  String _resumen(List<Recuerdo> visibles) {
    if (visibles.isEmpty) return '0 recuerdos 🐾';
    final promedio =
        visibles.map((r) => r.calificacion).reduce((a, b) => a + b) /
        visibles.length;
    return '${visibles.length} '
        '${visibles.length == 1 ? 'recuerdo' : 'recuerdos'} · '
        'promedio ${promedio.toStringAsFixed(1)} 🐾';
  }

  Widget _filtros(List<Recuerdo> todos) {
    final mes = _filtroMes;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        ActionChip(
          avatar: Icon(_orden.icono, size: 18),
          label: Text(_orden.etiqueta),
          tooltip: 'Ordenar',
          onPressed: _elegirOrden,
        ),
        FilterChip(
          avatar: mes == null
              ? const Icon(Icons.calendar_month, size: 18)
              : null,
          label: Text(mes == null ? 'Todos los meses' : nombreMes(mes)),
          selected: mes != null,
          onSelected: (_) => _elegirMes(todos),
        ),
        for (final m in _michis)
          FilterChip(
            avatar: MichiAvatar.de(m, radius: 12),
            label: Text(m.nombre),
            selected: _filtroMichi == m.id,
            showCheckmark: false,
            onSelected: (sel) =>
                setState(() => _filtroMichi = sel ? m.id : null),
          ),
        if (_hayFiltros)
          ActionChip(
            avatar: const Icon(Icons.filter_alt_off, size: 18),
            label: const Text('Limpiar'),
            onPressed: _limpiarFiltros,
          ),
      ],
    );
  }
}

class _TarjetaRecuerdo extends StatelessWidget {
  const _TarjetaRecuerdo({
    required this.recuerdo,
    required this.michi,
    required this.onTap,
  });

  final Recuerdo recuerdo;
  final Michi? michi;
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
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  FotoRecuerdo(path: recuerdo.imagePath),
                  if (michi case final m?)
                    Positioned(
                      left: 6,
                      top: 6,
                      right: 6,
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: EtiquetaMichi(michi: m),
                      ),
                    ),
                ],
              ),
            ),
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
  const _Mensaje({required this.emoji, required this.texto, this.accion});

  final String emoji;
  final String texto;
  final Widget? accion;

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
            if (accion case final a?) ...[const SizedBox(height: 8), a],
          ],
        ),
      ),
    );
  }
}
