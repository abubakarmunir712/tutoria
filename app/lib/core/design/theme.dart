import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'tokens.dart';

/// The app's Material theme, built from the tokens in tokens.dart.
ThemeData buildTutoriaTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: TColors.blue600,
        brightness: Brightness.light,
      ).copyWith(
        primary: TColors.blue600,
        onPrimary: Colors.white,
        primaryContainer: TColors.blue100,
        onPrimaryContainer: TColors.ink,
        secondary: TColors.yellow,
        onSecondary: TColors.ink,
        tertiary: TColors.gold,
        onTertiary: TColors.ink,
        surface: TColors.white,
        onSurface: TColors.body,
        onSurfaceVariant: TColors.muted,
        outline: TColors.line,
        outlineVariant: TColors.line,
        error: TColors.danger,
        surfaceContainerLowest: TColors.white,
        surfaceContainerHighest: TColors.blue100,
      );

  final fieldBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(TRadius.md),
    borderSide: const BorderSide(color: TColors.line, width: 1.5),
  );

  return ThemeData(
    useMaterial3: true,
    fontFamily: TText.family,
    colorScheme: scheme,
    scaffoldBackgroundColor: TColors.blue50,
    splashFactory: InkSparkle.splashFactory,
    textTheme: TextTheme(
      displayLarge: TText.display,
      headlineLarge: TText.title,
      headlineMedium: TText.heading,
      titleLarge: TText.heading,
      titleMedium: TText.subheading,
      titleSmall: TText.bodyBold,
      bodyLarge: TText.body,
      bodyMedium: TText.body,
      bodySmall: TText.small,
      labelLarge: TText.button,
      labelMedium: TText.smallBold,
      labelSmall: TText.caption,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: TColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TText.heading,
      iconTheme: const IconThemeData(color: TColors.ink),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: TColors.fieldFill,
      isDense: false,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      hintStyle: TText.body.copyWith(color: TColors.faint),
      labelStyle: TText.body.copyWith(color: TColors.muted),
      prefixIconColor: TColors.muted,
      suffixIconColor: TColors.muted,
      border: fieldBorder,
      enabledBorder: fieldBorder,
      focusedBorder: fieldBorder.copyWith(
        borderSide: const BorderSide(color: TColors.blue600, width: 2),
      ),
      errorBorder: fieldBorder.copyWith(
        borderSide: const BorderSide(color: TColors.danger, width: 1.5),
      ),
      focusedErrorBorder: fieldBorder.copyWith(
        borderSide: const BorderSide(color: TColors.danger, width: 2),
      ),
      errorStyle: TText.small.copyWith(color: TColors.danger),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: TColors.blue600,
        textStyle: TText.bodyBold,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: TColors.blue100,
      labelStyle: TText.smallBold.copyWith(color: TColors.blue600),
      side: BorderSide.none,
      shape: const StadiumBorder(),
    ),
    cardTheme: CardThemeData(
      color: TColors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TRadius.lg),
        side: const BorderSide(color: TColors.line),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: TColors.line,
      thickness: 1,
      space: 1,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: TColors.blue600,
      linearTrackColor: TColors.blue100,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: TColors.ink,
      contentTextStyle: TText.body.copyWith(color: Colors.white),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TRadius.md),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: TColors.white,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TText.heading,
      contentTextStyle: TText.body,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TRadius.lg),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: TColors.white,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(TRadius.xl)),
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}
