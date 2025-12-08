import 'package:flutter/material.dart';

class AppTheme {
  // رنگ‌های اصلی (از Stitch)
  static const Color primary = Color(0xFF13a4ec);
  static const Color backgroundLight = Color(0xFFF6F7F8);
  static const Color backgroundDark = Color(0xFF101c22);
  static const Color textDark = Color(0xFF111618);
  static const Color textLight = Color(0xFFF6F7F8);
  static const Color grey = Color(0xFF617c89);
  static const Color border = Color(0xFFDbe2e6);
  static const Color cardLight = Colors.white;
  static const Color cardDark = Color(0xFF1a2a32);

  // تم روشن
  static final ThemeData lightTheme = ThemeData(
    fontFamily: 'Plus Jakarta Sans',
    brightness: Brightness.light,
    primaryColor: primary,
    scaffoldBackgroundColor: backgroundLight,
    appBarTheme: const AppBarTheme(
      backgroundColor: backgroundLight,
      elevation: 0,
      foregroundColor: textDark,
      iconTheme: IconThemeData(color: textDark),
      titleTextStyle: TextStyle(color: textDark, fontWeight: FontWeight.bold, fontSize: 18),
    ),
    cardTheme: CardThemeData(
      color: cardLight,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: textDark),
      bodyMedium: TextStyle(color: textDark),
      titleLarge: TextStyle(color: textDark, fontWeight: FontWeight.bold),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cardLight,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
      hintStyle: TextStyle(color: grey),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: primary),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.all(Colors.white),
      trackColor: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.selected) ? primary : grey.withOpacity(0.5);
      }),
    ),
  );

  // تم تاریک
  static final ThemeData darkTheme = ThemeData(
    fontFamily: 'Plus Jakarta Sans',
    brightness: Brightness.dark,
    primaryColor: primary,
    scaffoldBackgroundColor: backgroundDark,
    appBarTheme: const AppBarTheme(
      backgroundColor: backgroundDark,
      elevation: 0,
      foregroundColor: textLight,
      iconTheme: IconThemeData(color: textLight),
      titleTextStyle: TextStyle(color: textLight, fontWeight: FontWeight.bold, fontSize: 18),
    ),
    cardTheme: CardThemeData(
      color: cardDark,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: textLight),
      bodyMedium: TextStyle(color: textLight),
      titleLarge: TextStyle(color: textLight, fontWeight: FontWeight.bold),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cardDark,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: grey.withOpacity(0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
      hintStyle: TextStyle(color: grey.withOpacity(0.7)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: primary),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.all(Colors.white),
      trackColor: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.selected) ? primary : grey.withOpacity(0.3);
      }),
    ),
  );
}