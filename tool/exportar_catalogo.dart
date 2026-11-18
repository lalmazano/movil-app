// Genera tool/seed/peliculas.json a partir del catálogo de la app.
// Uso: dart run tool/exportar_catalogo.dart
import 'dart:convert';
import 'dart:io';

import 'package:movil_app/features/listas/data/catalogo_disney.dart';

void main() {
  final peliculas = [
    for (final MapEntry(key: categoria, value: titulos)
        in catalogoDisney.entries)
      for (final titulo in titulos) {'titulo': titulo, 'categoria': categoria},
  ];
  File('tool/seed/peliculas.json').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(peliculas)}\n',
  );
  stdout.writeln('${peliculas.length} películas exportadas');
}
