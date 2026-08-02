# 0009 — Real location, via a foreground service and not background permission

**Status:** Accepted · 2026-08-02

## Context

Until now `FakeWorldStore` emitted one fixed position (Bến Thành). Everything
the product claims — "walking is what uncovers it" — was therefore unproven, and
the fog could not open because nobody ever moved.

Real location on Android has one decision in it that matters more than the code:
people walk with the phone in a pocket and the screen off, so the process has to
keep receiving fixes while it is not visible. There are two ways to get that, and
they have very different consequences for whether the app can ship.

| | What it is | Cost |
| --- | --- | --- |
| `ACCESS_BACKGROUND_LOCATION` | Location with no UI at all | A Play Console declaration and a policy review, routinely refused unless the core feature is impossible without it |
| A foreground service typed `location` | Location while a persistent notification is showing | A foreground-service-type declaration; no background-location review |

## Decision

**A location foreground service, started while the app is visible, on
while-in-use permission.** `ACCESS_BACKGROUND_LOCATION` is deliberately not
declared.

This works because of the shape of the product: the player opens NoPlace and
*then* walks. The service therefore always starts in the foreground, which is
the case Android allows without background-location permission. We never need to
start tracking from the background, which is the only thing that permission buys.

`geolocator` (MIT) provides both, through `AndroidSettings.foregroundNotificationConfig`.
On iOS the equivalent is `UIBackgroundModes: location` plus
`allowBackgroundLocationUpdates`, again on while-in-use rather than "Always".

Availability is modelled as states — `ready`, `serviceDisabled`, `denied`,
`deniedForever` — not as an error, because each one has a different remedy and
the player can act on all of them. `LocationBanner` shows the matching sentence
and the one button that fixes it, and an `AppLifecycleListener` re-checks on
resume so returning from Settings does not land on the same banner.

## Consequences

- **The permission we ask for is the one people grant.** "While using the app"
  has far higher acceptance than "All the time", and we never have to justify
  the latter to a reviewer.
- **The notification is not a workaround, it is the point.** An app quietly
  recording your position with nothing on screen is exactly what it exists to
  prevent. Ours says what it is doing.
- **A wake lock is held for the length of a walk.** Without it a pocketed phone
  sleeps and the trail comes back with holes in it. It is a real battery cost,
  and it only runs while the service does.
- **Refusing is not fatal.** The banner is not a dialog: a player who says no
  still has their old trail, their points and the map. Blocking them behind a
  modal is how an app gets uninstalled.
- **Three frozen-position bugs surfaced immediately**, all invisible while the
  position never changed: `watchNearbyPlaces` recomputed on the *places* stream
  (emitted once, never again), `distanceToPlaceProvider` read the store instead
  of watching the position, and the camera used `initialCenter` only, so the
  marker walked off a stationary map. All three are fixed and the first has a
  regression test.
- Verified on a Galaxy S8+ (Android 9): permission prompt, foreground service
  running (`isForeground=true`) with its notification, a real fix in Gò Vấp, the
  camera following it, and the fog opening over real streets.

## What would change our mind

- **Tracking without the app being opened first.** A "we noticed you walked
  today" feature genuinely needs `ACCESS_BACKGROUND_LOCATION`, and then the Play
  declaration is unavoidable and has to be argued on its merits.
- **The notification being unacceptable to the product.** There is no version of
  this without it, short of the permission above.
- **Battery.** If a long walk costs too much, the answer is a coarser
  `distanceFilter` or the platform's activity-recognition APIs, not a looser
  permission.

## Known gaps

- The foreground notification's text is English only. It is set in the data
  layer, which has no `BuildContext`, so localising it needs the strings passed
  in from above.
- Following the camera is unconditional: panning away snaps back on the next
  fix. The proper answer is a follow/free toggle with a recentre button, which
  is a design decision rather than a default to guess at.
