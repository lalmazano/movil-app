import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/widgets/club_logo.dart';
import '../../../core/widgets/paw_background.dart';
import '../../auth/domain/auth_service.dart';
import '../../listas/domain/config_club.dart';
import '../../listas/domain/item_lista.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.repository, this.auth});

  final ListaRepository repository;

  /// null = modo local, sin sesión.
  final AuthService? auth;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final _config = widget.repository.watchConfig();

  ListaRepository get repository => widget.repository;
  AuthService? get auth => widget.auth;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final usuario = auth?.actual;
    return Scaffold(
      appBar: AppBar(
        title: const Text('🫘 ${AppConstants.appName}'),
        actions: [
          if (auth case final auth?) _MenuUsuario(auth: auth, usuario: usuario),
        ],
      ),
      body: PawBackground(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Center(child: ClubLogo()),
            const SizedBox(height: 12),
            Text(
              usuario == null
                  ? 'Bienvenidos al club'
                  : '¡Hola, ${usuario.nombreCorto}!',
              textAlign: TextAlign.center,
              style: textTheme.headlineSmall,
            ),
            Text(
              'Lo que queremos ver, desear y hacer juntos',
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge,
            ),
            if (!repository.enLaNube) ...[
              const SizedBox(height: 12),
              const _AvisoModoLocal(),
            ],
            const SizedBox(height: 16),
            StreamBuilder<ConfigClub>(
              stream: _config,
              builder: (context, snap) {
                // Mientras carga (o si falla) se muestran todas las listas.
                final visibles = snap.data?.listasVisibles ?? TipoLista.values;
                if (visibles.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No hay listas visibles por ahora 🫘',
                      textAlign: TextAlign.center,
                      style: textTheme.titleMedium,
                    ),
                  );
                }
                return Column(
                  children: [
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
          ],
        ),
      ),
    );
  }
}

class _MenuUsuario extends StatelessWidget {
  const _MenuUsuario({required this.auth, required this.usuario});

  final AuthService auth;
  final Usuario? usuario;

  @override
  Widget build(BuildContext context) {
    final foto = usuario?.fotoUrl;
    return PopupMenuButton<void>(
      tooltip: 'Cuenta',
      icon: CircleAvatar(
        radius: 16,
        backgroundImage: foto == null ? null : NetworkImage(foto),
        child: foto == null ? const Icon(Icons.person, size: 18) : null,
      ),
      itemBuilder: (_) => [
        PopupMenuItem<void>(
          enabled: false,
          child: Text(usuario?.correo ?? usuario?.nombre ?? ''),
        ),
        PopupMenuItem<void>(
          onTap: auth.salir,
          child: const ListTile(
            leading: Icon(Icons.logout),
            title: Text('Cerrar sesión'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
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
