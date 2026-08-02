# NoPlace documentation

Start here. Every document below answers one question; if you cannot find the
answer in under a minute, the document is wrong — fix it in the same PR.

| Document | Answers |
| --- | --- |
| [01-product.md](01-product.md) | What is NoPlace, who is it for, what does "done" mean for a feature |
| [02-architecture.md](02-architecture.md) | How the app is layered and why, where new code goes |
| [03-project-structure.md](03-project-structure.md) | What lives in which folder |
| [04-design-system.md](04-design-system.md) | The components, and the rules for using and extending them |
| [05-design-tokens.md](05-design-tokens.md) | How one JSON file becomes Dart, CSS, Swift and Android XML |
| [06-user-flows.md](06-user-flows.md) | The screens, the states, and how the player moves between them |
| [07-localization.md](07-localization.md) | How to add a string, a language, or a plural |
| [08-state-management.md](08-state-management.md) | Providers, controllers, and who is allowed to hold state |
| [09-testing.md](09-testing.md) | What we test, at which level, and what "enough" means |
| [10-engineering-standards.md](10-engineering-standards.md) | Branches, commits, reviews, lints, CI |
| [region-pack-format.md](region-pack-format.md) | The map-data format: one SQLite file per city, tiles + places |
| [tickets/](tickets/) | Specced work not yet built |
| [adr/](adr/) | Decisions we do not want to relitigate, and what would change our mind |
| [backlog.md](backlog.md) | Known gaps in the current build, deliberately deferred |

## Quick start

```bash
cd app
flutter pub get
flutter run                 # a device or emulator must be attached
flutter test                # unit + widget tests
flutter analyze             # zero issues is the merge bar
```

Regenerating the design tokens (only after editing `design/tokens/*.json`):

```bash
dart run tools/token_builder/bin/build_tokens.dart
```

Regenerating localisations (automatic on `flutter run`; explicit when you need
the generated Dart before building):

```bash
cd app && flutter gen-l10n
```
