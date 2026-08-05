# 0010 — Backup as one plain file, restored by merging

**Status:** Accepted · 2026-08-05 · builds on
[0006](0006-sqlite-storage-and-map-points.md)

## Context

Everything the player has made lives in one SQLite file in the app's private
storage: the fog, their own points, their settings. That file goes with the app.
Uninstall it, lose the phone, factory-reset it, and a year of walking is gone —
and the fog is the one thing in this product that cannot be re-earned, because
earning it meant physically being there.

Android's own auto-backup is not an answer. It is capped, it can be off, it is
silent about whether it ran, and it restores only onto a device signed into the
same account during setup. None of that is something we can tell a player is
true of their walk.

There is also a nearer, duller case than disaster: moving to a new phone.

## Decision

### One file, gzipped JSON, extension `.noplace`

Written and read by `BackupService`. Not the SQLite file itself, and not a
vendor container.

```json
{
  "format": "noplace.backup",
  "version": 1,
  "createdAt": "2026-08-05T09:12:00.000",
  "trail": [["vn-hcmc", 1198572, 11855364, 10.7725, 106.698, 1754...]],
  "mapPoints": [{"id": "...", "kind": "user", ...}],
  "preferences": {"fog.clearing_radius_meters": "180.0"}
}
```

Same principle as 0006, one step further out: `gunzip < walk.noplace | jq`
prints the whole thing. A backup nobody but this app can read would be a worse
promise than no backup at all. `import` accepts the file un-gzipped too, so
looking inside one does not break it.

Trail rows are positional arrays rather than objects because a metre-resolution
city walk is six figures of rows, and repeating six key names on each one
triples the file to say nothing.

**Not the raw `.db` file.** It would be simpler to copy, and it would carry the
schema version with it — which is exactly the problem: restoring it means
replacing the database wholesale, so a restore could not merge, and a file from
a newer schema could not be read by an older build at all.

### The system's save and open dialogs, on our own channel

From Android 11 the app's own storage is not reachable from a file manager, so a
backup we filed ourselves would be one the player cannot get at. The Storage
Access Framework puts it wherever they say — Downloads, Drive, an SD card, a
cable — and asks for no permission to do it: picking the file *is* the grant.

Two Intents, `ACTION_CREATE_DOCUMENT` and `ACTION_OPEN_DOCUMENT`, on the
`MainActivity` channel that already exists for the location service.
**Deliberately not `file_picker`**, which is the obvious package and does not
fit: every stable line of it pins win32 5 while `geolocator`'s Linux
implementation pulls in win32 6, and the single version that resolves against
the rest of the app — `12.0.0-beta.1` — fails to compile, because its Android
Gradle config skips applying the Kotlin plugin under AGP 9 and its plugin class
then does not exist. Owning about a hundred lines of Kotlin is the smaller
liability, and it is the same trade this project already made for the battery
and notification calls next to it.

The cost is that backup is Android-only until somebody writes the iOS half. The
screen disables both buttons where there is no dialog behind them rather than
offering one that does nothing.

### Restoring merges; it never wipes

Trail rows collide on their primary key and are ignored, points and preferences
are keyed and replaced. Three consequences, all of them wanted:

- ground walked since the backup was taken stays walked;
- restoring the same file twice does nothing the second time;
- a backup from an old phone lands on a new one as a straight union.

The whole restore is one transaction. A restore interrupted halfway is a
database in a state nobody designed, and the player has no way to see it.

### Rows that do not parse are skipped, files that are not ours are refused

A file whose `format` is wrong, or whose `version` is ahead of this build, is
refused before anything is written — guessing at a shape we have never seen
risks writing nonsense into the one table that cannot be re-earned. Individual
malformed *rows* are dropped instead: the rows are independent, and restoring a
year of walking minus one bad line beats restoring none of it.

### Photos are not in it

Picture points are — where they are, what they are called — but the image files
stay on the phone that took them, and a restored picture point draws as a plain
pin. Putting camera output inside the backup is a different feature with
different tradeoffs, and this one is worth having first.

## Consequences

- The player can move their walk between phones, and keep a copy of it
  somewhere we do not control.
- The backup format is now a compatibility surface: `formatVersion` is bumped
  only when an older build could no longer read what we write.
- Export reads the trail table whole. Same limit as `load()` in 0006 — fine for
  a city, wrong for a lifetime — and the same fix applies when it bites.
- `flush()` before export and before import, and a reload of all three stores
  after: the screen must agree with the file the player just fed it.

## What would change our mind

- **iOS.** `UIDocumentPickerViewController` is the same two calls on the same
  channel, and the Dart side above it does not change.
- **Sync.** Once trails move between devices continuously, a file the player
  carries is the wrong shape and rows need an origin and a conflict rule — the
  same schema change 0006 already names.
- **Backups big enough to matter.** If the JSON gets unwieldy before the
  viewport-query work lands, the trail becomes a binary block inside the same
  envelope, and the envelope stays readable.
