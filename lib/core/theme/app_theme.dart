import 'package:flutter/material.dart';

/// Paleta "michi": naranja atigrado, rosa de naricita y crema.
abstract final class MichiColors {
  static const Color naranja = Color(0xFFF28C38);
  static const Color rosa = Color(0xFFF7A1B5);
  static const Color crema = Color(0xFFFFF4E6);
  static const Color cafe = Color(0xFF5D4037);
  static const Color noche = Color(0xFF2B2320);
}

/// Tema central de la aplicación (Material 3) con estilo gatuno.
abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: MichiColors.naranja,
          brightness: brightness,
        ).copyWith(
          primary: isDark ? const Color(0xFFFFB77C) : MichiColors.naranja,
          secondary: MichiColors.rosa,
          surface: isDark ? MichiColors.noche : MichiColors.crema,
        );
    final rounded = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
    );
    final onAppBar = isDark ? MichiColors.noche : Colors.white;
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: scheme.primary,
        foregroundColor: onAppBar,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        titleTextStyle: TextStyle(
          color: onAppBar,
          fontSize: 22,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
      cardTheme: CardThemeData(shape: rounded, elevation: 2),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
