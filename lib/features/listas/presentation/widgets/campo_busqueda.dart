import 'package:flutter/material.dart';

import '../../domain/item_lista.dart';

const _sinAcentos = {
  'á': 'a',
  'à': 'a',
  'ä': 'a',
  'â': 'a',
  'ã': 'a',
  'é': 'e',
  'è': 'e',
  'ë': 'e',
  'ê': 'e',
  'í': 'i',
  'ì': 'i',
  'ï': 'i',
  'î': 'i',
  'ó': 'o',
  'ò': 'o',
  'ö': 'o',
  'ô': 'o',
  'õ': 'o',
  'ú': 'u',
  'ù': 'u',
  'ü': 'u',
  'û': 'u',
  'ñ': 'n',
  'ç': 'c',
};

/// Texto en minúsculas y sin acentos, para comparar búsquedas.
String normalizarBusqueda(String texto) {
  final buffer = StringBuffer();
  for (final letra in texto.toLowerCase().trim().split('')) {
    buffer.write(_sinAcentos[letra] ?? letra);
  }
  return buffer.toString();
}

/// `true` si el título o la nota del elemento contienen [consulta]
/// (sin distinguir mayúsculas ni acentos). Una consulta vacía coincide con todo.
bool coincideBusqueda(ItemLista item, String consulta) {
  final q = normalizarBusqueda(consulta);
  if (q.isEmpty) return true;
  return normalizarBusqueda(item.titulo).contains(q) ||
      normalizarBusqueda(item.nota).contains(q);
}

/// Campo de búsqueda para el título del AppBar.
class CampoBusqueda extends StatelessWidget {
  const CampoBusqueda({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const Key('campo-busqueda'),
      controller: controller,
      autofocus: true,
      textInputAction: TextInputAction.search,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: 'Buscar…',
        border: InputBorder.none,
        isDense: true,
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, valor, _) => valor.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  tooltip: 'Borrar búsqueda',
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
        ),
      ),
    );
  }
}
