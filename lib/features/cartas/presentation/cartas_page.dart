import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/paw_background.dart';
import '../../listas/presentation/config_scope.dart';
import '../../musica/domain/cancion.dart';
import '../../musica/presentation/reproductor.dart';
import '../../musica/presentation/widgets_musica.dart';
import '../domain/cartas_repository.dart';
import 'formato_cartas.dart';

/// Aviso cuando la bandera `cartas` está apagada.
class _CartasDesactivadas extends StatelessWidget {
  const _CartasDesactivadas();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('🖋️ Cartas')),
    body: const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Las cartas están desactivadas',
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );
}

void _avisar(BuildContext context, String mensaje) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(mensaje)));
}

/// Lista de sobres: cerrados (🔒 con cuenta regresiva), listos para abrir y
/// ya abiertos.
class CartasPage extends StatefulWidget {
  const CartasPage({super.key, required this.cartas});

  final CartasRepository cartas;

  @override
  State<CartasPage> createState() => _CartasPageState();
}

class _CartasPageState extends State<CartasPage> {
  Stream<List<Carta>>? _stream;

  /// Refresca las cuentas regresivas cada minuto.
  Timer? _tic;

  CartasRepository get _repo => widget.cartas;

  @override
  void initState() {
    super.initState();
    _tic = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tic?.cancel();
    super.dispose();
  }

  Future<void> _escribir() async {
    final guardada = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EscribirCartaPage(cartas: _repo)),
    );
    if (guardada == true && mounted) {
      _avisar(context, 'Carta guardada 💌');
    }
  }

  void _abrir(Carta carta) {
    final ahora = _repo.ahora();
    if (!carta.esDe(_repo.uidActual) && carta.bloqueadaEn(ahora)) {
      _avisar(
        context,
        '🔒 Se abre el ${fechaCorta(carta.abrirEn)} a las '
        '${horaCorta(carta.abrirEn)} · ${faltan(carta.abrirEn.difference(ahora))}',
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LeerCartaPage(cartas: _repo, carta: carta),
      ),
    );
  }

  Future<void> _borrar(Carta carta) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: const Text('¿Borrar carta?'),
        content: Text('"${carta.titulo}" se borrará para siempre.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogo, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogo, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.borrar(carta);
    } catch (e) {
      if (mounted) _avisar(context, e is CartaError ? e.mensaje : '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ConfigClubScope.of(context).cartas) {
      return const _CartasDesactivadas();
    }
    return Scaffold(
      appBar: AppBar(title: const Text('🖋️ Cartas')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _escribir,
        icon: const Icon(Icons.edit),
        label: const Text('Escribir carta'),
      ),
      body: PawBackground(
        child: StreamBuilder<List<Carta>>(
          stream: _stream ??= _repo.watch(),
          builder: (context, snap) {
            if (snap.hasError) {
              return const Center(
                child: Text('No se pudieron cargar las cartas 😿'),
              );
            }
            final cartas = snap.data;
            if (cartas == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (cartas.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Aún no hay cartas.\nEscribe una para que se abra en un '
                    'día especial 💌',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                for (final carta in cartas)
                  _Sobre(
                    key: ValueKey(carta.id),
                    carta: carta,
                    ahora: _repo.ahora(),
                    mia: carta.esDe(_repo.uidActual),
                    onTap: () => _abrir(carta),
                    onBorrar: () => _borrar(carta),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Un sobre en la lista.
class _Sobre extends StatelessWidget {
  const _Sobre({
    super.key,
    required this.carta,
    required this.ahora,
    required this.mia,
    required this.onTap,
    required this.onBorrar,
  });

  final Carta carta;
  final DateTime ahora;
  final bool mia;
  final VoidCallback onTap;
  final VoidCallback onBorrar;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final cerrada = carta.bloqueadaEn(ahora);
    final lista = !mia && !cerrada && !carta.abierta;
    final (emoji, estado) = switch ((cerrada, carta.abierta)) {
      (true, _) => (
        '🔒',
        'Se abre el ${fechaCorta(carta.abrirEn)} · '
            '${faltan(carta.abrirEn.difference(ahora))}',
      ),
      (false, true) => (
        '📖',
        mia
            ? 'La abrió el ${fechaCorta(carta.abiertaEn!)}'
            : 'Abierta el ${fechaCorta(carta.abiertaEn!)}',
      ),
      (false, false) => (
        '💌',
        mia ? 'Ya se puede abrir · aún sin abrir' : '¡Ya puedes abrirla!',
      ),
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: lista ? scheme.secondaryContainer : null,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
        onTap: onTap,
        onLongPress: mia ? onBorrar : null,
        leading: Text(emoji, style: const TextStyle(fontSize: 28)),
        title: Text(
          carta.titulo,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: textTheme.titleMedium,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(mia ? 'Escrita por ti' : 'De ${carta.de.nombreCorto}'),
            Text(
              estado,
              style: lista
                  ? TextStyle(
                      fontWeight: FontWeight.bold,
                      color: scheme.onSecondaryContainer,
                    )
                  : null,
            ),
          ],
        ),
        trailing: mia
            ? PopupMenuButton<String>(
                tooltip: 'Opciones',
                onSelected: (_) => onBorrar(),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'borrar',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline),
                      title: Text('Borrar'),
                    ),
                  ),
                ],
              )
            : null,
      ),
    );
  }
}

/// Muestra el texto de una carta como una hoja de papel. Si quien la lee no
/// es quien la escribió, la marca como abierta. Si trae canción (y la
/// bandera `cartasMusica` está activa), la muestra debajo y suena la muestra
/// de 30 s una vez al abrirla.
class LeerCartaPage extends StatefulWidget {
  const LeerCartaPage({super.key, required this.cartas, required this.carta});

  final CartasRepository cartas;
  final Carta carta;

  @override
  State<LeerCartaPage> createState() => _LeerCartaPageState();
}

class _LeerCartaPageState extends State<LeerCartaPage> {
  late final Future<ContenidoCarta> _contenido = _cargar();

  /// Se guarda al inicio para detenerlo al salir aunque cambie la instancia.
  final _reproductor = Reproductor.instancia;

  /// La canción que sonó sola al abrir (solo una vez).
  Cancion? _sonoSola;

  Future<ContenidoCarta> _cargar() async {
    final contenido = await widget.cartas.leerContenido(widget.carta);
    // Si falla marcarla, igual se muestra (p. ej. sin conexión).
    unawaited(
      widget.cartas.marcarAbierta(widget.carta).catchError((Object e) {
        debugPrint('No se pudo marcar la carta como abierta: $e');
      }),
    );
    return contenido;
  }

  /// Reproduce la muestra una sola vez, después de dibujar la carta.
  void _autoplay(Cancion cancion) {
    if (_sonoSola != null || cancion.previewUrl == null) return;
    _sonoSola = cancion;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _reproductor.actual != cancion) {
        unawaited(_reproductor.alternar(cancion));
      }
    });
  }

  @override
  void dispose() {
    final cancion = _sonoSola;
    if (cancion != null && _reproductor.actual == cancion) {
      unawaited(_reproductor.detener());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!ConfigClubScope.of(context).cartas) {
      return const _CartasDesactivadas();
    }
    final carta = widget.carta;
    final conMusica = ConfigClubScope.of(context).cartasMusica;
    final textTheme = Theme.of(context).textTheme;
    const tinta = MichiColors.cafe;
    return Scaffold(
      appBar: AppBar(title: const Text('💌 Carta')),
      body: PawBackground(
        child: FutureBuilder<ContenidoCarta>(
          future: _contenido,
          builder: (context, snap) {
            if (snap.hasError) {
              final e = snap.error;
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    e is CartaError ? e.mensaje : 'No se pudo leer la carta',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final cancion = conMusica ? snap.data!.cancion : null;
            if (cancion != null) _autoplay(cancion);
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBF2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: MichiColors.rosa, width: 1.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        carta.titulo,
                        style: textTheme.headlineSmall?.copyWith(
                          color: tinta,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Para abrir el ${fechaCorta(carta.abrirEn)}',
                        style: textTheme.bodySmall?.copyWith(color: tinta),
                      ),
                      const Divider(height: 28, color: MichiColors.rosa),
                      SelectableText(
                        snap.data!.texto,
                        style: textTheme.bodyLarge?.copyWith(
                          color: tinta,
                          height: 1.6,
                          fontFamily: 'serif',
                        ),
                      ),
                      const SizedBox(height: 24),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Con cariño, ${carta.de.nombreCorto} 💌',
                          style: textTheme.titleMedium?.copyWith(
                            color: tinta,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (cancion != null) ...[
                  const SizedBox(height: 16),
                  _CancionDeLaCarta(cancion: cancion, de: carta.de.nombreCorto),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// La canción que acompaña a la carta: portada, título, artista, muestra y
/// "Escuchar completa".
class _CancionDeLaCarta extends StatelessWidget {
  const _CancionDeLaCarta({required this.cancion, required this.de});

  final Cancion cancion;
  final String de;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    const tinta = MichiColors.cafe;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MichiColors.rosa, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🎵 $de te dedicó una canción',
            style: textTheme.labelLarge?.copyWith(color: tinta),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              PortadaCancion(cancion: cancion, lado: 64),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cancion.titulo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium?.copyWith(
                        color: tinta,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      cancion.artista,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(color: tinta),
                    ),
                  ],
                ),
              ),
              BotonPreview(cancion: cancion, tamano: 36),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => mostrarAbrirCancion(context, cancion),
              icon: const Icon(Icons.headphones),
              label: const Text('Escuchar completa'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Formulario para escribir una carta. Devuelve `true` al guardarla.
class EscribirCartaPage extends StatefulWidget {
  const EscribirCartaPage({super.key, required this.cartas});

  final CartasRepository cartas;

  @override
  State<EscribirCartaPage> createState() => _EscribirCartaPageState();
}

class _EscribirCartaPageState extends State<EscribirCartaPage> {
  final _form = GlobalKey<FormState>();
  final _titulo = TextEditingController();
  final _texto = TextEditingController();

  /// Por defecto: mañana a la medianoche.
  late DateTime _abrirEn = () {
    final hoy = widget.cartas.ahora();
    return DateTime(hoy.year, hoy.month, hoy.day + 1);
  }();

  var _guardando = false;

  /// Canción opcional para acompañar la carta.
  Cancion? _cancion;

  /// Se guarda al inicio para detener la muestra al salir.
  final _reproductor = Reproductor.instancia;

  @override
  void dispose() {
    _titulo.dispose();
    _texto.dispose();
    if (_cancion != null && _reproductor.actual == _cancion) {
      unawaited(_reproductor.detener());
    }
    super.dispose();
  }

  Future<void> _elegirCancion() async {
    final cancion = await mostrarBuscadorCanciones(
      context,
      titulo: '🎵 Una canción para tu carta',
    );
    if (cancion != null && mounted) setState(() => _cancion = cancion);
  }

  void _quitarCancion() {
    if (_reproductor.actual == _cancion) unawaited(_reproductor.detener());
    setState(() => _cancion = null);
  }

  Future<void> _elegirFecha() async {
    final hoy = widget.cartas.ahora();
    final fecha = await showDatePicker(
      context: context,
      initialDate: _abrirEn.isBefore(hoy) ? hoy : _abrirEn,
      firstDate: DateTime(hoy.year, hoy.month, hoy.day),
      lastDate: DateTime(hoy.year + 20),
      helpText: '¿Qué día se abre?',
    );
    if (fecha == null) return;
    setState(
      () => _abrirEn = DateTime(
        fecha.year,
        fecha.month,
        fecha.day,
        _abrirEn.hour,
        _abrirEn.minute,
      ),
    );
  }

  Future<void> _elegirHora() async {
    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_abrirEn),
      helpText: '¿A qué hora se abre?',
    );
    if (hora == null) return;
    setState(
      () => _abrirEn = DateTime(
        _abrirEn.year,
        _abrirEn.month,
        _abrirEn.day,
        hora.hour,
        hora.minute,
      ),
    );
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    if (!_abrirEn.isAfter(widget.cartas.ahora())) {
      _avisar(context, 'La fecha para abrirla debe ser en el futuro');
      return;
    }
    setState(() => _guardando = true);
    try {
      await widget.cartas.crear(
        titulo: _titulo.text,
        texto: _texto.text,
        abrirEn: _abrirEn,
        cancion: ConfigClubScope.of(context).cartasMusica ? _cancion : null,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      _avisar(
        context,
        e is CartaError ? e.mensaje : 'No se pudo guardar la carta: $e',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ConfigClubScope.of(context).cartas) {
      return const _CartasDesactivadas();
    }
    final futuro = _abrirEn.isAfter(widget.cartas.ahora());
    final conMusica = ConfigClubScope.of(context).cartasMusica;
    final scheme = Theme.of(context).colorScheme;
    final cancion = _cancion;
    return Scaffold(
      appBar: AppBar(title: const Text('✍️ Escribir carta')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _titulo,
              maxLength: maxTituloCarta,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Título',
                hintText: 'Para nuestro aniversario',
              ),
              validator: (v) => (v ?? '').trim().isEmpty
                  ? 'Ponle un título a la carta'
                  : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _texto,
              maxLength: maxTextoCarta,
              minLines: 6,
              maxLines: 14,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Carta',
                alignLabelWithHint: true,
                hintText: 'Escribe lo que quieras decirle…',
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'La carta está vacía' : null,
            ),
            if (conMusica) ...[
              Card(
                margin: const EdgeInsets.only(bottom: 12),
                clipBehavior: Clip.antiAlias,
                child: cancion == null
                    ? ListTile(
                        leading: const Text(
                          '🎵',
                          style: TextStyle(fontSize: 24),
                        ),
                        title: const Text('Agregar una canción'),
                        subtitle: const Text(
                          'Será sorpresa hasta que abra la carta',
                        ),
                        trailing: const Icon(Icons.add),
                        onTap: _elegirCancion,
                      )
                    : FilaCancion(
                        cancion: cancion,
                        onTap: _elegirCancion,
                        trailing: IconButton(
                          tooltip: 'Quitar canción',
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.close),
                          onPressed: _quitarCancion,
                        ),
                      ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Se podrá abrir desde:',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _elegirFecha,
                    icon: const Icon(Icons.calendar_month),
                    label: Text(fechaCorta(_abrirEn)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _elegirHora,
                    icon: const Icon(Icons.schedule),
                    label: Text(horaCorta(_abrirEn)),
                  ),
                ),
              ],
            ),
            if (!futuro) ...[
              const SizedBox(height: 8),
              Text(
                'Elige una fecha en el futuro',
                style: TextStyle(color: scheme.error),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _guardando ? null : _guardar,
              icon: const Icon(Icons.mail),
              label: const Text('Guardar carta'),
            ),
          ],
        ),
      ),
    );
  }
}
