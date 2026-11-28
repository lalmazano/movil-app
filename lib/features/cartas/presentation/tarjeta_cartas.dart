import 'package:flutter/material.dart';

import '../../listas/domain/item_lista.dart';
import '../../listas/presentation/config_scope.dart';
import '../domain/cartas_repository.dart';
import 'cartas_page.dart';
import 'formato_cartas.dart';

/// Tarjeta "💌 Cartas" en el inicio. Se oculta si la bandera `cartas` de
/// config/app es false.
class TarjetaCartas extends StatefulWidget {
  const TarjetaCartas({super.key, required this.repository});

  final ListaRepository repository;

  @override
  State<TarjetaCartas> createState() => _TarjetaCartasState();
}

class _TarjetaCartasState extends State<TarjetaCartas> {
  /// Se crea solo cuando la bandera está activa (si no, las reglas
  /// rechazarían la lectura).
  Stream<List<Carta>>? _cartas;

  CartasRepository get _repo => widget.repository.cartas;

  /// Resumen corto según el estado de las cartas.
  String _resumen(List<Carta> cartas) {
    final ahora = _repo.ahora();
    final uid = _repo.uidActual;
    final listas = cartas
        .where((c) => !c.esDe(uid) && !c.abierta && !c.bloqueadaEn(ahora))
        .length;
    if (listas > 0) {
      return listas == 1
          ? '1 carta lista para abrir'
          : '$listas cartas listas para abrir';
    }
    final cerradas = cartas.where((c) => c.bloqueadaEn(ahora)).toList()
      ..sort((a, b) => a.abrirEn.compareTo(b.abrirEn));
    if (cerradas.isNotEmpty) {
      final falta = cerradas.first.abrirEn.difference(ahora);
      return 'Próxima se abre en ${duracionAmable(falta)}';
    }
    return 'Escríbele una carta';
  }

  @override
  Widget build(BuildContext context) {
    if (!ConfigClubScope.of(context).cartas) return const SizedBox.shrink();
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => CartasPage(cartas: _repo)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: StreamBuilder<List<Carta>>(
            stream: _cartas ??= _repo.watch(),
            builder: (context, snap) {
              final subtitulo = snap.hasError
                  ? 'No se pudieron cargar las cartas'
                  : snap.hasData
                  ? _resumen(snap.data!)
                  : 'Cargando…';
              return Row(
                children: [
                  const Text('💌', style: TextStyle(fontSize: 32)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Cartas', style: textTheme.titleMedium),
                        Text(subtitulo, style: textTheme.bodyMedium),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
