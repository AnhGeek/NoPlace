# 0006 — SQLite for everything on the device, and three kinds of point

**Status:** Accepted · 2026-07-31 · supersedes the JSON half of
[0005](0005-tile-caching-and-fog-persistence.md)

## Context

Three requirements arrived together: record the GPS trail at metre resolution,
store it somewhere a person can open on a computer, and put the player's own
points on the map alongside the suggested ones.

The JSON file from 0005 fails all three. A metre-resolution trail is millions of
rows over a year; a JSON array has to be parsed whole to read any of it; and it
had no place for points at all.

## Decision

### One SQLite file

`databases/noplace.db`, three tables:

| Table | Holds |
| --- | --- |
| `trail_points` | every metre walked — `(lat_cell, lng_cell)` primary key, plus the raw `latitude`/`longitude` and a timestamp |
| `map_points` | the player's own points: dropped pins and photo points |
| `preferences` | small settings, so a checkbox does not need a second storage mechanism |

Plain SQLite on purpose — **it is inspectable**:

```bash
adb exec-out run-as site.lya3hc.noplace cat databases/noplace.db > noplace.db
sqlite3 noplace.db 'select * from trail_points limit 5;'
```

That is not a debug affordance, it is a property of the product: the trail is
the player's record of their own walking, and it should never be locked inside
a format only this app understands.

The primary key does the de-duplication (`INSERT OR IGNORE`), so standing still
writes one row and re-walking a street writes none. Writes are batched and
flushed on a timer and on app background.

### A metre is the storage grid, not the uncovered area

Storing *uncovered ground* at a metre would be ~100,000 rows per position fix.
What is stored is where the player **was**; the fog opens a disc around each
point when it draws. Storage is therefore proportional to distance walked, not
to area revealed.

Recording precision is a throttle in front of that grid — skip a fix within *n*
metres of the last one — so a coarser setting shrinks the database without
changing the schema.

### Three kinds of point

`MapPointKind` — `suggested` (from the places data), `user` (dropped by the
player, with a chosen icon), `picture` (created from a photo). Each is drawn
above the fog and can be silenced independently from Settings.

Suggested points stay in the world data; the other two live in `map_points`.
The split matters: one of them is the player's content and must never be
replaced by a data refresh.

Icons are stored as stable string ids, never as `IconData` code points, which
are not a storage format.

## Consequences

- The trail keeps full fidelity for export and analysis while the fog stays
  cheap to draw.
- Settings, points and trail are one file to back up, inspect, or later sync.
- `SqliteTrailRepository.load()` reads the **whole** trail into memory. Fine for
  a city, wrong for a lifetime — the scaling fix is a bounded query per camera
  move, and it is in the backlog.
- Tests run the same schema on the desktop VM through `sqflite_common_ffi`.

## What would change our mind

- **Millions of rows.** At that point the in-memory set has to go and the fog
  queries by viewport bounds, which is why the bounds index exists already.
- **Sync.** Once trails move between devices, rows need an origin and a
  conflict rule; that is a schema migration, not a rewrite.
