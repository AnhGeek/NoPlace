# Architecture decision records

One file per decision that would otherwise be re-argued every few months.

Format: **Context → Decision → Consequences → What would change our mind.**
That last section is the point of the exercise — a decision without a stated
reversal condition is a belief, not an engineering choice.

Records are immutable. When a decision changes, add a new record and mark the
old one superseded.

| # | Decision | Status |
| --- | --- | --- |
| [0001](0001-flutter-and-riverpod.md) | Flutter + Riverpod, no code generation | Accepted |
| [0002](0002-design-tokens.md) | Design tokens as a build step, dark theme only | Accepted |
| [0003](0003-map-rendering.md) | `flutter_map` with CARTO raster tiles | Tile source superseded by 0008 |
| [0004](0004-fake-first-data-layer.md) | Build the UI against a fake world, not stubs | Accepted |
| [0005](0005-tile-caching-and-fog-persistence.md) | Cache tiles with flutter_map; store the fog ourselves | Partly superseded by 0006 and 0007 |
| [0006](0006-sqlite-storage-and-map-points.md) | SQLite for everything on the device, and three kinds of point | Accepted |
| [0007](0007-no-basemap.md) | No third-party basemap | Superseded by 0008 |
| [0008](0008-openstreetmap-basemap.md) | Our own OpenStreetMap basemap, shipped as vector region packs | Accepted |
| [0009](0009-real-location.md) | Real location via a foreground service, not background permission | Accepted |
| [0010](0010-backup-and-restore.md) | Backup as one plain file, restored by merging | Accepted |
