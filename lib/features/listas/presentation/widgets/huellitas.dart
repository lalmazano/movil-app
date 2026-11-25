import 'package:flutter/material.dart';

import '../../domain/item_lista.dart';

/// Avatar redondo de una persona: su foto si la tiene, si no la inicial.
class AvatarAutor extends StatelessWidget {
  const AvatarAutor({super.key, required this.autor, this.radio = 12});

  final Autor autor;
  final double radio;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final foto = autor.fotoUrl;
    final nombre = autor.nombre?.trim() ?? '';
    return CircleAvatar(
      radius: radio,
      backgroundColor: esquema.primaryContainer,
      foregroundColor: esquema.onPrimaryContainer,
      foregroundImage: foto != null && foto.isNotEmpty
          ? NetworkImage(foto)
          : null,
      child: Text(
        nombre.isEmpty ? '?' : nombre.characters.first.toUpperCase(),
        style: TextStyle(fontSize: radio * 1.1, height: 1),
      ),
    );
  }
}

/// Fila de huellitas: [cantidad] encendidas de 5.
class FilaHuellitas extends StatelessWidget {
  const FilaHuellitas({super.key, required this.cantidad, this.tamano = 12});

  final int cantidad;
  final double tamano;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 1; i <= 5; i++)
        Opacity(
          opacity: i <= cantidad ? 1 : 0.2,
          child: Text('🐾', style: TextStyle(fontSize: tamano, height: 1.2)),
        ),
    ],
  );
}

/// Promedio legible: 4 → "4", 4.5 → "4.5".
String promedioTexto(double p) =>
    p == p.roundToDouble() ? '${p.toInt()}' : p.toStringAsFixed(1);
