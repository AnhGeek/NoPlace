# 0013 — Auto check-in for the world's places, and the bonus it must not spend

**Status:** Accepted · 2026-08-06 · supersedes one decision in
[0012](0012-visit-history-for-every-place.md)

## Context

0012 gave the world's places a visit history and then refused to let an
unattended hour add to it. The reason was narrow and real: `Place.visited`
drives the first-visit ×2, `placeVisitSyncProvider` derived it from *any* visit,
so an hour spent near Chợ Bến Thành without tapping would have silently spent a
reward the player never collected.

That was the right call given one bit to work with. It is the wrong product.
Standing in a place for an hour is the most honest evidence of a visit the app
has, and the whole premise of the feature is that a diary should not need a
form. The constraint was in the schema, not in the idea.

## Decision

### `Place.autoCheckIn`, set by the data, not by the player

A flag on the place, defaulting to **true**, arriving with the places data —
JSON today, an API later. Off for the places where an unattended hour means
nothing: a whole district, a transport interchange, anywhere people wait rather
than visit.

Not the player's to change, deliberately, and this is the difference from a
place they saved themselves. Their own places carry an interval they picked
(`AutoCheckIn`, 0011/0012) because only they know whether the spot is a café or
their own kitchen. The world's places are described *to* them, and a per-place
duration nobody can reach is a constant with extra steps — so the interval here
is fixed at `AutoCheckIn.hourly` and only the flag varies.

### "Has been here" and "has spent the bonus" become two facts

`PlaceVisit.claimedAt` — null until the player *deliberately* checks in.
`PlaceVisitRules.visited` is the only path that sets it, and it sets it once:
`claimedAt ?? now`, so a second check-in does not move it. `advance` — the hour
— never touches it.

The consequences fall out cleanly:

- `hasVisited` (`checkInCount > 0`) drives the history card.
- `isClaimed` drives `Place.visited`, and therefore the ×2 and the reward line.
- Somebody who sits near a place for an hour and then walks in and taps still
  gets the doubled first visit. They collected a memory and kept the reward.

The check-in sheet's meta line moved from `place.visited` to the record's
`hasVisited`. Those now genuinely differ, and "never visited" printed above a
card reading "checked in once" is the sheet contradicting itself.

### The v5 backfill is `last_check_in_at`, not null

Every count already on disk was earned by tapping — until this version there was
no other way to collect one at a world place. Backfilling null would hand every
returning player a fresh first-visit bonus for everywhere they have ever been.
There is a migration test that does nothing but pin this down.

## Consequences

- Schema v5: one `ADD COLUMN` and one `UPDATE`, tested against a v4 database.
- The backup carries `claimed_at`, still without a format bump; a file written
  before v5 falls back to `last_check_in_at` for the same reason the migration
  does.
- `placePresenceProvider` now walks the world's places as well as the player's,
  reading `FakeWorldStore.currentPlaces` synchronously — it runs on a timer as
  well as on the position stream and cannot wait a microtask.
- Two loops, one rule. `PlaceVisitRules.advance` did not change.

## What would change our mind

- **If the flag needs to be per player after all** — somebody whose office is
  next to a landmark collecting it nightly. It would become a preference keyed
  by place id, beside the visit record, and the flag from the data becomes its
  default rather than the answer.
- **If an hour should pay XP.** It deliberately does not: the history is the
  device's, the XP economy is the world's, and only the tap crosses between
  them. Paying out would mean a `CheckInResult` and a log entry from a provider
  that currently only writes one row, and the ×2 would need a rule of its own.
- **If `claimedAt` starts being read as "first visit".** It is not — it is when
  the *bonus* was spent. If a genuine "first time here" timestamp is ever wanted,
  it is a third column, not this one wearing a second hat.
