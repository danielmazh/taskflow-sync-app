import 'package:flutter/material.dart';

/// Design tokens for TaskFlow Sync.
/// One source of truth for color, spacing, type, and shape.
class AppTheme {
  AppTheme._();

  static const Color _seed = Color(0xFF3F51B5); // Indigo 500.

  static ColorScheme get _light => ColorScheme.fromSeed(
        seedColor: _seed,
        brightness: Brightness.light,
      );

  static ColorScheme get _dark => ColorScheme.fromSeed(
        seedColor: _seed,
        brightness: Brightness.dark,
      );

  static ThemeData light() => _themeFor(_light);
  static ThemeData dark() => _themeFor(_dark);

  static ThemeData _themeFor(ColorScheme scheme) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      visualDensity: VisualDensity.standard,
    );
    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      checkboxTheme: CheckboxThemeData(
        shape: const CircleBorder(),
        side: BorderSide(width: 1.8, color: scheme.outline),
        materialTapTargetSize: MaterialTapTargetSize.padded,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      textTheme: base.textTheme.copyWith(
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          height: 1.25,
        ),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.35),
        labelLarge: base.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// 8-pt spacing scale. Use these instead of magic numbers.
class AppSpacing {
  AppSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

class AppRadius {
  AppRadius._();
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double pill = 999;
}

/// Semantic colors derived from the active ColorScheme.
/// Use these for status-bearing UI so dark/light work consistently.
extension AppColors on ColorScheme {
  /// Overdue / danger accent. Maps to the M3 error role, which has good
  /// contrast in both modes and is already the dismiss/destructive color.
  Color get danger => error;
  Color get onDanger => onError;

  /// A quieter foreground for tertiary metadata.
  Color get muted => onSurfaceVariant;
}
