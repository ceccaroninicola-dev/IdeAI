import 'package:flutter/material.dart';

/// Configurazione dei temi dell'applicazione.
/// Stile moderno e minimal ispirato al design Apple.
/// Colore primario: verde teal (#0D9488).
class AppTheme {
  // Colori principali — teal come accento primario
  static const Color _teal = Color(0xFF0D9488);
  static const Color _tealLight = Color(0xFF14B8A6);
  static const Color _tealDark = Color(0xFF0F766E);

  // Colori light mode (stile Apple)
  static const Color _sfondoChiaro = Color(0xFFFFFFFF);
  static const Color _superficieChiara = Color(0xFFF5F5F7);
  static const Color _testoChiaro = Color(0xFF1D1D1F);
  static const Color _testoSecondarioChiaro = Color(0xFF86868B);

  // Colori dark mode (stile Apple)
  static const Color _sfondoScuro = Color(0xFF000000);
  static const Color _superficieScura = Color(0xFF1C1C1E);
  static const Color _testoScuro = Color(0xFFF5F5F7);
  static const Color _testoSecondarioScuro = Color(0xFF98989D);

  /// Tema chiaro (light mode) — stile Apple con teal
  static ThemeData temaChiaro = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: _sfondoChiaro,
    colorScheme: const ColorScheme.light(
      primary: _teal,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFE0F5F3),
      onPrimaryContainer: _tealDark,
      secondary: _tealLight,
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFE0F5F3),
      onSecondaryContainer: _tealDark,
      tertiary: _tealDark,
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFE0F5F3),
      onTertiaryContainer: _tealDark,
      surface: _sfondoChiaro,
      onSurface: _testoChiaro,
      onSurfaceVariant: _testoSecondarioChiaro,
      surfaceContainerLow: _superficieChiara,
      surfaceContainerHighest: Color(0xFFE8E8ED),
      outline: Color(0xFFD2D2D7),
      outlineVariant: Color(0xFFE8E8ED),
    ),

    // Tipografia pulita — usa il font di sistema (SF Pro su iOS, Roboto su Android)
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: _testoChiaro,
      ),
      headlineSmall: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        color: _testoChiaro,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: _testoChiaro,
      ),
      titleMedium: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: _testoChiaro,
      ),
      bodyLarge: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w400,
        color: _testoChiaro,
      ),
      bodyMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: _testoChiaro,
      ),
      bodySmall: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: _testoSecondarioChiaro,
      ),
      labelMedium: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: _testoSecondarioChiaro,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: _testoSecondarioChiaro,
      ),
    ),

    // AppBar — stile pulito, senza elevazione
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: _sfondoChiaro,
      foregroundColor: _testoChiaro,
      titleTextStyle: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: _testoChiaro,
        letterSpacing: -0.2,
      ),
    ),

    // Bottoni elevati — teal pieno, bordi morbidi
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _teal,
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0xFFE8E8ED),
        disabledForegroundColor: _testoSecondarioChiaro,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    // Bottoni outlined — bordo teal, sfondo trasparente
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: _teal,
        side: const BorderSide(color: _teal, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    // Bottoni di testo
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: _teal,
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    // Card — ombra sottile, senza bordo
    cardTheme: CardThemeData(
      elevation: 0,
      color: _superficieChiara,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      margin: EdgeInsets.zero,
    ),

    // Chip — stile pulito
    chipTheme: ChipThemeData(
      backgroundColor: _superficieChiara,
      selectedColor: const Color(0xFFE0F5F3),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      labelStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    ),

    // Input — bordi morbidi
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _superficieChiara,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _teal, width: 2),
      ),
      contentPadding: const EdgeInsets.all(16),
    ),

    // Divider
    dividerTheme: const DividerThemeData(
      color: Color(0xFFE8E8ED),
      thickness: 0.5,
    ),

    // Dialog
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      backgroundColor: _sfondoChiaro,
    ),

    // SnackBar
    snackBarTheme: SnackBarThemeData(
      backgroundColor: _testoChiaro,
      contentTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 15,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );

  /// Tema scuro (dark mode) — stile Apple con nero profondo
  static ThemeData temaScuro = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: _sfondoScuro,
    colorScheme: const ColorScheme.dark(
      primary: _tealLight,
      onPrimary: Color(0xFF003731),
      primaryContainer: Color(0xFF0F3D38),
      onPrimaryContainer: Color(0xFF99F6E4),
      secondary: _tealLight,
      onSecondary: Color(0xFF003731),
      secondaryContainer: Color(0xFF0F3D38),
      onSecondaryContainer: Color(0xFF99F6E4),
      tertiary: _teal,
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFF0F3D38),
      onTertiaryContainer: Color(0xFF99F6E4),
      surface: _sfondoScuro,
      onSurface: _testoScuro,
      onSurfaceVariant: _testoSecondarioScuro,
      surfaceContainerLow: _superficieScura,
      surfaceContainerHighest: Color(0xFF2C2C2E),
      outline: Color(0xFF48484A),
      outlineVariant: Color(0xFF38383A),
    ),

    // Tipografia — usa il font di sistema, colori scuri
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: _testoScuro,
      ),
      headlineSmall: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        color: _testoScuro,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: _testoScuro,
      ),
      titleMedium: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: _testoScuro,
      ),
      bodyLarge: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w400,
        color: _testoScuro,
      ),
      bodyMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: _testoScuro,
      ),
      bodySmall: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: _testoSecondarioScuro,
      ),
      labelMedium: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: _testoSecondarioScuro,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: _testoSecondarioScuro,
      ),
    ),

    // AppBar — sfondo nero, testo chiaro
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: _sfondoScuro,
      foregroundColor: _testoScuro,
      titleTextStyle: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: _testoScuro,
        letterSpacing: -0.2,
      ),
    ),

    // Bottoni elevati — teal, bordi morbidi
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _teal,
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0xFF2C2C2E),
        disabledForegroundColor: _testoSecondarioScuro,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    // Bottoni outlined
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: _tealLight,
        side: const BorderSide(color: _tealLight, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    // Bottoni di testo
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: _tealLight,
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    // Card — superficie scura rialzata
    cardTheme: CardThemeData(
      elevation: 0,
      color: _superficieScura,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      margin: EdgeInsets.zero,
    ),

    // Chip
    chipTheme: ChipThemeData(
      backgroundColor: _superficieScura,
      selectedColor: const Color(0xFF0F3D38),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      labelStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    ),

    // Input
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _superficieScura,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _tealLight, width: 2),
      ),
      contentPadding: const EdgeInsets.all(16),
    ),

    // Divider
    dividerTheme: const DividerThemeData(
      color: Color(0xFF38383A),
      thickness: 0.5,
    ),

    // Dialog
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      backgroundColor: _superficieScura,
    ),

    // SnackBar
    snackBarTheme: SnackBarThemeData(
      backgroundColor: _testoScuro,
      contentTextStyle: const TextStyle(
        color: Colors.black,
        fontSize: 15,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
