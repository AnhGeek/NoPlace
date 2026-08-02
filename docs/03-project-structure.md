# Project structure

## Repository

```
NoPlace/
├── app/                  the Flutter application (Android + iOS)
├── design/
│   ├── tokens/           design tokens, hand-edited (source of truth)
│   └── build/            generated: tokens.css, Tokens.swift, colors.xml, …
├── docs/                 this documentation
├── landing_page/         the marketing site (Cloudflare Worker)
├── tools/
│   └── token_builder/    the token compiler (standalone Dart package)
└── map-pulse.html        the original UI study the app was built from
```

`design/` and `tools/` sit outside `app/` on purpose: the tokens describe the
brand, not the Flutter app, and the landing page consumes the same file.

## The Flutter app

```
app/lib/
├── main.dart                    entry point — one line
├── bootstrap.dart               everything that must happen before frame 1
│
├── app/
│   ├── noplace_app.dart         MaterialApp.router: theme, locale, routes
│   ├── router/
│   │   ├── app_router.dart      GoRouter + the stateful tab shell
│   │   └── routes.dart          every path and name in the app
│   └── shell/home_shell.dart    the frame around the four tabs
│
├── core/                        cross-cutting, feature-agnostic
│   ├── async/replay_subject.dart
│   ├── formatting/unit_formatter.dart
│   ├── settings/locale_controller.dart
│   └── ui/np_async_view.dart    the one loading state and one error state
│
├── design_system/
│   ├── tokens/design_tokens.g.dart   GENERATED — do not edit
│   ├── theme/                        ThemeData + the type ramp
│   ├── components/                   Np* widgets + components.dart barrel
│   └── gallery/                      debug-only live catalogue
│
├── domain/                      pure Dart, no Flutter import
│   ├── entities/                place, district, player, quest, log entry…
│   ├── repositories/            the contracts
│   └── rules/                   numbers the UI and data layer must share
│
├── data/
│   ├── fake/                    in-memory world + fake repositories
│   ├── local/                   on-device storage (the walked fog trail)
│   └── repository_providers.dart  composition root + read models
│
├── features/                    one folder per product area
│   ├── map/          check_in/   discovery/
│   ├── logs/         quests/     profile/     settings/
│
└── l10n/
    ├── arb/app_en.arb           the template — every string starts here
    ├── arb/app_vi.arb
    ├── generated/               GENERATED — do not edit
    └── l10n.dart                supported locales + `context.l10n`
```

## Tests

```
app/test/
├── support/pump_app.dart    mounts a widget with the real theme + l10n
├── domain/                  pure logic
├── data/                    the game rules, through the fake store
├── features/                one file per screen
└── l10n/arb_parity_test.dart  no untranslated or undocumented strings
```

## Two files you must not hand-edit

- `app/lib/design_system/tokens/design_tokens.g.dart` — regenerate from
  `design/tokens/`.
- `app/lib/l10n/generated/**` — regenerate with `flutter gen-l10n`.

Both are committed so a fresh clone builds without running any generator first.
