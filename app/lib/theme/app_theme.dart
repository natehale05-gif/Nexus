import 'package:flutter/material.dart';
// material.dart no longer re-exports the Cupertino route transitions, so pull
// the one builder we need in directly (a `show` clause keeps the rest of the
// Cupertino namespace from colliding with Material's).
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;

import 'tokens.dart';

ThemeData buildNexusTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: NexusColors.background,
    fontFamily: '.SF Pro Text',
    fontFamilyFallback: const ['Roboto', 'system-ui'],
    splashFactory: NoSplash.splashFactory,
    highlightColor: const Color(0x00000000),
    colorScheme: ColorScheme.fromSeed(
      seedColor: NexusColors.blue,
      brightness: Brightness.light,
      surface: NexusColors.surface,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
      },
    ),
    textSelectionTheme: const TextSelectionThemeData(cursorColor: NexusColors.blue),
  );
}
