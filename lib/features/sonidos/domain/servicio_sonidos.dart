import 'package:flutter/foundation.dart';

/// Efectos de sonido gatunos de la app.
///
/// Es un [ChangeNotifier] para que la interfaz (por ejemplo [BotonSonido])
/// se redibuje cuando se activan o desactivan los sonidos. Ningún método
/// lanza excepciones: si el audio falla, el michi simplemente se queda mudo.
abstract class ServicioSonidos extends ChangeNotifier {
  /// `true` si los sonidos están encendidos.
  bool get activado;

  /// Enciende o apaga los sonidos y guarda la preferencia.
  Future<void> setActivado(bool valor);

  /// Maullido corto.
  Future<void> maullar();

  /// Ronroneo grave. Se repite [vueltas] veces (cada vuelta dura ~1.5 s);
  /// con `vueltas <= 0` sigue en bucle hasta [detenerRonroneo].
  Future<void> ronronear({int vueltas = 2});

  /// Corta el ronroneo si está sonando.
  Future<void> detenerRonroneo();

  /// "Pop" corto, por ejemplo al atrapar algo en el juego.
  Future<void> pop();

  /// Trino de pajarito.
  Future<void> trino();
}

/// Implementación muda para pruebas: no reproduce nada, solo anota qué se
/// pidió en [llamadas].
class ServicioSonidosSilencioso extends ServicioSonidos {
  ServicioSonidosSilencioso({this._activado = true});

  bool _activado;
  final List<String> llamadas = [];

  @override
  bool get activado => _activado;

  @override
  Future<void> setActivado(bool valor) async {
    if (_activado == valor) return;
    _activado = valor;
    notifyListeners();
  }

  void _anotar(String sonido) {
    if (_activado) llamadas.add(sonido);
  }

  @override
  Future<void> maullar() async => _anotar('maullar');

  @override
  Future<void> ronronear({int vueltas = 2}) async => _anotar('ronronear');

  @override
  Future<void> detenerRonroneo() async => llamadas.add('detenerRonroneo');

  @override
  Future<void> pop() async => _anotar('pop');

  @override
  Future<void> trino() async => _anotar('trino');
}
