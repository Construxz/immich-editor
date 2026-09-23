import 'package:flutter/material.dart';

// Das Aussehen der Immich-App (`mobile/lib/theme/`, `constants/colors.dart`, Tag v3.2.2, AGPL-3.0):
// Markenfarbe Indigo, entfärbte Flächen, Google Sans. Der Editor selbst bleibt schwarz wie bei
// Google Fotos (D-22, D-35).

const _markeHell = Color(0xFF4150AF);
const _markeDunkel = Color(0xFFACCBFA);

final _hell = ColorScheme.fromSeed(seedColor: _markeHell).copyWith(
  primary: _markeHell,
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

final _dunkel =
    ColorScheme.fromSeed(
      seedColor: _markeDunkel,
      brightness: Brightness.dark,
    ).copyWith(
      primary: _markeDunkel,
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

final themaHell = _thema(_hell);
final themaDunkel = _thema(_dunkel);

const _schrift = 'GoogleSans';

ThemeData _thema(ColorScheme farben) {
  final dunkel = farben.brightness == Brightness.dark;
  return ThemeData(
    useMaterial3: true,
    colorScheme: farben,
    primaryColor: farben.primary,
    scaffoldBackgroundColor: farben.surface,
    splashColor: farben.primary.withValues(alpha: 0.1),
    highlightColor: farben.primary.withValues(alpha: 0.1),
    fontFamily: _schrift,
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: farben.surfaceContainer,
    ),
    snackBarTheme: SnackBarThemeData(
      contentTextStyle: TextStyle(
        fontFamily: _schrift,
        color: farben.primary,
        fontWeight: FontWeight.bold,
      ),
      backgroundColor: farben.surfaceContainerHighest,
    ),
    appBarTheme: AppBarTheme(
      titleTextStyle: TextStyle(
        color: farben.primary,
        fontFamily: _schrift,
        fontWeight: FontWeight.w600,
        fontSize: 18,
      ),
      backgroundColor: farben.surface,
      foregroundColor: farben.primary,
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
        backgroundColor: farben.primary,
        foregroundColor: dunkel ? Colors.black87 : Colors.white,
      ),
    ),
    chipTheme: const ChipThemeData(side: BorderSide.none),
    popupMenuTheme: const PopupMenuThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: dunkel ? farben.surfaceContainer : farben.surface,
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
        borderSide: BorderSide(color: farben.primary),
        borderRadius: const BorderRadius.all(Radius.circular(15)),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: farben.outlineVariant),
        borderRadius: const BorderRadius.all(Radius.circular(15)),
      ),
      labelStyle: TextStyle(color: farben.primary),
      hintStyle: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.normal),
    ),
    textSelectionTheme: TextSelectionThemeData(cursorColor: farben.primary),
    dialogTheme: DialogThemeData(backgroundColor: farben.surfaceContainer),
  );
}

extension ImmichFarben on ColorScheme {
  /// Immichs zweite Textfarbe (`onSurfaceSecondary`): Text um 30 % zur Fläche hin.
  Color get onSurfaceSecondary => Color.lerp(
    onSurface,
    brightness == Brightness.dark ? Colors.black : Colors.white,
    0.3,
  )!;
}
