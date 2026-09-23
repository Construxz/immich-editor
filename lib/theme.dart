import 'package:flutter/material.dart';

// The look of the Immich app (`mobile/lib/theme/`, `constants/colors.dart`, tag v3.2.2, AGPL-3.0):
// brand color indigo, desaturated surfaces, Google Sans. The editor itself stays black like
// Google Photos (D-22, D-35).

const _brandLight = Color(0xFF4150AF);
const _brandDark = Color(0xFFACCBFA);

final _light = ColorScheme.fromSeed(seedColor: _brandLight).copyWith(
  primary: _brandLight,
  surface: const Color(0xFFf9f9f9),
  onSurface: const Color(0xFF1b1b1b),
  surfaceContainerLowest: const Color(0xFFffffff),
  surfaceContainerLow: const Color(0xFFf3f3f3),
  surfaceContainer: const Color(0xFFeeeeee),
  surfaceContainerHigh: const Color(0xFFe8e8e8),
  surfaceContainerHighest: const Color(0xFFe2e2e2),
  surfaceDim: const Color(0xFFdadada),
  surfaceBright: const Color(0xFFf9f9f9),
  onSurfaceVariant: const Color(0xFF4c4546),
  inverseSurface: const Color(0xFF303030),
  onInverseSurface: const Color(0xFFf1f1f1),
);

final _dark =
    ColorScheme.fromSeed(
      seedColor: _brandDark,
      brightness: Brightness.dark,
    ).copyWith(
      primary: _brandDark,
      surface: const Color(0xFF131313),
      onSurface: const Color(0xFFE2E2E2),
      surfaceContainerLowest: const Color(0xFF0E0E0E),
      surfaceContainerLow: const Color(0xFF1B1B1B),
      surfaceContainer: const Color(0xFF1F1F1F),
      surfaceContainerHigh: const Color(0xFF242424),
      surfaceContainerHighest: const Color(0xFF2E2E2E),
      surfaceDim: const Color(0xFF131313),
      surfaceBright: const Color(0xFF353535),
      onSurfaceVariant: const Color(0xFFCfC4C5),
      inverseSurface: const Color(0xFFE2E2E2),
      onInverseSurface: const Color(0xFF303030),
    );

final lightTheme = _theme(_light);
final darkTheme = _theme(_dark);

const _font = 'GoogleSans';

ThemeData _theme(ColorScheme colors) {
  final dark = colors.brightness == Brightness.dark;
  return ThemeData(
    useMaterial3: true,
    colorScheme: colors,
    primaryColor: colors.primary,
    scaffoldBackgroundColor: colors.surface,
    splashColor: colors.primary.withValues(alpha: 0.1),
    highlightColor: colors.primary.withValues(alpha: 0.1),
    fontFamily: _font,
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colors.surfaceContainer,
    ),
    snackBarTheme: SnackBarThemeData(
      contentTextStyle: TextStyle(
        fontFamily: _font,
        color: colors.primary,
        fontWeight: FontWeight.bold,
      ),
      backgroundColor: colors.surfaceContainerHighest,
    ),
    appBarTheme: AppBarTheme(
      titleTextStyle: TextStyle(
        color: colors.primary,
        fontFamily: _font,
        fontWeight: FontWeight.w600,
        fontSize: 18,
      ),
      backgroundColor: colors.surface,
      foregroundColor: colors.primary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      displayMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      displaySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      titleSmall: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(fontSize: 18.0, fontWeight: FontWeight.w600),
      titleLarge: TextStyle(fontSize: 26.0, fontWeight: FontWeight.w600),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: colors.primary,
        foregroundColor: dark ? Colors.black87 : Colors.white,
      ),
    ),
    chipTheme: const ChipThemeData(side: BorderSide.none),
    popupMenuTheme: const PopupMenuThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: dark ? colors.surfaceContainer : colors.surface,
      labelTextStyle: const WidgetStatePropertyAll(
        TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: colors.primary),
        borderRadius: const BorderRadius.all(Radius.circular(15)),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: colors.outlineVariant),
        borderRadius: const BorderRadius.all(Radius.circular(15)),
      ),
      labelStyle: TextStyle(color: colors.primary),
      hintStyle: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.normal),
    ),
    textSelectionTheme: TextSelectionThemeData(cursorColor: colors.primary),
    dialogTheme: DialogThemeData(backgroundColor: colors.surfaceContainer),
  );
}

extension ImmichColors on ColorScheme {
  /// Immich's secondary text color (`onSurfaceSecondary`): text moved 30 % toward the surface.
  Color get onSurfaceSecondary => Color.lerp(
    onSurface,
    brightness == Brightness.dark ? Colors.black : Colors.white,
    0.3,
  )!;
}
