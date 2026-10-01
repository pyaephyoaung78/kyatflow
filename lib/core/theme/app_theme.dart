import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class AppTheme {
  static const background = Color(0xFFF5F5F7);
  static const surface = Colors.white;
  static const ink = Color(0xFF1C1C1E);
  static const secondary = Color(0xFF6C6C72);
  static const line = Color(0xFFE7E7EC);
  static const accent = Color(0xFF246B55);
  static const accentSoft = Color(0xFFE8F1ED);
  static const expense = Color(0xFFBB443A);
  static const warning = Color(0xFF96600B);
  static const radius = 20.0;
  static const numbers = [FontFeature.tabularFigures()];
  static const title = TextStyle(
    fontSize: 32,
    height: 1.15,
    fontWeight: FontWeight.w700,
    letterSpacing: -1,
    color: ink,
  );
  static const section = TextStyle(
    fontSize: 19,
    height: 1.3,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
    color: ink,
  );
  static const caption = TextStyle(fontSize: 13, height: 1.4, color: secondary);
  static Duration motion(BuildContext context, [int milliseconds = 240]) =>
      MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : Duration(milliseconds: milliseconds);

  static ThemeData get light {
    final base = ThemeData(useMaterial3: true, brightness: Brightness.light);
    return base.copyWith(
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.fromSeed(seedColor: accent).copyWith(
        primary: accent,
        onPrimary: surface,
        surface: surface,
        onSurface: ink,
        error: expense,
        outline: line,
      ),
      textTheme: base.textTheme.apply(bodyColor: ink, displayColor: ink),
      cupertinoOverrideTheme: const CupertinoThemeData(
        primaryColor: accent,
        brightness: Brightness.light,
        textTheme: CupertinoTextThemeData(primaryColor: accent),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        titleTextStyle: base.textTheme.titleLarge!.copyWith(
          color: ink,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      dividerTheme: const DividerThemeData(
        color: line,
        thickness: 0.5,
        space: 1,
      ),
      splashFactory: NoSplash.splashFactory,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: surface,
          minimumSize: const Size(48, 54),
          elevation: 0,
          textStyle: base.textTheme.labelLarge!.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.all(16),
        hintStyle: const TextStyle(color: secondary, fontSize: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: accent),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
