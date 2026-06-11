/// "Fresh Court" design tokens — white + tennis-ball green.
///
/// The design language comes from a tennis ball on a fresh white court:
/// clean white surfaces, deep green linework, and one thing that pops —
/// the optic ball green. Yellow-green never appears twice in the same
/// viewport at equal weight: it marks the single most important element.
library;

import 'package:flutter/material.dart';

abstract final class RcColors {
  /// App background — fresh court white.
  static const court = Color(0xFFFFFFFF);

  /// Cards, sheets — faint grass tint.
  static const courtRaised = Color(0xFFF4F7F0);

  /// Primary text and linework — deep court green-black.
  static const line = Color(0xFF13241B);

  /// Secondary text, captions.
  static const lineDim = Color(0xFF5F7367);

  /// THE accent: tennis-ball optic green. Fills, arcs, charts, CTA
  /// backgrounds only — never small text on white (contrast).
  static const ball = Color(0xFFBFD730);

  /// Accent for text/icons on white where ball-green would fail contrast.
  static const ballText = Color(0xFF2E7D32);

  /// Errors / "needs work" only.
  static const clay = Color(0xFFC4684A);

  /// Borders, dividers, inactive states.
  static const net = Color(0xFFDCE5D8);
}

abstract final class RcType {
  static const display = TextStyle(
    fontFamily: 'Archivo Black',
    fontSize: 44,
    height: 1.05,
    letterSpacing: -0.44,
    color: RcColors.line,
  );

  static const title = TextStyle(
    fontFamily: 'Archivo Black',
    fontSize: 28,
    height: 1.1,
    letterSpacing: -0.28,
    color: RcColors.line,
  );

  static const heading = TextStyle(
    fontFamily: 'Archivo Black',
    fontSize: 20,
    height: 1.15,
    letterSpacing: -0.2,
    color: RcColors.line,
  );

  static const body = TextStyle(
    fontFamily: 'Inter',
    fontSize: 16,
    height: 1.4,
    color: RcColors.line,
  );

  static const bodyDim = TextStyle(
    fontFamily: 'Inter',
    fontSize: 16,
    height: 1.4,
    color: RcColors.lineDim,
  );

  static const caption = TextStyle(
    fontFamily: 'Inter',
    fontSize: 13,
    height: 1.3,
    color: RcColors.lineDim,
  );

  /// Numbers only — scores, timers, counts. Tabular figures.
  static const stat = TextStyle(
    fontFamily: 'JetBrains Mono',
    fontSize: 16,
    fontWeight: FontWeight.w500,
    fontFeatures: [FontFeature.tabularFigures()],
    color: RcColors.line,
  );

  static const statHero = TextStyle(
    fontFamily: 'JetBrains Mono',
    fontSize: 56,
    fontWeight: FontWeight.w500,
    height: 1.0,
    fontFeatures: [FontFeature.tabularFigures()],
    color: RcColors.ballText,
  );
}

/// 4dp grid; screen padding 20dp; 2dp corner radius everywhere — court
/// lines are not rounded and neither is this app.
abstract final class RcDims {
  static const screenPadding = 20.0;
  static const radius = 2.0;
  static const hairline = 1.0;
}

ThemeData buildRallyCoachTheme() {
  const radius = BorderRadius.all(Radius.circular(RcDims.radius));
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: RcColors.court,
    fontFamily: 'Inter',
    colorScheme: ColorScheme.fromSeed(
      seedColor: RcColors.ballText,
      brightness: Brightness.light,
      surface: RcColors.court,
      primary: RcColors.ballText,
      secondary: RcColors.ball,
      error: RcColors.clay,
    ),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: RcColors.line,
      displayColor: RcColors.line,
    ),
    dividerTheme: const DividerThemeData(
      color: RcColors.net,
      thickness: RcDims.hairline,
      space: RcDims.hairline,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: RcColors.court,
      foregroundColor: RcColors.line,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: RcType.heading,
    ),
    cardTheme: const CardThemeData(
      color: RcColors.courtRaised,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: radius),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: RcColors.line,
      contentTextStyle: TextStyle(fontFamily: 'Inter', color: RcColors.court),
      shape: RoundedRectangleBorder(borderRadius: radius),
    ),
  );
}
