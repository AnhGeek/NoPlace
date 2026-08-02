# State management

Riverpod 3. Three kinds of provider, and a rule about which state belongs where.

## Who owns what

| Kind of state | Lives in | Example |
| --- | --- | --- |
| Server / world state | `StreamProvider` over a repository | `playerProvider`, `placesProvider` |
| Derived, synchronous | `Provider` | `checkInCandidatesProvider` |
| UI state a rebuild must survive | `Notifier` | `mapScopeProvider`, `logFilterProvider` |
| UI state nothing else can see | `State` of the widget | which alternative the check-in sheet is targeting |
| An action in flight | `AsyncNotifier` | `checkInControllerProvider` |

The last row is the one people get wrong. A `Future` kicked off in `onPressed`
gives you double taps and a pending state that disappears on rebuild. An
`AsyncNotifier` gives you both for free.

## Read models

Screens never watch a repository. They watch a read model in
`data/repository_providers.dart`:

```dart
final playerProvider = StreamProvider<Player>((ref) {
  return ref.watch(playerRepositoryProvider).watchPlayer();
});
```

Keeping the stream wiring in one file means a screen is a pure function of
state, which is why the widget tests are four lines long.

## Loading and errors

Every `AsyncValue` goes through `NpAsyncView`, so there is one spinner and one
error state in the whole product:

```dart
NpAsyncView<List<Place>>(
  value: ref.watch(placesProvider),
  data: (places) => …,
)
```

`skipLoadingOnReload` is on: a refresh keeps showing the old data instead of
blanking the screen.

## Selectors

Watch the narrowest thing you need:

```dart
final streak = ref.watch(playerProvider.select((p) => p.value?.streakDays ?? 0));
```

The check-in sheet rebuilds when the streak changes, not when XP does.

## Rules

1. **No `BuildContext` in a controller.** Controllers return values and set
   state; the widget decides what to show.
2. **No business rules in widgets.** "First visits pay double" lives in
   `domain/rules/`, not in a `Text`.
3. **Providers are declared next to what they serve** — read models in
   `data/repository_providers.dart`, feature UI state in the feature folder.
4. **Never `ref.read` in `build`.** `watch` in build, `read` in callbacks.
5. **One-shot results are consumed, not observed.** `lastCheckInResultProvider`
   has a `take()` that clears it, so a rebuild cannot replay the district
   celebration.

## Testing

Override the composition root, not the screen:

```dart
await tester.pumpApp(
  const ProfileScreen(),
  overrides: [playerRepositoryProvider.overrideWithValue(FakePlayerRepository(store))],
);
```

Because the fakes are real state machines, most tests need no overrides at all —
the default `ProviderScope` already gives a seeded, working world.
