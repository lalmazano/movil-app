import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/widgets/club_logo.dart';
import '../../../core/widgets/paw_background.dart';
import '../../auth/domain/auth_service.dart';
import '../../listas/domain/config_club.dart';
import '../../listas/domain/item_lista.dart';
import '../data/widget_inicio.dart';
import 'contador_aniversario.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.repository, this.auth, this.reloj});

  final ListaRepository repository;

  /// null = modo local, sin sesión.
  final AuthService? auth;

  /// Para pruebas: qué día es "hoy" en el contador del aniversario.
  final DateTime Function()? reloj;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final _config = widget.repository.watchConfig();

  /// Mantiene al día el widget de Android (no hace nada en otras plataformas).
  late final _widgetInicio = WidgetInicio(widget.repository);

  Object? _errorInicial;

  @override
  void initState() {
    super.initState();
    _inicializar();
    _widgetInicio.iniciar();
  }

  @override
  void dispose() {
    _widgetInicio.dispose();
    super.dispose();
  }

  /// La primera vez crea la configuración, el club y los datos iniciales.
  Future<void> _inicializar() async {
    if (_errorInicial != null) setState(() => _errorInicial = null);
    try {
      await widget.repository.inicializar();
    } catch (e) {
      debugPrint('No se pudo inicializar el club: $e');
      if (mounted) setState(() => _errorInicial = e);
    }
  }

  ListaRepository get repository => widget.repository;
  AuthService? get auth => widget.auth;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final usuario = auth?.actual;
    return Scaffold(
      appBar: AppBar(title: const Text('🫘 ${AppConstants.appName}')),
      body: PawBackground(
        // Una sola suscripción a la configuración para el contador y las listas.
        child: StreamBuilder<ConfigClub>(
          stream: _config,
          builder: (context, snap) {
            // Mientras carga (o si falla) se muestran todas las listas.
            final visibles = snap.data?.listasVisibles ?? TipoLista.values;
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: switch (auth) {
                    final auth? => _FotoPerfil(auth: auth, usuario: usuario),
                    null => const ClubLogo(),
                  },
                ),
                const SizedBox(height: 12),
                Text(
                  usuario == null
                      ? 'Bienvenidos al club'
                      : '¡Hola, ${usuario.nombreCorto}!',
                  textAlign: TextAlign.center,
                  style: textTheme.headlineSmall,
                ),
                if (snap.data?.aniversario case final aniversario?) ...[
                  const SizedBox(height: 8),
                  ContadorAniversario(desde: aniversario, reloj: widget.reloj),
                ],
                if (_errorInicial case final error?) ...[
                  const SizedBox(height: 12),
                  _AvisoError(error: error, onReintentar: _inicializar),
                ],
                if (!repository.enLaNube) ...[
                  const SizedBox(height: 12),
                  const _AvisoModoLocal(),
                ],
                const SizedBox(height: 16),
                if (visibles.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No hay listas visibles por ahora 🫘',
                      textAlign: TextAlign.center,
                      style: textTheme.titleMedium,
                    ),
                  )
                else
                  for (final tipo in visibles)
                    _TarjetaLista(
                      key: ValueKey(tipo),
                      tipo: tipo,
                      repository: repository,
                    ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Foto de perfil de Google en el círculo central. Al tocarla se abre la
/// cuenta (correo y cerrar sesión). Sin foto, muestra el logo del club.
class _FotoPerfil extends StatelessWidget {
  const _FotoPerfil({required this.auth, required this.usuario});

  final AuthService auth;
  final Usuario? usuario;

  static const _radio = 64.0;

  /// Google entrega la foto a 96 px; se pide más grande para que no se vea
  /// borrosa en el círculo.
  static String _enAltaResolucion(String url) =>
      url.replaceFirst(RegExp(r'=s\d+-c$'), '=s400-c');

  void _abrirCuenta(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.account_circle),
              title: Text(usuario?.nombre ?? 'Cuenta'),
              subtitle: usuario?.correo == null ? null : Text(usuario!.correo!),
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Cerrar sesión'),
              onTap: () {
                Navigator.pop(sheet);
                auth.salir();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final foto = usuario?.fotoUrl;
    final color = Theme.of(context).colorScheme.secondary;
    return Tooltip(
      message: 'Cuenta',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => _abrirCuenta(context),
        child: foto == null
            ? const ClubLogo(radio: _radio)
            : CircleAvatar(
                radius: _radio,
                backgroundColor: color.withValues(alpha: 0.35),
                child: ClipOval(
                  child: Image.network(
                    _enAltaResolucion(foto),
                    width: _radio * 2,
                    height: _radio * 2,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const ClubLogo(radio: _radio),
                  ),
                ),
              ),
      ),
    );
  }
}

class _TarjetaLista extends StatefulWidget {
  const _TarjetaLista({
    super.key,
    required this.tipo,
    required this.repository,
  });

  final TipoLista tipo;
  final ListaRepository repository;

  @override
  State<_TarjetaLista> createState() => _TarjetaListaState();
}

class _TarjetaListaState extends State<_TarjetaLista> {
  late final _items = widget.repository.watch(widget.tipo);

  @override
  Widget build(BuildContext context) {
    final tipo = widget.tipo;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () =>
            Navigator.of(context).pushNamed(AppRoutes.lista, arguments: tipo),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: StreamBuilder<List<ItemLista>>(
            stream: _items,
            builder: (context, snap) {
              final items = snap.data ?? const <ItemLista>[];
              final hechos = items.where((i) => i.hecho).length;
              return Row(
                children: [
                  Text(tipo.emoji, style: const TextStyle(fontSize: 40)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tipo.titulo, style: textTheme.titleLarge),
                        const SizedBox(height: 4),
                        Text(
                          items.isEmpty
                              ? 'Lista vacía'
                              : '$hechos de ${items.length} ${tipo.hechos}',
                          style: textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: items.isEmpty ? 0 : hechos / items.length,
                            minHeight: 8,
                          ),
                        ),
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

class _AvisoModoLocal extends StatelessWidget {
  const _AvisoModoLocal();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          '☁️ Modo local: Firebase no está configurado, así que los cambios '
          'no se guardan en la nube.',
          style: TextStyle(color: scheme.onErrorContainer),
        ),
      ),
    );
  }
}

class _AvisoError extends StatelessWidget {
  const _AvisoError({required this.error, required this.onReintentar});

  final Object error;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final estilo = TextStyle(color: scheme.onErrorContainer);
    return Card(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '⚠️ No se pudo preparar el club. Revisa que las reglas de '
              'Firestore estén publicadas.',
              style: estilo.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            SelectableText('$error', style: estilo.copyWith(fontSize: 12)),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onReintentar,
                child: const Text('Reintentar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
