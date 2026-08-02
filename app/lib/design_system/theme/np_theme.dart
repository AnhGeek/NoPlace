import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens/design_tokens.g.dart';
import 'np_typography.dart';

/// Builds the single [ThemeData] the app runs on.
///
/// NoPlace is a dark-only product: the map is the content, and a light chrome
/// would fight it. The tokens are already structured semantically, so adding a
/// light theme later means adding `semantic.light.json` and turning these
/// constants into a `ThemeExtension` — see docs/adr/0002-design-tokens.md.
abstract final class NpTheme {
  const NpTheme._();

  static ThemeData dark() {
    const colorScheme = ColorScheme.dark(
      primary: NpColors.accentDefault,
      onPrimary: NpColors.contentOnAccent,
      secondary: NpColors.statusInfo,
      onSecondary: NpColors.contentOnAccent,
      surface: NpColors.backgroundSurface,
      onSurface: NpColors.contentPrimary,
      surfaceContainer: NpColors.backgroundPanel,
      surfaceContainerHigh: NpColors.backgroundPanelRaised,
      outline: NpColors.borderSubtle,
      outlineVariant: NpColors.borderStrong,
      error: NpColors.statusWarning,
      onError: NpColors.contentOnAccent,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: NpColors.backgroundSurface,
      canvasColor: NpColors.backgroundSurface,
      fontFamily: NpFontFamily.sans,
      textTheme: NpTypography.textTheme,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: NpColors.backgroundSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: NpTypography.display,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: NpColors.backgroundSurface,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: NpColors.backgroundPanelRaised,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: NpColors.backgroundPanelRaised,
        modalBarrierColor: NpColors.backgroundScrim,
        showDragHandle: false,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(NpRadius.sheet),
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: NpColors.borderSubtle,
        thickness: NpBorderWidth.hairline,
        space: NpBorderWidth.hairline,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: NpColors.backgroundPanelRaised,
        contentTextStyle: NpTypography.body,
        actionTextColor: NpColors.accentDefault,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NpRadius.md),
          side: const BorderSide(color: NpColors.borderSubtle),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: NpColors.accentDefault,
        linearTrackColor: NpColors.chartTrack,
        circularTrackColor: NpColors.chartTrack,
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: NpColors.accentDefault,
        selectionColor: NpColors.accentSubtle,
        selectionHandleColor: NpColors.accentDefault,
      ),
      iconTheme: const IconThemeData(
        color: NpColors.contentMuted,
        size: NpSize.iconXl,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: NpColors.contentMuted,
        textColor: NpColors.contentPrimary,
      ),
    );
  }

  /// Status bar / navigation bar styling for screens that draw their own
  /// background behind the system bars (the map).
  static const SystemUiOverlayStyle overlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
  );
}
