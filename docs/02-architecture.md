# Architecture

## The shape

Four layers, one direction of dependency. Anything pointing the other way is a
bug, not a style choice.

```
┌──────────────────────────────────────────────────────────────┐
│ features/            screens, controllers, feature widgets   │
│                      may import: design_system, domain, core │
├──────────────────────────────────────────────────────────────┤
│ design_system/       components + theme + generated tokens    │
│                      may import: nothing of ours but tokens   │
├──────────────────────────────────────────────────────────────┤
│ data/                repository implementations, providers    │
│                      may import: domain, core                 │
├──────────────────────────────────────────────────────────────┤
│ domain/              entities, repository contracts, rules    │
│                      may import: nothing (pure Dart)          │
└──────────────────────────────────────────────────────────────┘
      core/            cross-cutting helpers (formatting, async, ui)
      app/             wiring: router, shell, root widget
```

Read it as four sentences:

- **domain** knows the game and nothing about Flutter.
- **data** knows where the game state comes from.
- **design_system** knows how things look and nothing about the game.
- **features** compose the two, and are the only layer allowed to know both.

## Why this, and not "clean architecture" with use-case classes

A use-case class per action (`CheckInUseCase`, `GetNearbyPlacesUseCase`) buys
indirection we would not use: there is one consumer per action and the rules are
three lines long. The rules that *are* shared — check-in radius, first-visit
multiplier — live in `domain/rules/exploration_rules.dart`, where both the data
layer and the UI read the same number.

When a rule grows past "a constant and a comparison", it becomes a class in
`domain/`. Not before.

## The dependency seam

`data/repository_providers.dart` is the composition root: the only file naming a
concrete implementation. Today those are the in-memory fakes; tomorrow they are
HTTP clients. Tests override the same providers.

```dart
final worldRepositoryProvider = Provider<WorldRepository>((ref) {
  return FakeWorldRepository(ref.watch(fakeWorldStoreProvider));
});
```

Nothing in `features/` imports `data/fake/`. A screen asks for
`ref.watch(playerProvider)` and does not know — or care — where the player came
from.

`data/local/` is the same idea for storage that is genuinely device-local rather
than a stand-in for a server: the walked fog trail lives there and will keep
living there after the API arrives. See
[adr/0005](adr/0005-tile-caching-and-fog-persistence.md).

## Why streams

Position, XP and quest progress all change while a screen is open. A `Future`
would force every screen to re-fetch on a hunch. Repositories therefore return
`Stream`s, and the fakes replay their latest value on subscribe
(`core/async/replay_subject.dart`), so screens paint real data on their first
frame instead of flashing a spinner.

## Feature anatomy

```
features/check_in/
└── presentation/
    ├── check_in_controller.dart   # AsyncNotifier: idle → in flight → result
    └── check_in_sheet.dart        # the screen + its private widgets
```

A feature gets a `data/` or `domain/` folder of its own only when it owns state
nobody else can see. Shared entities live in the top-level `domain/`, because
"place" and "district" mean the same thing on all four tabs.

## Navigation

`go_router` with a `StatefulShellRoute.indexedStack`: each tab keeps its own
navigation stack and its own scroll and camera position. Route paths and names
live in `app/router/routes.dart` — screens never write a path literal.

Modal sheets are pushed on the **root** navigator (`showNpModalSheet`), so the
bottom navigation bar cannot draw over them.

## Where new code goes

| You are adding… | It goes in… |
| --- | --- |
| A new screen | `features/<feature>/presentation/` |
| A widget two screens share | `design_system/components/` |
| A colour, size or duration | `design/tokens/*.json`, then regenerate |
| A new entity or a game rule | `domain/` |
| An API call | `data/remote/` + a provider swap in `repository_providers.dart` |
| A string | `lib/l10n/arb/app_en.arb`, then `app_vi.arb` |
| A formatting helper | `core/formatting/` |
