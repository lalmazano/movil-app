import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';

/// Marcos disponibles para decorar la foto del michi.
enum Marco {
  ninguno('Sin marco', '🚫'),
  huellitas('Huellitas', '🐾'),
  rosa('Rosa', '🌸'),
  polaroid('Polaroid', '📸');

  const Marco(this.etiqueta, this.emoji);

  final String etiqueta;
  final String emoji;
}

/// Stickers del cajón. Los que no son emoji se dibujan en código.
abstract final class StickersMichi {
  static const String orejitas = 'orejitas';
  static const String bigotes = 'bigotes';

  static const List<String> catalogo = [
    orejitas,
    bigotes,
    '🐱',
    '😻',
    '🐾',
    '💕',
    '👑',
    '🐟',
    '✨',
    '🎀',
    '🌸',
    '🧶',
  ];

  static bool esDibujado(String sticker) =>
      sticker == orejitas || sticker == bigotes;
}

/// Un sticker colocado sobre la foto.
///
/// [posicion] está normalizada (0..1) respecto al lienzo, así la composición
/// se ve igual en pantalla y al exportarla a mayor resolución.
@immutable
class StickerColocado {
  const StickerColocado({
    required this.id,
    required this.sticker,
    this.posicion = const Offset(0.5, 0.5),
    this.escala = 1,
    this.rotacion = 0,
  });

  final String id;
  final String sticker;
  final Offset posicion;
  final double escala;

  /// Rotación en radianes.
  final double rotacion;

  StickerColocado copyWith({
    Offset? posicion,
    double? escala,
    double? rotacion,
  }) => StickerColocado(
    id: id,
    sticker: sticker,
    posicion: posicion ?? this.posicion,
    escala: escala ?? this.escala,
    rotacion: rotacion ?? this.rotacion,
  );

  @override
  bool operator ==(Object other) =>
      other is StickerColocado &&
      other.id == id &&
      other.sticker == sticker &&
      other.posicion == posicion &&
      other.escala == escala &&
      other.rotacion == rotacion;

  @override
  int get hashCode => Object.hash(id, sticker, posicion, escala, rotacion);
}

class _Foto {
  const _Foto(this.stickers, this.marco);

  final List<StickerColocado> stickers;
  final Marco marco;
}

/// Estado puro del editor: stickers, marco, selección e historial (deshacer).
///
/// Durante un gesto continuo (arrastrar/pellizcar) se llama a
/// [comenzarGesto] una vez para guardar una sola foto del historial y
/// luego [mover]/[transformar] tantas veces como haga falta.
class EditorEstado extends ChangeNotifier {
  EditorEstado({String Function()? generarId})
    : _generarId = generarId ?? _idPorDefecto;

  static int _contador = 0;
  static String _idPorDefecto() =>
      '${DateTime.now().microsecondsSinceEpoch}_${_contador++}';

  static const double escalaMinima = 0.3;
  static const double escalaMaxima = 5;

  final String Function() _generarId;
  final List<_Foto> _historial = [];

  List<StickerColocado> _stickers = const [];
  Marco _marco = Marco.ninguno;
  String? _seleccionado;
  bool _enGesto = false;

  List<StickerColocado> get stickers => List.unmodifiable(_stickers);
  Marco get marco => _marco;
  String? get seleccionadoId => _seleccionado;
  bool get puedeDeshacer => _historial.isNotEmpty;
  bool get estaVacio => _stickers.isEmpty && _marco == Marco.ninguno;

  StickerColocado? get seleccionado {
    for (final s in _stickers) {
      if (s.id == _seleccionado) return s;
    }
    return null;
  }

  void _guardar() => _historial.add(_Foto(_stickers, _marco));

  /// Agrega un sticker (por defecto al centro) y lo deja seleccionado.
  String agregar(String sticker, {Offset posicion = const Offset(0.5, 0.5)}) {
    _guardar();
    final id = _generarId();
    _stickers = [
      ..._stickers,
      StickerColocado(id: id, sticker: sticker, posicion: _limitar(posicion)),
    ];
    _seleccionado = id;
    notifyListeners();
    return id;
  }

  void seleccionar(String? id) {
    if (_seleccionado == id) return;
    _seleccionado = id;
    notifyListeners();
  }

  /// Trae el sticker al frente y guarda el estado para deshacer el gesto.
  void comenzarGesto(String id) {
    final i = _stickers.indexWhere((s) => s.id == id);
    if (i < 0) return;
    _guardar();
    _enGesto = true;
    final s = _stickers[i];
    _stickers = [..._stickers]
      ..removeAt(i)
      ..add(s);
    _seleccionado = id;
    notifyListeners();
  }

  void terminarGesto() => _enGesto = false;

  /// Desplaza un sticker. [delta] está normalizado respecto al lienzo.
  void mover(String id, Offset delta) => _actualizar(
    id,
    (s) => s.copyWith(posicion: _limitar(s.posicion + delta)),
  );

  /// Fija escala y rotación absolutas de un sticker.
  void transformar(String id, {double? escala, double? rotacion}) =>
      _actualizar(
        id,
        (s) => s.copyWith(
          escala: escala?.clamp(escalaMinima, escalaMaxima).toDouble(),
          rotacion: rotacion,
        ),
      );

  void eliminar(String id) {
    if (!_stickers.any((s) => s.id == id)) return;
    _guardar();
    _stickers = _stickers.where((s) => s.id != id).toList();
    if (_seleccionado == id) _seleccionado = null;
    notifyListeners();
  }

  void cambiarMarco(Marco marco) {
    if (marco == _marco) return;
    _guardar();
    _marco = marco;
    notifyListeners();
  }

  void deshacer() {
    if (_historial.isEmpty) return;
    final anterior = _historial.removeLast();
    _stickers = anterior.stickers;
    _marco = anterior.marco;
    if (seleccionado == null) _seleccionado = null;
    _enGesto = false;
    notifyListeners();
  }

  /// Quita todos los stickers y el marco (se puede deshacer).
  void limpiar() {
    if (estaVacio) return;
    _guardar();
    _stickers = const [];
    _marco = Marco.ninguno;
    _seleccionado = null;
    notifyListeners();
  }

  void _actualizar(
    String id,
    StickerColocado Function(StickerColocado) cambio,
  ) {
    final i = _stickers.indexWhere((s) => s.id == id);
    if (i < 0) return;
    if (!_enGesto) _guardar();
    _stickers = [..._stickers]..[i] = cambio(_stickers[i]);
    notifyListeners();
  }

  static Offset _limitar(Offset p) =>
      Offset(p.dx.clamp(0.0, 1.0), p.dy.clamp(0.0, 1.0));
}
