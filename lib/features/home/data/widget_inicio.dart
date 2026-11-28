import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../../fechas/domain/fechas_repository.dart';
import '../../listas/domain/config_club.dart';
import '../../listas/domain/item_lista.dart';
import '../domain/aniversario.dart';

/// Claves que lee el widget de Android (`ClubWidgetProvider.kt`).
abstract final class ClavesWidget {
  static const aniversario = 'aniversario';

  /// Fecha "aaaa-mm-dd" para que el widget recalcule los días cada día.
  static const aniversarioFecha = 'aniversario_fecha';
  static const pelicula = 'pelicula';
  static const plan = 'plan';

  /// Línea completa de la próxima fecha importante:
  /// "📆 Cumpleaños de Ana · Faltan 12 días".
  static const fecha = 'fecha';

  /// Partes de esa línea para que el widget recalcule los días cada día:
  /// "📆 Cumpleaños de Ana", el día "aaaa-mm-dd" en que toca y el extra
  /// opcional ("cumple 30 años").
  static const fechaTitulo = 'fecha_titulo';
  static const fechaDia = 'fecha_dia';
  static const fechaExtra = 'fecha_extra';

  /// Marca que la app ya guardó datos (aunque todas las líneas estén ocultas).
  static const listo = 'listo';
}

/// Lo que muestra el widget. Un valor null oculta esa línea.
Map<String, String?> datosWidget({
  required List<ItemLista> peliculas,
  required List<ItemLista> planes,
  required ConfigClub config,
  required DateTime hoy,
  List<FechaImportante> fechas = const [],
}) {
  String? siguiente(List<ItemLista> items) {
    final pendientes = items.where((i) => !i.hecho).toList()
      ..sort((a, b) => a.creadoEn.compareTo(b.creadoEn));
    return pendientes.isEmpty ? '¡Nada pendiente!' : pendientes.first.titulo;
  }

  final aniversario = config.contador ? config.aniversario : null;
  final proxima = config.fechas ? siguienteFecha(fechas, hoy) : null;
  final dia = proxima?.proxima(hoy);
  String dosDigitos(int n) => n.toString().padLeft(2, '0');
  String? aaaammdd(DateTime? f) => f == null
      ? null
      : '${f.year}-${dosDigitos(f.month)}-${dosDigitos(f.day)}';
  return {
    ClavesWidget.listo: 'si',
    ClavesWidget.aniversario: aniversario == null
        ? null
        : textoAniversario(aniversario, hoy),
    ClavesWidget.aniversarioFecha: aaaammdd(aniversario),
    ClavesWidget.pelicula: config.peliculas
        ? '🎬 Próxima película: ${siguiente(peliculas)}'
        : null,
    ClavesWidget.plan: config.planes
        ? '🧺 Próximo plan: ${siguiente(planes)}'
        : null,
    ClavesWidget.fecha: proxima == null
        ? null
        : '📆 ${proxima.titulo} · ${proxima.cuentaRegresiva(hoy)}',
    ClavesWidget.fechaTitulo: proxima == null ? null : '📆 ${proxima.titulo}',
    ClavesWidget.fechaDia: aaaammdd(dia),
    ClavesWidget.fechaExtra: proxima?.cumple(hoy),
  };
}

/// Mantiene al día el widget de la pantalla de inicio de Android.
///
/// Escucha películas, planes, fechas importantes y configuración, y guarda los textos con
/// `home_widget` (esperando un momento para juntar varios cambios). En
/// cualquier otra plataforma, y en las pruebas, no hace nada.
class WidgetInicio {
  WidgetInicio(
    this.repository, {
    DateTime Function()? reloj,
    bool? habilitado,
    this.espera = const Duration(milliseconds: 800),
  }) : _reloj = reloj ?? DateTime.now,
       habilitado = habilitado ?? esAndroid;

  /// Nombre completo del `AppWidgetProvider` (el paquete de Kotlin no es el
  /// applicationId, por eso no basta con `androidName`).
  static const proveedorAndroid = 'com.igss.movil_app.ClubWidgetProvider';

  /// Solo en Android de verdad. `flutter test` reporta Android como
  /// [defaultTargetPlatform], por eso también se revisa [Platform.isAndroid].
  static bool get esAndroid =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      Platform.isAndroid;

  final ListaRepository repository;
  final bool habilitado;
  final Duration espera;
  final DateTime Function() _reloj;

  final _suscripciones = <StreamSubscription<Object?>>[];
  Timer? _temporizador;
  var _peliculas = const <ItemLista>[];
  var _planes = const <ItemLista>[];
  var _fechas = const <FechaImportante>[];
  StreamSubscription<Object?>? _subFechas;
  var _config = const ConfigClub();

  void iniciar() {
    if (!habilitado || _suscripciones.isNotEmpty) return;
    void error(Object e) => debugPrint('Widget de inicio: $e');
    _suscripciones.addAll([
      repository.watch(TipoLista.peliculas).listen((items) {
        _peliculas = items;
        _programar();
      }, onError: error),
      repository.watch(TipoLista.planes).listen((items) {
        _planes = items;
        _programar();
      }, onError: error),
      repository.watchConfig().listen((config) {
        // Las reglas niegan leer las fechas con la bandera apagada: se
        // escuchan solo mientras esté encendida.
        if (config.fechas && _subFechas == null) _escucharFechas();
        if (!config.fechas) {
          _subFechas?.cancel();
          _subFechas = null;
        }
        _config = config;
        _programar();
      }, onError: error),
    ]);
  }

  void _escucharFechas() {
    _subFechas = repository.fechas.watch().listen(
      (fechas) {
        _fechas = fechas;
        _programar();
      },
      onError: (Object e) {
        debugPrint('Widget de inicio (fechas): $e');
        // Se vuelve a intentar con el próximo cambio de configuración.
        _subFechas?.cancel();
        _subFechas = null;
      },
    );
  }

  void _programar() {
    _temporizador?.cancel();
    _temporizador = Timer(espera, _enviar);
  }

  Future<void> _enviar() async {
    // Con la bandera `widget` en false se deja de actualizar.
    if (!_config.widget) return;
    final datos = datosWidget(
      peliculas: _peliculas,
      planes: _planes,
      config: _config,
      hoy: _reloj(),
      fechas: _fechas,
    );
    try {
      for (final MapEntry(:key, :value) in datos.entries) {
        await HomeWidget.saveWidgetData<String>(key, value);
      }
      await HomeWidget.updateWidget(qualifiedAndroidName: proveedorAndroid);
    } catch (e) {
      debugPrint('No se pudo actualizar el widget de inicio: $e');
    }
  }

  void dispose() {
    _temporizador?.cancel();
    for (final s in _suscripciones) {
      s.cancel();
    }
    _suscripciones.clear();
    _subFechas?.cancel();
    _subFechas = null;
  }
}
