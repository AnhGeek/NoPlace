# 0001 — Flutter and Riverpod, without code generation

**Status:** Accepted · 2026-07-30

## Context

NoPlace needs Android and iOS from day one, with a small team and a UI that is
almost entirely custom: a fog-of-war overlay, hand-drawn map pins, a navigation
bar that fades into the map. Very little of the screen is a stock platform
control, so the usual argument for native ("it feels like the OS") buys us less
than usual here.

For state, the app has genuinely reactive data — position, XP, quest progress
all change while a screen is open — and a dependency seam that has to survive
swapping in-memory fakes for a real API.

## Decision

1. **Flutter** (3.44, Dart 3.12) for both platforms.
2. **Riverpod 3** for state and dependency injection.
3. **No code generation** — no `riverpod_generator`, no `freezed`,
   no `json_serializable` yet.

Value equality comes from `equatable`; unions come from Dart's own sealed
classes, which give exhaustive `switch` at compile time:

```dart
sealed class LogEntry { … }
final class CheckInLogEntry extends LogEntry { … }
```

## Consequences

- Adding a screen is: write it, run it. No `build_runner` in the loop, no
  generated files to resolve in a rebase.
- `copyWith` and `props` are written by hand. That is the cost, and it is a real
  one — roughly ten lines per entity.
- The sealed-class `switch` in `LogEntryTile` and `QuestTile` means adding an
  entry or quest type is a compile error until the UI handles it. That property
  is worth more than the boilerplate it costs.
- Riverpod's compile-safe providers mean no `BuildContext` lookups and no
  runtime "provider not found".

## What would change our mind

- **JSON.** The moment a real API lands, hand-written `fromJson` stops being
  defensible: add `json_serializable` (and probably `freezed` with it).
- **Entity count.** Past roughly fifteen entities, the hand-written `copyWith`
  tax exceeds the cost of a `build_runner` step.
- **Team size.** With more than three or four engineers, `riverpod_generator`'s
  consistency is worth the build step.
