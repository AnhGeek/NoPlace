# 0012 — A visit history for every place, and an hour the player picks

**Status:** Accepted · 2026-08-06 · extends
[0011](0011-places-the-player-saves.md) · the decision "the world's places count
deliberate check-ins, and nothing else" is superseded by
[0013](0013-auto-check-in-for-the-worlds-places.md)

## Context

0011 gave the player's *own* places a history — how many times, when last — and
an hour spent nearby that counts on its own. Two things it left undone turned
out to matter more than they looked.

The world's places, the seeded ones in Ho Chi Minh City, had `visited: bool` and
nothing else. One bit, no time, no count, and held in memory: checking into Chợ
Bến Thành flipped the bit, appended a row to a flat global log, and forgot the
whole thing on the next launch. A player who had been there seven times was
shown the same sheet as one who had never been — and was offered the first-visit
bonus again every morning.

And the hour was ours, not theirs. An hour is right for a café and absurd for
your own kitchen, where the same rule quietly collects a visit every night.

## Decision

### The visit history is a record *about* a place, not a field *on* one

`PlaceVisit` — count, last time, and the pair that tracks an ongoing stay — is
keyed by place id and lives in a `place_visits` table. Both kinds of place go
through the same entity and the same rules.

Keyed rather than stored on the place, because the two have different owners. A
`Place` is world data: a places API will one day hand it to us and replace the
lot on a refresh. That somebody stood in it on a Tuesday in August is theirs,
and has to survive that refresh — including one that renames the café or moves
the pin ten metres. There is deliberately no foreign key: losing a visit count
because a data refresh renumbered something is the worse bug by a distance.

`MapPoint` keeps its four columns inline rather than moving into the table.
Nothing replaces a point the player authored, so the reason for the split does
not apply to it, and `MapPoint.visit` / `withVisit` give the rules the same
shape either way.

### The world's places count deliberate check-ins, and nothing else

They do not accrue the unattended hour, even though the machinery would now
allow it. Standing near Chợ Bến Thành for an hour without tapping would
otherwise consume the first-visit bonus that the check-in was about to pay — the
player would be quietly worse off for having stood still. The XP economy belongs
to the world; the history belongs to the device; only the tap crosses between
them.

Writing that record is a decorator — `VisitRecordingCheckInRepository` — rather
than a line in the check-in controller. "Checking in is what makes a visit" is
true of the check-in, not of the screen that triggered it, and it survives the
inner repository becoming an HTTP call.

The device's record is played back onto the freshly seeded world on every
launch, by `placeVisitSyncProvider`. It only ever *sets* `visited`: an id missing
from the record is the absence of evidence, not evidence of absence.

### The interval is per place, and one of the choices is "off"

`AutoCheckIn` offers off, 30 minutes, an hour and two hours, defaulting to the
hour — which is exactly what every place did before the setting existed, so an
upgraded database behaves on Tuesday as it did on Monday.

Stored as a `Duration` with `Duration.zero` for off, not a nullable one. A
`copyWith` built on `??` cannot put a null back, so a nullable field would have
made "Off" the one choice the player could pick and never un-pick — the sort of
bug that is invisible in review and obvious the first time somebody hits it.

Off is a genuine early return in `PlaceVisitRules.advance`: a place the player
told us not to watch should not be costing them database writes either.

### The question mark is a button, not a tooltip

`NpTipButton` opens a sheet. Auto check-in is the only control in the app that
keeps acting after the phone is back in a pocket, and the three facts that make
it comprehensible — 150 m, the interval, the 20 minutes that end a stay — do not
fit under a heading and are not worth reading twice. A `Tooltip` was the obvious
alternative and is wrong twice over: two seconds is a poor way to read three
paragraphs, and a long press is invisible to anyone who does not already know
the gesture is there.

## Consequences

- Schema v4: one `ADD COLUMN` and one new table, tested against a database built
  by v3.
- The backup carries `placeVisits` and the interval, without a format version
  bump — a missing key reads as empty, which is the correct reading of a file
  written before the key existed. The stay in progress is dropped on the way in,
  for the same reason 0011 dropped it.
- The check-in sheet shows the history only once there is one. "No check-ins
  yet" above a button offering to make one is noise, and it would sit there for
  most places on the map.
- Two sheets now share `PlaceVisitCard`, because "you have been here seven
  times, last on Tuesday" is the same sentence either way.

## What would change our mind

- **If a count and a last time stop being enough.** A real log — one row per
  visit, with how it was earned — is a bigger feature that this one deliberately
  does not owe. `place_visits` would become append-only and the count derived
  from it; `PlaceVisit` is the only thing above the store that would notice.
- **If the world's places gain a server.** Their counts move behind the same API
  as `CheckInRepository`, `place_visits` becomes a cache, and the decorator is
  where that swap happens.
- **If four intervals turn out to be three too many.** If nearly everybody
  leaves it alone and the rest only ever pick Off, the picker becomes a switch
  and `AutoCheckIn.all` shrinks to two entries.
