import 'package:flutter/material.dart';
import 'package:m3e_design/m3e_design.dart';

/// Builds the Android theme pair (light + dark).
///
/// On Android 12+ pass the wallpaper-derived [dynamicLight] and [dynamicDark]
/// schemes from [DynamicColorBuilder]. On older Android (and on desktop/iOS
/// where [DynamicColorBuilder] yields null), both will be null and the
/// [seedColor] fallback is used instead.
///
/// M3 Expressive tokens are injected via the [M3ETheme] [ThemeExtension] from
/// the `m3e_design` package. Expressive rounded shapes (from [M3EShapes.expressive])
/// are applied to card, bottom sheet, dialog, and FAB component themes.
///
/// The `flutter_m3shapes` package expressive shape widgets (e.g. [M3Container])
/// are available for custom UI components — see docs/THEME_PLATFORM_STRATEGY.md.
({ThemeData light, ThemeData dark}) buildAndroidTheme({
  ColorScheme? dynamicLight,
  ColorScheme? dynamicDark,
  required Color seedColor,
}) {
  final lightScheme =
      dynamicLight ??
      ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.light);
  final darkScheme =
      dynamicDark ??
      ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.dark);

  return (light: _buildTheme(lightScheme), dark: _buildTheme(darkScheme));
}

ThemeData _buildTheme(ColorScheme scheme) {
  // M3 Expressive shape ramp (round family, not square).
  // Values from M3EShapes.expressive(): sm=20, md=28, lg=44.
  const shapeRound = (sm: 20.0, md: 28.0);

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    cardTheme: CardThemeData(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(shapeRound.md),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(shapeRound.md),
          topRight: Radius.circular(shapeRound.md),
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(shapeRound.md),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(shapeRound.sm),
      ),
    ),
    // M3 Expressive popup/context menu: extra-small M3 shape (sm=20dp round),
    // surfaceContainer background, elevation 3 per M3 menu spec.
    popupMenuTheme: PopupMenuThemeData(
      color: scheme.surfaceContainer,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(shapeRound.sm),
      ),
    ),
  );

  // Inject the M3ETheme ThemeExtension (colors, typography, shapes, spacing,
  // motion tokens). withM3ETheme uses M3ETheme.defaults(scheme) which applies
  // M3EShapes.expressive() internally.
  return withM3ETheme(base);
}
