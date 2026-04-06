import 'package:flutter/material.dart';

class ThemeSchemaService {
  static Color _hex(String hex, {Color fallback = Colors.blue}) {
    final normalized = hex.replaceAll('#', '').trim();
    if (normalized.length != 6) return fallback;
    return Color(int.parse('FF$normalized', radix: 16));
  }

  static ThemeData buildTheme(Map<String, dynamic> schema) {
    final colors = (schema['colors'] as Map?)?.cast<String, dynamic>() ?? {};
    final primary = _hex(colors['primary']?.toString() ?? '#7C9EFF');
    final secondary = _hex(colors['secondary']?.toString() ?? '#80CBC4');
    final background = _hex(colors['background']?.toString() ?? '#0D1117');
    final surface = _hex(colors['surface']?.toString() ?? '#161B22');
    final error = _hex(colors['error']?.toString() ?? '#F07178');
    final mode = (schema['mode']?.toString().toLowerCase() ?? 'dark') == 'light' ? Brightness.light : Brightness.dark;

    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: mode,
      primary: primary,
      secondary: secondary,
      surface: surface,
      error: error,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: mode,
      scaffoldBackgroundColor: background,
      colorScheme: scheme,
      floatingActionButtonTheme: const FloatingActionButtonThemeData(shape: CircleBorder()),
      cardTheme: CardThemeData(
        color: surface.withOpacity(mode == Brightness.dark ? 0.78 : 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
