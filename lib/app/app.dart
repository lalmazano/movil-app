import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/constants/app_constants.dart';
import '../core/routes/app_router.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/domain/auth_service.dart';
import '../features/listas/domain/item_lista.dart';
import '../features/listas/presentation/config_scope.dart';

class ClubDelFrijolApp extends StatelessWidget {
  const ClubDelFrijolApp({super.key, required this.repository, this.auth});

  final ListaRepository repository;

  /// null = modo local, sin inicio de sesión.
  final AuthService? auth;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      // Calendarios, selectores de hora y textos del sistema en español.
      locale: const Locale('es', 'GT'),
      supportedLocales: const [Locale('es', 'GT'), Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      initialRoute: AppRoutes.home,
      onGenerateRoute: AppRouter(repository, auth: auth).onGenerateRoute,
      // Respeta el tamaño de letra del teléfono, pero sin pasar de 1.15x
      // para que botones y filtros no se corten.
      builder: (context, child) => ConfigClubProvider(
        repository: repository,
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.15,
          child: child!,
        ),
      ),
    );
  }
}
