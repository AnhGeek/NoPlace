# Backlog

What the current build deliberately does not do. Each item says what exists
today, so nobody has to reverse-engineer the gap.

## Data

- **Basemap: two cities, bundled.** Streets are back
  ([adr/0008](adr/0008-openstreetmap-basemap.md)): OpenStreetMap vector tiles in
  a region pack, cooked by [tools/region_cooker](../tools/region_cooker/).
  `vn-hcmc` and `vn-dongnai` are bundled and the region follows the player's
  position, announced by the arrival sheet when it changes. Hà Nội has a config
  and a remote URL but no cooked pack and **no download flow** —
  `RegionPackStore.download` exists and nothing calls it, so the picker shows it
  as not on the phone and refuses to select it. That is the rest of
  [NP-1](tickets/NP-1-region-packs-on-device.md).
- **Places still come from the fake world.** The packs carry an OSM `pois`
  layer the app ignores; `FakeWorldStore` is still what supplies places.
- **Location is real.** The GPS drives the player position, the fog and the
  nearby list ([adr/0009](adr/0009-real-location.md)). Tracking continues with
  the screen off via a location foreground service, on while-in-use permission —
  `ACCESS_BACKGROUND_LOCATION` is deliberately not declared.
  Remaining: the foreground notification's text is English only, and the camera
  follows the player unconditionally rather than offering a follow/free toggle.
  The trail is region-scoped, so each city keeps its own fog.
- **A places API.** The seven seeded places are hard-coded. `WorldRepository`
  is the seam; nothing above it changes.
- **Persistence.** The walked fog trail *is* stored on the device
  ([adr/0005](adr/0005-tile-caching-and-fog-persistence.md)). Everything else —
  language choice, XP, streak, check-in history — is still in memory and resets
  on relaunch. `LocaleController.build()` is the single place a stored language
  would be read.
- **No authoring flows.** Dropping a pin, choosing its icon and taking a photo
  for a picture point are all unbuilt: `MapPointRepository` has `add`/`update`/
  `remove` and the map renders all three kinds, but the only points that exist
  come from `DemoMapPoints`. `PicturePointThumbnails` is the prepared seam for
  the photo half.
- **No detail sheet for a player's point.** Tapping one shows its label in a
  snackbar; rename, re-icon, view photo and delete are missing.
- **No way to clear the trail.** `ExplorationTrailRepository.clear()` exists and
  is tested, but nothing in the UI calls it. It needs a settings row behind a
  confirmation — wiping somebody's walking history by accident is unforgivable.
- **The trail is device-local.** Reinstall and it is gone, and it does not move
  between phones. It is the first thing to sync once accounts exist.
- **Charted percentage.** `chartedFraction` is seeded, not computed. The real
  version needs visited-tile accounting — now per region, since the trail is
  scoped to one.

## Screens

- **Search.** The field on the map is a visible promise; tapping it shows a
  placeholder message. It needs a results screen over the places API.
- **City switching.** The profile chips render but only the current city is
  live; "+ Add city" does nothing.
- **Empty states.** Only the logs screen has one. The map with no nearby place
  and the quests screen with no quests both need designed copy.
- **Failure copy.** `NpAsyncView`'s error state is untranslated English
  ("Something went wrong"), on purpose: the wording is unresolved, and a wrong
  sentence in two languages is worse than a neutral one in one.

## Platform

- **iOS run.** The project is configured (bundle id, display name, dark
  appearance, localisations, location usage string) but has only been built and
  verified on Android — an S8 running Android 9. It needs a pass on a real
  iPhone, especially the sheet's safe-area handling on a notched device.
- **App icons and splash.** Still Flutter's defaults.
- **Flavours.** One entry point today. `bootstrap()` exists so dev/staging/prod
  entry points can share start-up work when they arrive.
- **Crash reporting.** `FlutterError.onError` in `bootstrap.dart` is the hook;
  no service is wired in.

## Quality

- **Golden tests** for the design system, once the visual language settles.
- **Integration test** for check-in → district discovered, once location is
  real.
- **CI pipeline** — the exact steps are in
  [10-engineering-standards.md](10-engineering-standards.md).

## Known rough edges

- The fog mask is recomputed on every camera frame and culled to the viewport.
  Fine into the low thousands of trail cells; past that it needs a spatial index
  rather than a linear scan.
- The trail is now scoped per region (`trail_points.region_id`, schema v2), so
  each city keeps its own fog and start-up reads one city rather than every one
  ever walked. Cells are still absolute world coordinates, which is what has
  always stopped one city's fog appearing over another.
- `District.index` is seeded to match the mock-up ("District 3 of 12" for Bình
  Thạnh); it should be derived from the city's district list.
- The check-in radius (200 m) is generous to survive urban GPS drift. It should
  become server-driven per place — a market entrance is not a park.
