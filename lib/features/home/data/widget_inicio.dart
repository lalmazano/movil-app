import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

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

  /// Marca que la app ya guardó datos (aunque todas las líneas estén ocultas).
  static const listo = 'listo';
}

/// Lo que muestra el widget. Un valor null oculta esa línea.
Map<String, String?> datosWidget({
  required List<ItemLista> peliculas,
  required List<ItemLista> planes,
  required ConfigClub config,
  required DateTime hoy,
}) {
  String? siguiente(List<ItemLista> items) {
    final pendientes = items.where((i) => !i.hecho).toList()
      ..sort((a, b) => a.creadoEn.compareTo(b.creadoEn));
    return pendientes.isEmpty ? '¡Nada pendiente!' : pendientes.first.titulo;
  }

  final aniversario = config.aniversario;
  String dosDigitos(int n) => n.toString().padLeft(2, '0');
  return {
    ClavesWidget.listo: 'si',
    ClavesWidget.aniversario: aniversario == null
        ? null
        : textoAniversario(aniversario, hoy),
    ClavesWidget.aniversarioFecha: aniversario == null
        ? null
        : '${aniversario.year}-${dosDigitos(aniversario.month)}-'
              '${dosDigitos(aniversario.day)}',
    ClavesWidget.pelicula: config.peliculas
        ? '🎬 Próxima película: ${siguiente(peliculas)}'
        : null,
    ClavesWidget.plan: config.planes
        ? '🧺 Próximo plan: ${siguiente(planes)}'
        : null,
  };
}

/// Mantiene al día el widget de la pantalla de inicio de Android.
///
/// Escucha películas, planes y configuración, y guarda los textos con
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
        _config = config;
        _programar();
      }, onError: error),
    ]);
  }

  void _programar() {
    _temporizador?.cancel();
    _temporizador = Timer(espera, _enviar);
  }

  Future<void> _enviar() async {
    final datos = datosWidget(
      peliculas: _peliculas,
      planes: _planes,
      config: _config,
      hoy: _reloj(),
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
  }
}
