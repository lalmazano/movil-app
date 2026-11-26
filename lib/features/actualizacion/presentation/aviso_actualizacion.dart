import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../listas/domain/item_lista.dart';
import '../../listas/presentation/config_scope.dart';
import '../data/descargador_apk.dart';
import '../domain/version_app.dart';

/// Número de compilación instalado (versionCode).
typedef LeerBuild = Future<int> Function();

/// Descarga e instala el APK; emite el progreso de 0 a 100.
typedef Instalador = Stream<double> Function(VersionApp version);

Future<int> _buildInstalado() async =>
    int.tryParse((await PackageInfo.fromPlatform()).buildNumber) ?? 0;

bool get _esAndroid => !kIsWeb && Platform.isAndroid;

/// Tarjeta en el inicio que aparece cuando hay una versión nueva en
/// `config/version`. La primera vez además muestra un diálogo; si la
/// versión es obligatoria, el diálogo no se puede cerrar.
class AvisoActualizacion extends StatefulWidget {
  const AvisoActualizacion({
    super.key,
    required this.repository,
    this.leerBuild = _buildInstalado,
    this.instalador = instalarDesdeFirestore,
    bool? soportado,
  }) : soportado = soportado ?? false;

  /// Constructor para la app real: solo funciona en Android.
  AvisoActualizacion.android({super.key, required this.repository})
    : leerBuild = _buildInstalado,
      instalador = instalarDesdeFirestore,
      soportado = _esAndroid;

  final ListaRepository repository;
  final LeerBuild leerBuild;
  final Instalador instalador;

  /// Si la plataforma puede instalar APKs (solo Android).
  final bool soportado;

  @override
  State<AvisoActualizacion> createState() => _AvisoActualizacionState();
}

class _AvisoActualizacionState extends State<AvisoActualizacion> {
  StreamSubscription<VersionApp?>? _sub;
  VersionApp? _nueva;
  int? _instalado;
  bool _dialogoMostrado = false;

  @override
  void initState() {
    super.initState();
    if (!widget.soportado) return;
    _iniciar();
  }

  Future<void> _iniciar() async {
    try {
      _instalado = await widget.leerBuild();
    } catch (_) {
      return;
    }
    if (!mounted) return;
    _sub = widget.repository.watchVersion().listen((v) {
      final nueva = v != null && v.build > (_instalado ?? 0) ? v : null;
      if (!mounted) return;
      setState(() => _nueva = nueva);
      if (nueva != null && ConfigClubScope.of(context).actualizaciones) {
        _avisar(nueva);
      }
    }, onError: (Object _) {});
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _avisar(VersionApp v) {
    if (_dialogoMostrado) return;
    _dialogoMostrado = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _abrirDialogo(v);
    });
  }

  Future<void> _abrirDialogo(VersionApp v) => showDialog<void>(
    context: context,
    barrierDismissible: !v.obligatoria,
    builder: (_) => PopScope(
      canPop: !v.obligatoria,
      child: _DialogoActualizar(version: v, instalador: widget.instalador),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final v = _nueva;
    if (v == null || !ConfigClubScope.of(context).actualizaciones) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.primaryContainer,
      margin: const EdgeInsets.only(top: 12),
      child: ListTile(
        key: const Key('aviso-actualizacion'),
        leading: const Text('🎁', style: TextStyle(fontSize: 26)),
        title: Text('Nueva versión ${v.version}'),
        subtitle: const Text('Toca para actualizar'),
        trailing: const Icon(Icons.system_update),
        onTap: () => _abrirDialogo(v),
      ),
    );
  }
}

class _DialogoActualizar extends StatefulWidget {
  const _DialogoActualizar({required this.version, required this.instalador});

  final VersionApp version;
  final Instalador instalador;

  @override
  State<_DialogoActualizar> createState() => _DialogoActualizarState();
}

class _DialogoActualizarState extends State<_DialogoActualizar> {
  double? _progreso;
  String? _error;
  StreamSubscription<double>? _sub;

  void _actualizar() {
    setState(() {
      _progreso = 0;
      _error = null;
    });
    _sub = widget
        .instalador(widget.version)
        .listen(
          (p) {
            if (mounted) setState(() => _progreso = p);
          },
          onError: (Object e) {
            if (mounted) {
              setState(() {
                _progreso = null;
                _error = '$e';
              });
            }
          },
          onDone: () {
            // Android muestra su pantalla de instalación; cerramos el diálogo
            // salvo que la versión sea obligatoria.
            if (mounted && !widget.version.obligatoria) Navigator.pop(context);
          },
        );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.version;
    final textTheme = Theme.of(context).textTheme;
    final descargando = _progreso != null;
    return AlertDialog(
      title: Text('🎁 Versión ${v.version}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (v.notas.isNotEmpty) ...[
            Text('Novedades', style: textTheme.titleSmall),
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: SingleChildScrollView(child: Text(v.notas)),
            ),
            const SizedBox(height: 12),
          ],
          if (v.obligatoria)
            Text(
              'Esta actualización es necesaria para seguir usando la app.',
              style: textTheme.bodySmall,
            ),
          if (descargando) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(value: _progreso! / 100),
            const SizedBox(height: 4),
            Text('Descargando… ${_progreso!.round()} %'),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        if (!v.obligatoria && !descargando)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Después'),
          ),
        FilledButton(
          onPressed: descargando ? null : _actualizar,
          child: Text(_error == null ? 'Actualizar' : 'Reintentar'),
        ),
      ],
    );
  }
}
