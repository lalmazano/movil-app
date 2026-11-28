import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_constants.dart';
import '../../listas/domain/config_club.dart';
import '../../listas/domain/item_lista.dart';
import '../../listas/presentation/config_scope.dart';
import '../../listas/presentation/widgets/huellitas.dart';
import '../domain/resumen_anual.dart';

/// Cómo se comparte la imagen (PNG) del resumen junto con un texto.
typedef CompartirResumen = Future<void> Function(Uint8List png, String texto);

/// Comparte con la hoja del sistema (share_plus).
Future<void> compartirConSistema(Uint8List png, String texto) async {
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(png, mimeType: 'image/png')],
      fileNameOverrides: const ['resumen-club-del-frijol.png'],
      text: texto,
    ),
  );
}

/// Degradados cálidos de las páginas (se repiten en orden).
const paletasResumen = [
  [Color(0xFFF28C38), Color(0xFFF7A1B5)],
  [Color(0xFFE8505B), Color(0xFFF9A26C)],
  [Color(0xFFB5487A), Color(0xFFF28C38)],
  [Color(0xFFE55039), Color(0xFFF6B93B)],
  [Color(0xFF5D4037), Color(0xFFF28C38)],
  [Color(0xFFF7A1B5), Color(0xFFB5487A)],
];

/// Resumen del año tipo "Wrapped": una historia vertical, una cifra por
/// página, y al final una tarjeta para compartir.
class ResumenPage extends StatefulWidget {
  const ResumenPage({
    super.key,
    required this.repository,
    this.reloj,
    this.compartir,
  });

  final ListaRepository repository;

  /// Para pruebas: qué día es "hoy" (año por defecto).
  final DateTime Function()? reloj;

  /// Para pruebas; por defecto [compartirConSistema].
  final CompartirResumen? compartir;

  @override
  State<ResumenPage> createState() => _ResumenPageState();
}

class _ResumenPageState extends State<ResumenPage> {
  final _items = <TipoLista, List<ItemLista>>{};
  final _subs = <StreamSubscription<List<ItemLista>>>[];
  final _controller = PageController();
  final _claveTarjeta = GlobalKey();
  int? _anio;
  var _pagina = 0;
  var _compartiendo = false;

  @override
  void initState() {
    super.initState();
    for (final tipo in TipoLista.values) {
      _subs.add(
        widget.repository
            .watch(tipo)
            .listen(
              (items) {
                if (mounted) setState(() => _items[tipo] = items);
              },
              onError: (Object e) {
                debugPrint('No se pudo leer ${tipo.coleccion}: $e');
                if (mounted) setState(() => _items[tipo] = const []);
              },
            ),
      );
    }
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _controller.dispose();
    super.dispose();
  }

  void _elegirAnio(int anio) {
    if (_controller.hasClients) _controller.jumpToPage(0);
    setState(() {
      _anio = anio;
      _pagina = 0;
    });
  }

  Future<void> _compartir(ResumenAnual resumen, ConfigClub config) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _compartiendo = true);
    try {
      final boundary =
          _claveTarjeta.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final imagen = await boundary.toImage(pixelRatio: 3);
      final datos = await imagen.toByteData(format: ui.ImageByteFormat.png);
      imagen.dispose();
      if (datos == null) throw StateError('No se pudo crear la imagen');
      await (widget.compartir ?? compartirConSistema)(
        datos.buffer.asUint8List(),
        textoParaCompartir(resumen, config),
      );
    } catch (e) {
      debugPrint('No se pudo compartir el resumen: $e');
      messenger.showSnackBar(
        const SnackBar(content: Text('No se pudo compartir 😿')),
      );
    } finally {
      if (mounted) setState(() => _compartiendo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ConfigClubScope.of(context);
    final visibles = config.listasVisibles;
    final cargando = visibles.any((t) => !_items.containsKey(t));
    final actual = (widget.reloj ?? DateTime.now)().year;

    List<ItemLista> de(TipoLista t) =>
        config.esVisible(t) ? _items[t] ?? const [] : const [];

    final anios = aniosConDatos([for (final t in visibles) ...de(t)]);
    final anio =
        _anio ??
        (anios.isEmpty || anios.contains(actual) ? actual : anios.first);
    final opciones = {actual, ...anios}.toList()
      ..sort((a, b) => b.compareTo(a));

    final Widget cuerpo;
    if (!config.resumen) {
      cuerpo = const _Mensaje('El resumen anual está desactivado 🫘');
    } else if (visibles.isEmpty) {
      cuerpo = const _Mensaje('No hay listas visibles por ahora 🫘');
    } else if (cargando) {
      cuerpo = const Center(child: CircularProgressIndicator());
    } else {
      final resumen = calcularResumen(
        anio,
        de(TipoLista.peliculas),
        de(TipoLista.deseos),
        de(TipoLista.planes),
      );
      final paginas = _paginas(resumen, config);
      cuerpo = Stack(
        children: [
          PageView.builder(
            key: ValueKey(anio),
            controller: _controller,
            scrollDirection: Axis.vertical,
            itemCount: paginas.length,
            onPageChanged: (p) => setState(() => _pagina = p),
            itemBuilder: (context, i) => _PaginaHistoria(
              colores: paletasResumen[i % paletasResumen.length],
              pista: i == 0 && paginas.length > 1,
              child: paginas[i],
            ),
          ),
          if (paginas.length > 1)
            Positioned(
              right: 10,
              top: 0,
              bottom: 0,
              child: _Indicador(total: paginas.length, actual: _pagina),
            ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('🎁 Su año en el club'),
        actions: [
          if (config.resumen && opciones.length > 1)
            PopupMenuButton<int>(
              key: const Key('selector-anio'),
              tooltip: 'Elegir año',
              initialValue: anio,
              onSelected: _elegirAnio,
              itemBuilder: (_) => [
                for (final a in opciones)
                  PopupMenuItem(value: a, child: Text('$a')),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [Text('$anio'), const Icon(Icons.arrow_drop_down)],
                ),
              ),
            ),
        ],
      ),
      body: cuerpo,
    );
  }

  List<Widget> _paginas(ResumenAnual r, ConfigClub config) {
    if (r.vacio) {
      return [
        _Cifra(
          emoji: '🫘',
          titulo: 'Su ${r.anio} en el club',
          detalle:
              'Aún no hay recuerdos este año.\n¡Marquen algo como hecho y '
              'aquí aparecerá su resumen!',
        ),
      ];
    }
    final visibles = config.listasVisibles;
    final mejor = config.calificaciones && r.mejores.isNotEmpty
        ? r.mejores.first
        : null;
    final recuerdos = [
      if (config.calificaciones && r.totalCalificaciones > 0)
        'Repartieron ${_plural(r.totalCalificaciones, 'calificación', 'calificaciones')} 🐾',
      if (config.fotos && r.fotos > 0)
        'Guardaron ${_plural(r.fotos, 'foto', 'fotos')} de recuerdo 📸',
    ];
    return [
      _Cifra(
        emoji: '🎁',
        titulo: 'Su ${r.anio} en el club',
        detalle: 'Hicieron ${_plural(r.total, 'cosa', 'cosas')} juntos 💛',
        extra: Column(
          children: [
            for (final t in visibles)
              Text(
                '${t.emoji} ${textoTotal(t, r.totalDe(t))}',
                style: _estiloExtra,
              ),
          ],
        ),
      ),
      for (final t in visibles)
        if (r.totalDe(t) > 0) _paginaLista(t, r, config),
      if (mejor != null)
        _Cifra(
          emoji: '🏆',
          titulo:
              'Su mejor calificada: ${mejor.item.titulo} 🐾 '
              '${mejor.item.promedioHuellitas!.toStringAsFixed(1)}',
          extra: r.mejores.length > 1
              ? Column(
                  children: [
                    for (final (i, l) in r.mejores.indexed)
                      _FilaMejor(
                        puesto: i + 1,
                        logro: l,
                        posters: config.posters,
                      ),
                  ],
                )
              : null,
        ),
      if (r.categoriaFavorita case final cat?)
        _Cifra(
          emoji: '💖',
          titulo: 'Su categoría favorita: $cat',
          detalle:
              '${_plural(r.vecesCategoriaFavorita, 'cosa', 'cosas')} '
              'de $cat este año',
        ),
      if (r.mesMasActivo case final mes?)
        _Cifra(
          emoji: '📅',
          titulo: '${nombreMes(mes)} fue su mes más activo',
          detalle:
              'con ${_plural(r.vecesMesMasActivo, 'cosa hecha', 'cosas hechas')}',
        ),
      if (recuerdos.isNotEmpty)
        _Cifra(
          emoji: '📸',
          titulo: recuerdos.first,
          detalle: recuerdos.length > 1 ? recuerdos.last : null,
        ),
      if (config.autores && r.marcadoPor.isNotEmpty)
        _Cifra(emoji: '😼', titulo: 'Dato curioso', detalle: _datoCurioso(r)),
      if (r.primero case final primero?)
        _Cifra(
          emoji: '🌅',
          titulo: 'Empezaron con ${primero.item.titulo}',
          detalle: r.total > 1
              ? 'el ${_fecha(primero.fecha)}… y cerraron con '
                    '${r.ultimo!.item.titulo} el ${_fecha(r.ultimo!.fecha)} 🌙'
              : 'el ${_fecha(primero.fecha)}',
        ),
      Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: RepaintBoundary(
                key: _claveTarjeta,
                child: TarjetaFinalResumen(resumen: r, config: config),
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const Key('boton-compartir-resumen'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFFB5487A),
            ),
            onPressed: _compartiendo ? null : () => _compartir(r, config),
            icon: const Icon(Icons.share),
            label: const Text('Compartir'),
          ),
        ],
      ),
    ];
  }

  Widget _paginaLista(TipoLista t, ResumenAnual r, ConfigClub config) {
    final n = r.totalDe(t);
    return switch (t) {
      TipoLista.peliculas => _Cifra(
        emoji: '🎬',
        titulo: 'Vieron ${_plural(n, 'película', 'películas')} juntos',
        detalle: '¡Palomitas para todo el año! 🍿',
      ),
      TipoLista.deseos => _Cifra(
        emoji: '🌠',
        titulo: 'Cumplieron ${_plural(n, 'deseo', 'deseos')}',
        detalle: 'Cada uno, un sueño hecho realidad ✨',
      ),
      TipoLista.planes => _Cifra(
        emoji: '🧺',
        titulo: 'Hicieron ${_plural(n, 'plan', 'planes')} juntos',
        detalle: config.repetibles && r.repeticiones > 0
            ? 'y repitieron sus favoritos '
                  '${_plural(r.repeticiones, 'vez', 'veces')} 🔁'
            : 'Juntos todo es mejor 💛',
      ),
    };
  }
}

/// "Luis marcó más cosas" o empate.
String _datoCurioso(ResumenAnual r) {
  if (r.quienMarcoMas case MapEntry(key: final nombre, value: final n)) {
    return r.marcadoPor.length == 1
        ? '$nombre marcó todo: ${_plural(n, 'cosa', 'cosas')} ✅'
        : '$nombre marcó más cosas: $n ✅';
  }
  return '¡Empate! Marcaron ${r.marcadoPor.values.first} cosas cada uno 🤝';
}

String _plural(int n, String uno, String varios) =>
    '$n ${n == 1 ? uno : varios}';

String _fecha(DateTime f) => '${f.day} de ${nombreMes(f.month).toLowerCase()}';

/// "3 películas vistas", "1 deseo cumplido", "2 planes hechos".
String textoTotal(TipoLista tipo, int n) => switch (tipo) {
  TipoLista.peliculas => _plural(n, 'película vista', 'películas vistas'),
  TipoLista.deseos => _plural(n, 'deseo cumplido', 'deseos cumplidos'),
  TipoLista.planes => _plural(n, 'plan hecho', 'planes hechos'),
};

/// Texto que acompaña la imagen al compartir.
String textoParaCompartir(ResumenAnual r, ConfigClub config) {
  final partes = [
    for (final t in config.listasVisibles) textoTotal(t, r.totalDe(t)),
  ];
  final lista = partes.length > 1
      ? '${partes.sublist(0, partes.length - 1).join(', ')} y ${partes.last}'
      : partes.join();
  return '🎁 Nuestro ${r.anio} en ${AppConstants.appName}: $lista 💛';
}

const _estiloExtra = TextStyle(color: Colors.white, fontSize: 18, height: 1.6);

/// Fondo con degradado de cada página de la historia.
class _PaginaHistoria extends StatelessWidget {
  const _PaginaHistoria({
    required this.colores,
    required this.child,
    this.pista = false,
  });

  final List<Color> colores;
  final Widget child;
  final bool pista;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colores,
      ),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 24, 36, 16),
        child: Column(
          children: [
            Expanded(child: Center(child: child)),
            if (pista)
              const Text(
                'Desliza hacia arriba ↑',
                style: TextStyle(color: Colors.white70),
              ),
          ],
        ),
      ),
    ),
  );
}

/// Una cifra grande con emoji y texto corto.
class _Cifra extends StatelessWidget {
  const _Cifra({
    required this.emoji,
    required this.titulo,
    this.detalle,
    this.extra,
  });

  final String emoji;
  final String titulo;
  final String? detalle;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 72)),
          const SizedBox(height: 16),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (detalle case final d?) ...[
            const SizedBox(height: 12),
            Text(
              d,
              textAlign: TextAlign.center,
              style: textTheme.titleMedium?.copyWith(color: Colors.white),
            ),
          ],
          if (extra case final e?) ...[const SizedBox(height: 20), e],
        ],
      ),
    );
  }
}

class _FilaMejor extends StatelessWidget {
  const _FilaMejor({
    required this.puesto,
    required this.logro,
    required this.posters,
  });

  final int puesto;
  final LogroAnual logro;
  final bool posters;

  @override
  Widget build(BuildContext context) {
    final url = posters ? logro.item.pelicula?.posterUrl : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$puesto.', style: _estiloExtra),
          const SizedBox(width: 8),
          if (url != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(
                url,
                width: 28,
                height: 42,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              '${logro.item.titulo} · '
              '${promedioTexto(logro.item.promedioHuellitas!)} 🐾',
              overflow: TextOverflow.ellipsis,
              style: _estiloExtra,
            ),
          ),
        ],
      ),
    );
  }
}

/// Puntitos verticales que indican la página actual.
class _Indicador extends StatelessWidget {
  const _Indicador({required this.total, required this.actual});

  final int total;
  final int actual;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (var i = 0; i < total; i++)
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(vertical: 3),
          width: 6,
          height: i == actual ? 18 : 6,
          decoration: BoxDecoration(
            color: i == actual ? Colors.white : Colors.white54,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
    ],
  );
}

class _Mensaje extends StatelessWidget {
  const _Mensaje(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        texto,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    ),
  );
}

/// Tarjeta final con todo junto; es la imagen que se comparte.
class TarjetaFinalResumen extends StatelessWidget {
  const TarjetaFinalResumen({
    super.key,
    required this.resumen,
    required this.config,
  });

  final ResumenAnual resumen;
  final ConfigClub config;

  @override
  Widget build(BuildContext context) {
    final r = resumen;
    final mejor = config.calificaciones && r.mejores.isNotEmpty
        ? r.mejores.first.item
        : null;
    final filas = <(String, String)>[
      for (final t in config.listasVisibles)
        (t.emoji, textoTotal(t, r.totalDe(t))),
      if (mejor != null)
        (
          '🏆',
          '${mejor.titulo} · ${promedioTexto(mejor.promedioHuellitas!)} 🐾',
        ),
      if (r.categoriaFavorita case final cat?) ('💖', cat),
      if (r.mesMasActivo case final mes?) ('📅', nombreMes(mes)),
      if (config.calificaciones && r.totalCalificaciones > 0)
        (
          '🐾',
          _plural(r.totalCalificaciones, 'calificación', 'calificaciones'),
        ),
      if (config.fotos && r.fotos > 0)
        ('📸', _plural(r.fotos, 'foto', 'fotos')),
    ];
    return Container(
      width: 320,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF28C38), Color(0xFFE8505B), Color(0xFFB5487A)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.white, fontSize: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🫘 ${AppConstants.appName}',
              style: TextStyle(fontSize: 14, color: Colors.white70),
            ),
            const SizedBox(height: 4),
            Text(
              'Nuestro ${r.anio} 🎁',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text('${_plural(r.total, 'cosa', 'cosas')} juntos 💛'),
            const Divider(color: Colors.white54, height: 24),
            for (final (emoji, texto) in filas)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(width: 32, child: Text(emoji)),
                    Expanded(
                      child: Text(
                        texto,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
