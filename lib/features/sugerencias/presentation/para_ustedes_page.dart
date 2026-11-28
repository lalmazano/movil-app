import 'package:flutter/material.dart';

import '../../../core/tmdb/tmdb_client.dart';
import '../../../core/widgets/iconos_club.dart';
import '../../../core/widgets/paw_background.dart';
import '../../listas/domain/item_lista.dart';
import '../domain/sugerencias.dart';
import 'tarjeta_sugerencia.dart';

/// "Para ustedes": películas recomendadas a partir de las favoritas del club,
/// en cuadrícula, con botón para agregarlas.
class ParaUstedesPage extends StatefulWidget {
  const ParaUstedesPage({
    super.key,
    required this.repository,
    required this.apiKey,
    this.categoriaInicial,
  });

  final ListaRepository repository;
  final String apiKey;

  /// Categoría propuesta al agregar.
  final String? categoriaInicial;

  @override
  State<ParaUstedesPage> createState() => _ParaUstedesPageState();
}

class _ParaUstedesPageState extends State<ParaUstedesPage> {
  late final _items = widget.repository.watch(TipoLista.peliculas);
  late Future<List<Sugerencia>> _sugerencias = _cargar();

  Future<List<Sugerencia>> _cargar() async {
    final items = await widget.repository.watch(TipoLista.peliculas).first;
    final cliente = TmdbClient.crear(widget.apiKey);
    try {
      return await sugerenciasParaUstedes(cliente, items);
    } finally {
      cliente.cerrar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const TituloSeccion(Secciones.sugerencias, 'Para ustedes'),
      ),
      body: PawBackground(
        child: FutureBuilder<List<Sugerencia>>(
          future: _sugerencias,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return _Mensaje(
                texto: switch (snap.error) {
                  TmdbException(:final mensaje) => mensaje,
                  _ => 'No se pudieron cargar las sugerencias',
                },
                onReintentar: () => setState(() => _sugerencias = _cargar()),
              );
            }
            final sugerencias = snap.data!;
            if (sugerencias.isEmpty) {
              return const _Mensaje(
                texto:
                    'Aún no hay sugerencias.\nVinculen y califiquen algunas '
                    'películas con TMDB para recibir recomendaciones.',
              );
            }
            return StreamBuilder<List<ItemLista>>(
              stream: _items,
              builder: (context, items) => LayoutBuilder(
                builder: (context, restricciones) {
                  const margen = 12.0, espacio = 10.0;
                  final util = restricciones.maxWidth - margen * 2;
                  final columnas = (util / 120).floor().clamp(3, 8);
                  final ancho = (util - espacio * (columnas - 1)) / columnas;
                  return GridView.builder(
                    padding: const EdgeInsets.all(margen),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columnas,
                      mainAxisExtent: ancho * 1.5 + 68,
                      crossAxisSpacing: espacio,
                      mainAxisSpacing: espacio,
                    ),
                    itemCount: sugerencias.length,
                    itemBuilder: (context, i) {
                      final r = sugerencias[i].resultado;
                      return TarjetaSugerencia(
                        resultado: r,
                        ancho: ancho,
                        enLista: yaEnLista(r, items.data ?? const []),
                        onAgregar: () => agregarSugerencia(
                          context,
                          repository: widget.repository,
                          resultado: r,
                          categoriaInicial: widget.categoriaInicial,
                        ),
                      );
                    },
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Mensaje extends StatelessWidget {
  const _Mensaje({required this.texto, this.onReintentar});

  final String texto;
  final VoidCallback? onReintentar;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(texto, textAlign: TextAlign.center),
          if (onReintentar != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onReintentar,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ],
      ),
    ),
  );
}
