import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:noplace/design_system/theme/np_theme.dart';
import 'package:noplace/l10n/l10n.dart';

/// Mounts [widget] inside the same theme, localisations and provider scope the
/// real app uses.
///
/// Every widget test goes through this: a test that has to build its own
/// `MaterialApp` will drift from production and stop catching anything.
extension PumpApp on WidgetTester {
  Future<void> pumpApp(
    Widget widget, {
    List<Override> overrides = const [],
    Locale locale = const Locale('en'),
    Size surfaceSize = const Size(390, 844),
  }) async {
    view.physicalSize = surfaceSize * view.devicePixelRatio;
    view.devicePixelRatio = 1;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);

    await pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          locale: locale,
          theme: NpTheme.dark(),
          supportedLocales: L10nConfig.supported,
          localizationsDelegates: const [
            AppL10n.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(body: widget),
        ),
      ),
    );
    await pump();
  }
}
