# Localisation

The app ships in **English** and **Vietnamese**. Neither is a fallback for the
other: both are first-class, and a missing translation fails the build.

## How it is wired

- `app/l10n.yaml` configures Flutter's `gen-l10n`.
- `app/lib/l10n/arb/app_en.arb` is the **template** — every string starts here,
  with an `@`-description.
- `app/lib/l10n/arb/app_vi.arb` is the translation.
- `flutter gen-l10n` (automatic on `flutter run`) generates
  `lib/l10n/generated/app_localizations.dart`, class `AppL10n`.
- `app/lib/l10n/l10n.dart` exposes `L10nConfig.supported` and the
  `context.l10n` extension. Nothing else in the codebase mentions a language
  code.

```dart
Text(context.l10n.mapCheckIn)
Text(context.l10n.profileLevelLine(4, 340))
```

## Adding a string

1. Add the key **and its `@`-description** to `app_en.arb`. The description is
   mandatory (`required-resource-attributes: true`) — it is what a translator
   reads instead of guessing from the key.
2. Add the same key to `app_vi.arb`.
3. `flutter gen-l10n`, then use `context.l10n.yourKey`.
4. `flutter test test/l10n/arb_parity_test.dart` — it fails on a missing
   translation, a stale key, a missing description, or a placeholder that exists
   in one locale but not the other.

## Placeholders, plurals, selects

```jsonc
"commonDays": "{count, plural, =1{1 day} other{{count} days}}",
"mapNearbyMeta": "{distance} away · {visited, select, never{never visited} other{visited before}} · +{xp} XP"
```

Vietnamese has no plural inflection — a single `other{}` branch is correct, not
lazy.

**Apostrophes must be doubled** (`You''re`): with `use-escaping: true`, a single
quote is an ICU escape character and a lone one is a build error.

## Never concatenate

```dart
// wrong — word order is not universal
Text('${l10n.distance} away · ${l10n.neverVisited}');

// right — one message, the translator controls the whole sentence
Text(l10n.mapNearbyMeta(distance, 'never', xp));
```

## Numbers, dates, distances

All of it goes through `core/formatting/unit_formatter.dart`, which is locale
aware: `4.2 km` in English is `4,2 km` in Vietnamese, and weekday and time
formats follow the locale too. Never call `toStringAsFixed` in a widget.

Rules the formatter enforces, so the product reads consistently:

- under 1 km → whole metres, rounded to 10 m above 100 m ("480 m");
- 1 km and above → one decimal ("4.2 km");
- goals drop the pointless decimal ("Walk 5 km today").

## Adding a language

1. `app/lib/l10n/arb/app_<code>.arb`, translated from the template.
2. Add the locale to `L10nConfig.supported`.
3. Add its name — written in that language — to `L10nConfig.nativeName`.
4. Add the code to `CFBundleLocalizations` in `ios/Runner/Info.plist`.
5. Run the parity test.

## Layout consequences

Vietnamese runs roughly 30% longer than English. Two rules follow:

- never size a container to fit an English string;
- any line that carries a reward gets two lines, not an ellipsis — see the
  nearby card, where clipping "+100 XP" would clip the reason to tap.

The widget tests render key screens in both locales for exactly this reason.
