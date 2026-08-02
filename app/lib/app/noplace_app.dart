import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/settings/locale_controller.dart';
import '../design_system/theme/np_theme.dart';
import '../l10n/l10n.dart';
import 'router/app_router.dart';

/// The root widget: theme, localisation, router. Nothing else belongs here.
class NoPlaceApp extends ConsumerWidget {
  const NoPlaceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final locale = ref.watch(localeControllerProvider);

    return MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.appName,
      debugShowCheckedModeBanner: false,
      theme: NpTheme.dark(),
      darkTheme: NpTheme.dark(),
      themeMode: ThemeMode.dark,
      routerConfig: router,
      locale: locale,
      supportedLocales: L10nConfig.supported,
      localizationsDelegates: const [
        AppL10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        // Cap text scaling: past 1.3 the stat tiles and the nearby card start
        // clipping, and a clipped reward is worse than a slightly smaller one.
        final scaler = MediaQuery.textScalerOf(
          context,
        ).clamp(minScaleFactor: 1, maxScaleFactor: 1.3);
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: scaler),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
