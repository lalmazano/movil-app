import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import '../core/routes/app_router.dart';
import '../core/theme/app_theme.dart';
import '../features/listas/domain/item_lista.dart';

class ClubDelFrijolApp extends StatelessWidget {
  const ClubDelFrijolApp({super.key, required this.repository});

  final ListaRepository repository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      initialRoute: AppRoutes.home,
      onGenerateRoute: AppRouter(repository).onGenerateRoute,
    );
  }
}
