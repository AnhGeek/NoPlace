# 0011 — Places the player saves, and the hour that checks them in

**Status:** Accepted · 2026-08-05 · extends
[0006](0006-sqlite-storage-and-map-points.md)

## Context

Until now the player could only check into places the *world* knows about —
seven seeded `Place`s that will one day come from a places API. Their own points
existed on the map and could not be created, named, judged or returned to:
`MapPointRepository` had `add`, `update` and `remove`, and nothing called them.

What was actually wanted is smaller and more personal than the places API: save
the spot I am standing on, call it something, say how it felt, give it stars,
and tell me how many times I have been back. And — the part that is not a form —
count the times I did not tap anything, because I was sitting in it for an hour.

## Decision

### The player's place is a `MapPoint`, not a new entity

A saved place *is* the `user` kind of map point from 0006, grown five fields:
`stars`, `moodId`, `checkInCount`, `lastCheckInAt`, and the pair that tracks an
ongoing stay. Schema v3 adds them as columns with defaults, so an existing pin
keeps its name and its icon and simply arrives unrated.

The alternative — a `SavedPlace` entity beside `MapPoint` — would have meant two
things on the map that are the same thing to the player, two layer toggles, two
rows in the backup format, and a fork in every screen that draws a pin. The
split that matters is already drawn in the right place: world data on one side
(`Place`, replaceable by a refresh), the player's own content on the other
(`MapPoint`, never silently replaced).

Ratings and feelings are two fields, not one. A five-star bún chả you queued an
hour for can still have felt exhausting, and collapsing them would lose the more
interesting half.

### An hour nearby is a check-in, and nobody has to confirm it

`PlaceVisitRules` — a domain class, because the rule outgrew "a constant and a
comparison" — decides. A stay is a run of *sightings* within 150 m: the first
one starts it, each further hour of it is a check-in, and 20 minutes without one
ends it.

Three consequences of that shape, each of them a bug worth not having:

- **Leaving is never recorded.** Only fixes inside the radius are considered, so
  a single drifting fix — routine in a city — cannot wipe out fifty minutes of
  sitting still. A real departure ends the stay anyway, twenty minutes later.
- **A stay is only as long as the sightings that vouch for it.** An app killed at
  the office on Friday and opened there on Monday awards nothing. Wall-clock
  arithmetic alone would have paid out the weekend.
- **The clock ticks even when the GPS does not.** The stay is confirmed every
  five minutes from the last known position as well as on every fix. A phone
  lying on a café table stops producing fixes precisely when the feature is most
  right, and a stay measured only in fixes would go cold there.

The radius is 150 m, tighter than the 200 m check-in radius, because this one is
spent unattended: the generosity that stops a deliberate tap being refused would
otherwise hand out check-ins for the café across the road from the office.

### The stay lives in the database

`stay_started_at` and `stay_last_seen_at` are columns, not memory. An hour at a
café outlives the process — the app is frozen in a pocket routinely — and a
feature that only works with the screen on is not this feature. Writes are
throttled to one per five minutes per place, which is the same heartbeat.

A restored backup deliberately drops them: a stay is a fact about the phone that
was standing there, and replaying it onto another one would hand out an hour
nobody spent. Ratings and counts *are* restored.

## Consequences

- Schema v3, one migration of six `ADD COLUMN`s, tested against a database built
  by v2.
- The map grows one authoring control (the accent button) and a long press;
  tapping your own pin opens the sheet instead of a snackbar.
- `placePresenceProvider` is alive with the map, like the trail recorder. Off the
  map screen there is no accrual — acceptable while the map is where the app
  lives, and the first thing to move if that stops being true.
- Deleting is immediate and undoable from a snackbar rather than guarded by a
  dialog. One tap to delete, one to undo, and the point is recoverable for
  longer than a confirmation would have protected it.

## What would change our mind

- **If places gain a server.** Check-in counts would move behind the same API as
  `CheckInRepository`, and the on-device count becomes a cache. The entity
  survives; the store does not.
- **If accrual has to work off the map screen** — a quest that counts hours at a
  place, say. `placePresenceProvider` would move out of the widget tree's reach
  and into whatever keeps the location stream alive.
- **If an hour turns out to be the wrong unit.** It is a guess made at a desk.
  If real walks show people collecting a check-in for a bus stop they waited at,
  the interval becomes per-place or the radius shrinks — the rule is one pure
  function, and it is the only thing that would have to change.
