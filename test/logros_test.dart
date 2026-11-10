import 'package:flutter_test/flutter_test.dart';
import 'package:movil_app/features/logros/domain/logro.dart';
import 'package:movil_app/features/michis/domain/michi.dart';
import 'package:movil_app/features/recuerdos/domain/recuerdo.dart';

final _hoy = DateTime(2026, 11, 10, 12);
var _n = 0;

Recuerdo _foto(DateTime fecha, {int calificacion = 3, String? michiId}) =>
    Recuerdo(
      id: '${_n++}',
      imagePath: '/x.jpg',
      fecha: fecha,
      calificacion: calificacion,
      michiId: michiId,
    );

RegistroPeso _peso(int dia) => RegistroPeso(
  id: '$dia',
  michiId: 'm',
  fecha: DateTime(2026, 1, dia),
  kg: 4,
);

Map<String, Logro> _calcular({
  List<Michi> michis = const [],
  List<Recuerdo> recuerdos = const [],
  List<RegistroPeso> pesos = const [],
  DateTime? hoy,
}) => {
  for (final l in calcularLogros(
    michis: michis,
    recuerdos: recuerdos,
    pesos: pesos,
    hoy: hoy ?? _hoy,
  ))
    l.id: l,
};

List<Recuerdo> _fotos(int n) => [
  for (var i = 0; i < n; i++)
    _foto(DateTime(2026, 1, 1).add(Duration(days: i * 2))),
];

void main() {
  test('sin datos no hay nada desbloqueado y los ids son únicos', () {
    final logros = calcularLogros(
      michis: const [],
      recuerdos: const [],
      pesos: const [],
      hoy: _hoy,
    );
    expect(logros.length, greaterThanOrEqualTo(10));
    expect(logros.map((l) => l.id).toSet().length, logros.length);
    expect(logros.where((l) => l.desbloqueado), isEmpty);
    for (final l in logros) {
      expect(l.progreso, inInclusiveRange(0, 1));
      expect(l.emoji, isNotEmpty);
      expect(l.titulo, isNotEmpty);
    }
  });

  test('logros por cantidad de fotos', () {
    var l = _calcular(recuerdos: _fotos(1));
    expect(l['primer_recuerdo']!.desbloqueado, isTrue);
    expect(l['fotografo_michi']!.actual, 1);
    expect(l['fotografo_michi']!.progreso, closeTo(0.1, 1e-9));

    l = _calcular(recuerdos: _fotos(9));
    expect(l['fotografo_michi']!.desbloqueado, isFalse);
    l = _calcular(recuerdos: _fotos(10));
    expect(l['fotografo_michi']!.desbloqueado, isTrue);
    expect(l['paparazzi_gatuno']!.actual, 10);

    l = _calcular(recuerdos: _fotos(49));
    expect(l['paparazzi_gatuno']!.desbloqueado, isFalse);
    l = _calcular(recuerdos: _fotos(60));
    expect(l['paparazzi_gatuno']!.desbloqueado, isTrue);
    expect(l['paparazzi_gatuno']!.actual, 50, reason: 'se limita a la meta');
  });

  test('¡Purr-fecto! y Crítico exigente', () {
    var l = _calcular(
      recuerdos: [_foto(_hoy, calificacion: 4), _foto(_hoy, calificacion: 2)],
    );
    expect(l['purrfecto']!.desbloqueado, isFalse);
    expect(l['critico_exigente']!.desbloqueado, isFalse);

    l = _calcular(
      recuerdos: [_foto(_hoy, calificacion: 5), _foto(_hoy, calificacion: 1)],
    );
    expect(l['purrfecto']!.desbloqueado, isTrue);
    expect(l['critico_exigente']!.desbloqueado, isTrue);
  });

  group('racha de 7 días', () {
    List<Recuerdo> dias(DateTime inicio, int n) => [
      for (var i = 0; i < n; i++)
        _foto(DateTime(inicio.year, inicio.month, inicio.day + i, 9)),
    ];

    test('7 días seguidos la desbloquean', () {
      final l = _calcular(recuerdos: dias(DateTime(2026, 3, 1), 7));
      expect(l['racha_7_dias']!.desbloqueado, isTrue);
    });

    test('6 días seguidos no alcanzan', () {
      final l = _calcular(recuerdos: dias(DateTime(2026, 3, 1), 6));
      expect(l['racha_7_dias']!.actual, 6);
      expect(l['racha_7_dias']!.desbloqueado, isFalse);
    });

    test('un hueco rompe la racha', () {
      final fotos = [
        ...dias(DateTime(2026, 3, 1), 4),
        ...dias(DateTime(2026, 3, 6), 3), // falta el 5
      ];
      final l = _calcular(recuerdos: fotos);
      expect(l['racha_7_dias']!.actual, 4);
      expect(l['racha_7_dias']!.desbloqueado, isFalse);
    });

    test('varias fotos el mismo día cuentan una vez', () {
      final fotos = [
        for (var h = 0; h < 7; h++) _foto(DateTime(2026, 3, 1, h)),
        _foto(DateTime(2026, 3, 2, 23, 59)),
      ];
      expect(_calcular(recuerdos: fotos)['racha_7_dias']!.actual, 2);
    });

    test('cruza meses, años y cambios de horario', () {
      expect(
        rachaMasLarga([
          for (var i = 0; i < 7; i++) DateTime(2025, 12, 28 + i, 23, 30),
        ], hoy: _hoy),
        7,
      );
      // Fin de semana con cambio de horario de verano en muchas zonas.
      expect(
        rachaMasLarga([
          for (var i = 0; i < 7; i++) DateTime(2026, 3, 26 + i, 0, 15),
        ], hoy: _hoy),
        7,
      );
    });

    test('desordenadas y con fechas futuras ignoradas', () {
      final fechas = [
        for (var i = 6; i >= 0; i--) DateTime(2026, 11, 4 + i), // 4..10
      ];
      expect(rachaMasLarga(fechas, hoy: _hoy), 7);
      // Si "hoy" es el 9, el 10 no cuenta.
      expect(rachaMasLarga(fechas, hoy: DateTime(2026, 11, 9)), 6);
      expect(rachaMasLarga(const [], hoy: _hoy), 0);
    });

    test('se queda con la racha más larga', () {
      final fechas = [
        ...[for (var i = 0; i < 3; i++) DateTime(2026, 1, 1 + i)],
        ...[for (var i = 0; i < 8; i++) DateTime(2026, 2, 1 + i)],
        ...[for (var i = 0; i < 2; i++) DateTime(2026, 3, 1 + i)],
      ];
      expect(rachaMasLarga(fechas, hoy: _hoy), 8);
    });
  });

  test('Familia gatuna', () {
    const uno = [Michi(id: 'a', nombre: 'Pelusa')];
    const dos = [...uno, Michi(id: 'b', nombre: 'Tom')];
    expect(_calcular(michis: uno)['familia_gatuna']!.desbloqueado, isFalse);
    expect(_calcular(michis: dos)['familia_gatuna']!.desbloqueado, isTrue);
  });

  test('Perfil completo pide foto y nacimiento en el mismo michi', () {
    final soloFoto = Michi(id: 'a', nombre: 'A', fotoPath: '/a.jpg');
    final soloNacimiento = Michi(
      id: 'b',
      nombre: 'B',
      nacimiento: DateTime(2020),
    );
    var l = _calcular(michis: [soloFoto, soloNacimiento]);
    expect(l['perfil_completo']!.actual, 1);
    expect(l['perfil_completo']!.desbloqueado, isFalse);

    l = _calcular(
      michis: [
        Michi(
          id: 'c',
          nombre: 'C',
          fotoPath: '/c.jpg',
          nacimiento: DateTime(2020),
        ),
      ],
    );
    expect(l['perfil_completo']!.desbloqueado, isTrue);
  });

  test('Todos en la foto', () {
    const michis = [Michi(id: 'a', nombre: 'A'), Michi(id: 'b', nombre: 'B')];
    var l = _calcular(
      michis: michis,
      recuerdos: [
        _foto(_hoy, michiId: 'a'),
        _foto(_hoy, michiId: 'a'),
        _foto(_hoy, michiId: 'borrado'),
        _foto(_hoy),
      ],
    );
    expect(l['todos_en_la_foto']!.actual, 1);
    expect(l['todos_en_la_foto']!.meta, 2);
    expect(l['todos_en_la_foto']!.desbloqueado, isFalse);

    l = _calcular(
      michis: michis,
      recuerdos: [
        _foto(_hoy, michiId: 'a'),
        _foto(_hoy, michiId: 'b'),
      ],
    );
    expect(l['todos_en_la_foto']!.desbloqueado, isTrue);
  });

  test('Foto de cumple', () {
    final michis = [
      Michi(id: 'a', nombre: 'A', nacimiento: DateTime(2020, 4, 5)),
    ];
    expect(
      _calcular(
        michis: michis,
        recuerdos: [_foto(DateTime(2026, 4, 6), michiId: 'a')],
      )['foto_de_cumple']!.desbloqueado,
      isFalse,
    );
    expect(
      _calcular(
        michis: michis,
        recuerdos: [_foto(DateTime(2026, 4, 5, 18), michiId: 'a')],
      )['foto_de_cumple']!.desbloqueado,
      isTrue,
    );
  });

  test('Báscula al día', () {
    var l = _calcular(pesos: [_peso(1), _peso(2)]);
    expect(l['bascula_al_dia']!.actual, 2);
    expect(l['bascula_al_dia']!.desbloqueado, isFalse);
    l = _calcular(pesos: [_peso(1), _peso(2), _peso(3)]);
    expect(l['bascula_al_dia']!.desbloqueado, isTrue);
  });
}
