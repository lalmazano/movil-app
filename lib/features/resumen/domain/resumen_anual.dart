import '../../listas/domain/item_lista.dart';

/// Algo que el club hizo en el año: el elemento, su lista y cuándo se hizo.
class LogroAnual {
  const LogroAnual({
    required this.item,
    required this.tipo,
    required this.fecha,
  });

  final ItemLista item;
  final TipoLista tipo;
  final DateTime fecha;
}

/// Estadísticas del año para el resumen tipo "Wrapped" (🎁).
class ResumenAnual {
  const ResumenAnual({
    required this.anio,
    required this.logros,
    required this.totales,
    required this.mejores,
    required this.categoriaFavorita,
    required this.vecesCategoriaFavorita,
    required this.mesMasActivo,
    required this.vecesMesMasActivo,
    required this.totalCalificaciones,
    required this.fotos,
    required this.repeticiones,
    required this.marcadoPor,
  });

  final int anio;

  /// Todo lo hecho en el año, del más antiguo al más reciente.
  final List<LogroAnual> logros;

  /// Cuántos elementos de cada lista se hicieron en el año.
  final Map<TipoLista, int> totales;

  /// Las 3 mejor calificadas (por promedio de huellitas; en empate, la que
  /// se hizo primero).
  final List<LogroAnual> mejores;

  /// La categoría con más elementos hechos (en empate, la que llegó primero
  /// a ese número). null si no hay datos.
  final String? categoriaFavorita;
  final int vecesCategoriaFavorita;

  /// Mes (1 a 12) con más elementos hechos (en empate, el primero). null si
  /// no hay datos.
  final int? mesMasActivo;
  final int vecesMesMasActivo;

  /// Calificaciones de los elementos hechos en el año.
  final int totalCalificaciones;

  /// Fotos guardadas en los elementos hechos en el año.
  final int fotos;

  /// Veces acumuladas de los repetibles que se hicieron en el año.
  final int repeticiones;

  /// Cuántos elementos marcó cada persona (por nombre corto), de más a menos.
  final Map<String, int> marcadoPor;

  int get total => logros.length;
  bool get vacio => logros.isEmpty;
  int totalDe(TipoLista tipo) => totales[tipo] ?? 0;

  LogroAnual? get primero => logros.isEmpty ? null : logros.first;
  LogroAnual? get ultimo => logros.isEmpty ? null : logros.last;

  /// Quién marcó más cosas, o null si nadie o si hay empate.
  MapEntry<String, int>? get quienMarcoMas {
    final entradas = marcadoPor.entries.toList();
    if (entradas.isEmpty) return null;
    if (entradas.length > 1 && entradas[1].value == entradas.first.value) {
      return null;
    }
    return entradas.first;
  }

  /// `true` si al menos dos personas marcaron y quedaron empatadas.
  bool get empateMarcado {
    final valores = marcadoPor.values.toList();
    return valores.length > 1 && valores[0] == valores[1];
  }
}

/// Cuándo se hizo [item] por última vez, o null si nunca.
///
/// Los repetibles usan [ItemLista.ultimaVez] (o [ItemLista.hechoEn] si
/// además están marcados y es más reciente).
DateTime? fechaHecho(ItemLista item) {
  final hechoEn = item.hecho ? item.hechoEn : null;
  if (!item.repetible) return hechoEn;
  final ultima = item.veces > 0 ? item.ultimaVez : null;
  if (ultima == null) return hechoEn;
  if (hechoEn == null) return ultima;
  return hechoEn.isAfter(ultima) ? hechoEn : ultima;
}

/// Calcula el resumen de [anio]. Para no mostrar una lista oculta, pásala
/// vacía.
ResumenAnual calcularResumen(
  int anio,
  List<ItemLista> peliculas,
  List<ItemLista> deseos,
  List<ItemLista> planes,
) {
  final porTipo = {
    TipoLista.peliculas: peliculas,
    TipoLista.deseos: deseos,
    TipoLista.planes: planes,
  };
  final logros = <LogroAnual>[
    for (final MapEntry(key: tipo, value: items) in porTipo.entries)
      for (final item in items)
        if (fechaHecho(item) case final fecha? when fecha.year == anio)
          LogroAnual(item: item, tipo: tipo, fecha: fecha),
  ];
  // Orden estable: por fecha y, en empate, por lista.
  logros.sort((a, b) => a.fecha.compareTo(b.fecha));

  final totales = {for (final tipo in TipoLista.values) tipo: 0};
  final categorias = <String, int>{};
  String? categoriaFavorita;
  var vecesCategoria = 0;
  final meses = <int, int>{};
  final marcadoPor = <String, int>{};
  var calificaciones = 0;
  var fotos = 0;
  var repeticiones = 0;

  for (final logro in logros) {
    final item = logro.item;
    totales[logro.tipo] = totales[logro.tipo]! + 1;
    final c = categorias[item.categoria] =
        (categorias[item.categoria] ?? 0) + 1;
    // Solo cambia si la supera: en empate gana la que llegó primero.
    if (c > vecesCategoria) {
      categoriaFavorita = item.categoria;
      vecesCategoria = c;
    }
    meses[logro.fecha.month] = (meses[logro.fecha.month] ?? 0) + 1;
    if (item.hechoPor case final autor?) {
      marcadoPor[autor.nombreCorto] = (marcadoPor[autor.nombreCorto] ?? 0) + 1;
    }
    calificaciones += item.calificaciones.length;
    fotos += item.fotos;
    if (item.repetible) repeticiones += item.veces;
  }

  int? mes;
  var vecesMes = 0;
  for (var m = 1; m <= 12; m++) {
    if ((meses[m] ?? 0) > vecesMes) {
      mes = m;
      vecesMes = meses[m]!;
    }
  }

  final calificados =
      logros.where((l) => l.item.promedioHuellitas != null).toList()
        ..sort((a, b) {
          final p = b.item.promedioHuellitas!.compareTo(
            a.item.promedioHuellitas!,
          );
          return p != 0 ? p : a.fecha.compareTo(b.fecha);
        });

  final personas = marcadoPor.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  return ResumenAnual(
    anio: anio,
    logros: List.unmodifiable(logros),
    totales: Map.unmodifiable(totales),
    mejores: List.unmodifiable(calificados.take(3)),
    categoriaFavorita: categoriaFavorita,
    vecesCategoriaFavorita: vecesCategoria,
    mesMasActivo: mes,
    vecesMesMasActivo: vecesMes,
    totalCalificaciones: calificaciones,
    fotos: fotos,
    repeticiones: repeticiones,
    marcadoPor: Map.unmodifiable(Map.fromEntries(personas)),
  );
}

/// Años en los que se hizo algo, del más reciente al más antiguo.
List<int> aniosConDatos(Iterable<ItemLista> items) {
  final anios = {
    for (final item in items)
      if (fechaHecho(item) case final fecha?) fecha.year,
  }.toList()..sort((a, b) => b.compareTo(a));
  return anios;
}

const nombresMeses = [
  'Enero',
  'Febrero',
  'Marzo',
  'Abril',
  'Mayo',
  'Junio',
  'Julio',
  'Agosto',
  'Septiembre',
  'Octubre',
  'Noviembre',
  'Diciembre',
];

/// Nombre del mes (1 = "Enero").
String nombreMes(int mes) => nombresMeses[mes - 1];
