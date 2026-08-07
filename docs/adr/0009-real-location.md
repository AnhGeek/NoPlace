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

### The service is necessary, not sufficient

Shipping it showed that the service starting is only the first of three things
that have to hold for a walk with the screen off to be recorded whole. The other
two are outside `geolocator` and are handled in `MainActivity` behind one method
channel, rather than by adding a permissions plugin for three calls:

1. **The notification has to be postable.** From Android 13 that is a runtime
   permission. A foreground service whose notification is suppressed still runs,
   but it runs unannounced — and unannounced is the state in which the system is
   most willing to reclaim it. Asked for at the same moment as location, before
   the stream is subscribed, because the notification is posted the instant it
   is.
2. **The process must not be dozed.** Doze and the OEM battery managers —
   Samsung's "sleeping apps", MIUI's battery saver — freeze an unexempted app
   minutes after the screen goes off. This is not a dropped fix; it is a stopped
   isolate, and it is the exact shape of "the fog stopped recording in my
   pocket". The app asks for the exemption from a dismissible card on the map,
   and works without it.

And one rule follows from the service rather than being another prerequisite:
**a stream error while the app is hidden must not be answered by
re-subscribing.** Cancelling the position stream stops the foreground service,
and from Android 12 a backgrounded app is not allowed to start one again — so
the obvious repair is what would end the walk for good. `cancelOnError` is
already false, so the stream may recover on its own; if it does not, the restart
is held until the next resume. `test/data/location_background_test.dart` pins
all four cases.

Availability is modelled as states — `ready`, `serviceDisabled`, `denied`,
`deniedForever` — not as an error, because each one has a different remedy and
the player can act on all of them. `LocationBanner` shows the matching sentence
and the one button that fixes it, and an `AppLifecycleListener` re-checks on
resume so returning from Settings does not land on the same banner.

**A resume refreshes the position but not the camera.** It does two things:
repair whatever broke while we were away, and ask the OS where the phone is
*now* via `refreshPosition`. Waiting for the stream is not good enough — it only
speaks after the player has moved the distance filter, and a phone that was
frozen in a pocket or closed on another street comes back with the marker
sitting where it was left. The current fix is asked for rather than the last
known one: on a resume the cached fix can be older than something the stream has
already delivered, and a stale position landing on top of a fresh one walks the
marker backwards.

Moving the camera is deliberately *not* part of that. Opening the app is the
player asking where they are, and the first real fix answers it at the opening
zoom. Flicking back from a message is not the same question — they are returning
to a map they had already put where they wanted it, and re-centring at the
opening zoom throws that away every time they glance at a notification. The
fresh fix still moves the camera while `_following` is on, at the zoom they
chose; `RecentreButton` is how somebody who wants the jump asks for it.

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
- **Two permissions the player can refuse without breaking anything.** Refusing
  the notification leaves the service running unannounced; refusing the battery
  exemption leaves the walk at the mercy of the OEM. Both are worth having and
  neither is a gate.
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
