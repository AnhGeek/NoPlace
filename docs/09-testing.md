# Testing

```bash
cd app
flutter test                    # everything
flutter test --coverage         # with lcov output
flutter analyze                 # zero issues is the merge bar
```

## What we test, and where

| Level | Lives in | Tests | Example |
| --- | --- | --- | --- |
| Pure logic | `test/domain/` | Maths and invariants | Haversine distance is symmetric |
| Rules | `test/data/` | The game's behaviour through the fake store | First visit pays double, out-of-range is refused |
| Storage | `test/data/` | Data that must survive a restart | The trail reloads after a cold start; a corrupt file does not crash launch |
| Screens | `test/features/` | What the player sees, in both languages | Logs renders the seeded history; locked rows are dimmed |
| Content | `test/l10n/` | Translations stay in sync | No untranslated, undocumented or mismatched strings |

## The three questions a test should answer

1. **Does the rule hold?** — `fake_world_store_test.dart` asserts the XP maths,
   the log entry, the district unlock and both refusal paths. When a real API
   arrives, the same expectations are the contract it has to satisfy.
2. **Does the screen say the right thing?** — widget tests assert *text the
   player reads*, not widget types. `find.text('2 / 12 districts')` breaks when
   the meaning breaks; `find.byType(Row)` breaks when someone refactors.
3. **Does it survive a small phone and a long language?** Every screen test runs
   at 390 × 844; the profile test also runs at 360 × 740 and in Vietnamese,
   because that combination is where things clip.

## Conventions

- Mount widgets with `tester.pumpApp(...)` from `test/support/pump_app.dart`. It
  installs the real theme, the real localisations and a real `ProviderScope`, so
  a test cannot pass against a setup production never uses.
- Prefer the seeded fake world over hand-built stubs. If a test needs a state
  the seed cannot produce, override the repository provider — do not add a
  back door to production code.
- Name tests as sentences about behaviour: *"a repeat visit pays the base reward
  and does not re-count"*, not *"testCheckIn2"*.

## What is not covered yet

- **Golden tests.** They are the natural next step for the design system: one
  golden per component state, run on a single fixed device profile. Not added
  yet because the visual language is still moving.
- **Integration tests.** The check-in → discovery flow is verified by hand on a
  device today. It should become an `integration_test` once the real location
  source lands, since that is the part a widget test cannot fake honestly.
- **The token generator.** Guarded in CI by
  `dart run tools/token_builder/bin/build_tokens.dart --check` rather than by a
  unit test.

## Manual device pass

Before a release, on a real phone — not a simulator:

1. All four tabs, in both languages.
2. Check-in on a place you have already visited (base reward) and a new one
   (doubled).
3. The district-discovered screen (debug shortcut: Settings → Preview).
4. System font size at maximum: nothing clipped, nothing overlapping.
5. Airplane mode on a street you have already walked: the basemap still renders
   from the tile cache, and the fog is exactly where you left it.
6. Force-stop and relaunch: the uncovered area is unchanged at the first frame,
   not filled in a moment later.
