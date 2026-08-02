import 'package:flutter/widgets.dart';

import 'generated/app_localizations.dart';

export 'generated/app_localizations.dart' show AppL10n;

/// Everything the app knows about languages lives here.
///
/// Adding a language is a three-step change: drop a new `app_<code>.arb` in
/// `lib/l10n/arb/`, add the locale to [supported], and give it a label in
/// [nativeName]. Nothing else in the codebase should mention a language code.
abstract final class L10nConfig {
  /// Order matters: the first entry is the fallback when the device locale is
  /// not supported.
  static const List<Locale> supported = [Locale('en'), Locale('vi')];

  /// The language name written in that language — never translated, because a
  /// user looking for their language reads it in their own.
  static const Map<String, String> nativeName = {
    'en': 'English',
    'vi': 'Tiếng Việt',
  };

  static String labelFor(Locale locale) =>
      nativeName[locale.languageCode] ?? locale.languageCode;
}

/// `context.l10n.mapCheckIn` instead of `AppL10n.of(context).mapCheckIn`.
extension L10nContext on BuildContext {
  AppL10n get l10n => AppL10n.of(this);
}
