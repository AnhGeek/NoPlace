import 'package:flutter/material.dart';

import '../tokens/design_tokens.g.dart';

/// The type ramp, built once from the tokens.
///
/// Screens should reach for a named role (`NpTypography.title`) rather than
/// composing a `TextStyle` by hand; a style that does not exist here is a
/// design question, not a code question.
abstract final class NpTypography {
  const NpTypography._();

  static const TextStyle _base = TextStyle(
    fontFamily: NpFontFamily.sans,
    color: NpColors.contentPrimary,
    height: NpLineHeight.normal,
    letterSpacing: NpTracking.normal,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// All-caps section kicker: "NEW DISTRICT DISCOVERED".
  static const TextStyle overline = TextStyle(
    fontFamily: NpFontFamily.sans,
    fontSize: NpFontSize.overline,
    fontWeight: NpFontWeight.semibold,
    letterSpacing: NpTracking.widest,
    height: NpLineHeight.snug,
    color: NpColors.contentMuted,
  );

  /// Tab labels — same size as [overline] but tracked a little tighter.
  static const TextStyle tabLabel = TextStyle(
    fontFamily: NpFontFamily.sans,
    fontSize: NpFontSize.bodyLarge,
    fontWeight: NpFontWeight.semibold,
    letterSpacing: NpTracking.wide,
    height: NpLineHeight.snug,
    color: NpColors.contentMuted,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: NpFontFamily.sans,
    fontSize: NpFontSize.caption,
    fontWeight: NpFontWeight.regular,
    height: NpLineHeight.snug,
    color: NpColors.contentMuted,
  );

  static const TextStyle footnote = TextStyle(
    fontFamily: NpFontFamily.sans,
    fontSize: NpFontSize.footnote,
    fontWeight: NpFontWeight.regular,
    height: NpLineHeight.snug,
    color: NpColors.contentMuted,
  );

  static const TextStyle footnoteStrong = TextStyle(
    fontFamily: NpFontFamily.sans,
    fontSize: NpFontSize.footnote,
    fontWeight: NpFontWeight.semibold,
    height: NpLineHeight.snug,
    color: NpColors.contentPrimary,
  );

  static const TextStyle body = TextStyle(
    fontFamily: NpFontFamily.sans,
    fontSize: NpFontSize.body,
    fontWeight: NpFontWeight.regular,
    height: NpLineHeight.normal,
    color: NpColors.contentPrimary,
  );

  static const TextStyle bodyStrong = TextStyle(
    fontFamily: NpFontFamily.sans,
    fontSize: NpFontSize.body,
    fontWeight: NpFontWeight.semibold,
    height: NpLineHeight.snug,
    color: NpColors.contentPrimary,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontFamily: NpFontFamily.sans,
    fontSize: NpFontSize.bodyLarge,
    fontWeight: NpFontWeight.regular,
    height: NpLineHeight.normal,
    color: NpColors.contentPrimary,
  );

  static const TextStyle label = TextStyle(
    fontFamily: NpFontFamily.sans,
    fontSize: NpFontSize.bodyLarge,
    fontWeight: NpFontWeight.semibold,
    height: NpLineHeight.snug,
    color: NpColors.contentPrimary,
  );

  static const TextStyle title = TextStyle(
    fontFamily: NpFontFamily.sans,
    fontSize: NpFontSize.title,
    fontWeight: NpFontWeight.bold,
    height: NpLineHeight.snug,
    color: NpColors.contentPrimary,
  );

  static const TextStyle headline = TextStyle(
    fontFamily: NpFontFamily.sans,
    fontSize: NpFontSize.headline,
    fontWeight: NpFontWeight.bold,
    height: NpLineHeight.snug,
    color: NpColors.contentPrimary,
  );

  /// Screen titles: "Explorer Logs", "Profile".
  static const TextStyle display = TextStyle(
    fontFamily: NpFontFamily.sans,
    fontSize: NpFontSize.display,
    fontWeight: NpFontWeight.bold,
    height: NpLineHeight.snug,
    color: NpColors.contentPrimary,
  );

  static const TextStyle hero = TextStyle(
    fontFamily: NpFontFamily.sans,
    fontSize: NpFontSize.hero,
    fontWeight: NpFontWeight.bold,
    height: NpLineHeight.tight,
    color: NpColors.contentPrimary,
  );

  /// Celebration numbers and the district name on the discovery screen.
  static const TextStyle stat = TextStyle(
    fontFamily: NpFontFamily.sans,
    fontSize: NpFontSize.stat,
    fontWeight: NpFontWeight.bold,
    height: NpLineHeight.tight,
    letterSpacing: NpTracking.tighter,
    color: NpColors.contentPrimary,
  );

  /// The single biggest number on screen — "38% of the city charted".
  static const TextStyle statHero = TextStyle(
    fontFamily: NpFontFamily.sans,
    fontSize: NpFontSize.statHero,
    fontWeight: NpFontWeight.bold,
    height: NpLineHeight.tight,
    letterSpacing: NpTracking.tighter,
    color: NpColors.contentPrimary,
  );

  /// Material's [TextTheme], so stock widgets inherit the ramp too.
  static const TextTheme textTheme = TextTheme(
    displayLarge: statHero,
    displayMedium: stat,
    displaySmall: hero,
    headlineMedium: display,
    headlineSmall: headline,
    titleLarge: title,
    titleMedium: label,
    titleSmall: bodyStrong,
    bodyLarge: bodyLarge,
    bodyMedium: body,
    bodySmall: footnote,
    labelLarge: bodyStrong,
    labelMedium: caption,
    labelSmall: overline,
  );

  /// Fallback used by `DefaultTextStyle` outside of Material widgets.
  static TextStyle get fallback => _base;
}
