# Screens and flows

Six screens, one loop. Everything else is a state of one of these.

## Navigation map

```
HomeShell (bottom navigation, each tab keeps its own stack)
├── /map        MapScreen          ← launch destination
├── /logs       LogsScreen
├── /quests     QuestsScreen
└── /profile    ProfileScreen
        └── /profile/settings                 SettingsScreen
                ├── …/fog                     FogSettingsScreen
                ├── …/backup                  BackupScreen
                └── …/design-gallery          DesignGalleryScreen (debug only)

Pushed on the root navigator, above everything:
    /discovery                    DistrictDiscoveredScreen (full-screen, fade in)
    (modal)                       CheckInSheet
```

Tapping the active tab again pops that tab back to its root.

## 1 · Map — the home screen

The two tabs are two views of the same world, not two zooms. **CITY** is the
map below; **NEARBY** is a list.

```
┌─────────────────────────────┐
│  CITY        │     NEARBY   │  scope tabs
│  ┌───────────────────────┐  │
│  │  Search places…       │  │  opens search (not yet built)
│  └───────────────────────┘  │
│                             │
│        ▒▒▒ fog ▒▒▒          │  everything unvisited is dark
│      ◐ you are here         │  chip anchored to the player
│    📍 pins for places       │  colour = category
│                        (☁)  │  fog toggle — lit while the fog is off
│                        (◎)  │  recentre — lit while following the GPS
│                        (✚)  │  save a place, here
│  ┌───────────────────────┐  │
│  │ You're near X         │  │  nearby card — only for places
│  │ 40 m · never · +100XP │  │  inside the check-in radius
│  │ Wrong place? ›  [Check│  │
│  └───────────────────────┘  │
│  Map   Logs   Quests  Profile│
└─────────────────────────────┘
```

States: no nearby place → the card is absent, nothing else changes. Tiles still
loading → the canvas colour shows through the fog, which reads as "unexplored"
rather than "broken".

**The fog toggle** lifts the fog for as long as the player wants it lifted, and
is remembered across launches like the other layers. It erases nothing and stops
nothing: the trail is untouched, the walk keeps recording, and putting the fog
back shows exactly the ground earned meanwhile. It exists because the fog is also
what hides the street you are standing on, and an explorer who cannot orient
themselves stops walking. The lit state is fog *off* — the opposite of the
recentre button — because fog on is the game as designed and needs no marker,
while fog off is the state worth noticing.

### NEARBY — the list

```
┌─────────────────────────────┐
│  CITY        │     NEARBY   │
│  ┌───────────────────────┐  │
│  │  Search places…       │  │
│  └───────────────────────┘  │
│  📍 Chợ Bến Thành    [Check]│  in range: tappable, check-in enabled
│     40 m · never · +100 XP  │
│  📍 Saigon Post Office [Chk]│
│     250 m · visited · +50XP │
│  📍 Công viên Tao Đàn  [Chk]│  out of range: dimmed, button disabled
│     630 m · walk closer…    │
│  Map   Logs   Quests  Profile│
└─────────────────────────────┘
```

Every place within the nearby radius, closest first — **2 km by default**, and
changeable in Settings › Nearby (500 m to 10 km). Out-of-range rows are dimmed
rather than dropped: the list is also how a player picks the next walk, and one
that showed only claimable places would be empty exactly when it matters most.
Nothing within the radius → an empty state that still says walking works.

The fog is cumulative and **stored on the device**: everywhere the player has
stood stays uncovered across launches, and previously-visited streets still
render with no network at all, from the tile cache. See
[adr/0005](adr/0005-tile-caching-and-fog-persistence.md).

## 2 · Check-in sheet

Opened by the card's button, by tapping a pin, or by "Wrong place?".

1. **Header** — pin, name, `category · distance · never visited`, reward.
2. **Three tiles** — explorers here, first-visit ×2, streak kept.
3. **Your history here**, but only once there is one: `Checked in 7 times` and
   when the last one was. A card reading "no check-ins yet" above a button
   offering to make one is noise, and it would sit there for most of the map.
4. **Check in here** — the only orange thing on the sheet.
5. **"Not this place?"** — up to three alternatives, all of them within the
   check-in radius so the app can never offer something the rules would refuse.
   Tapping one re-targets the sheet in place.
6. **Not now** — dismiss.

While the request is in flight the button is disabled. On failure the sheet
stays open and says why ("You're too far away…"); it never closes on a silent
error.

The history is kept **on the device**, keyed by place id, and so survives a
relaunch even though the world itself is seeded fresh each time — which is also
what stops a place you checked into last week offering its first-visit bonus
again this morning.

An hour spent near one of the world's places counts as a visit too, with nothing
tapped — the same rule as a place you saved, but at a **fixed hourly interval
you cannot change**, and only where the places data says so. That flag is on by
default and off for the places an unattended hour would be meaningless at: a
whole district, a transport interchange, anywhere people wait rather than visit.

Collecting an hour this way **never spends the first-visit ×2**. Sit outside a
place all afternoon and then walk in and check in, and the bonus is still
yours — the sheet counts the hours in your history and keeps the reward
separate. See [adr/0013](adr/0013-auto-check-in-for-the-worlds-places.md).

## 2b · Place sheet — the player's own

Opened by the ✚ button (at the player), by a long press on the map (at that
spot), or by tapping one of your own pins. One sheet for both, because saving a
place and coming back to it are the same form:

1. **Pin preview and name** — the preview redraws as the icon is picked, so the
   choice is made against the thing that will be on the map. The name may stay
   empty; a pin you drop to remember a corner does not owe anybody a label.
2. **Icon** — twenty to choose from.
3. **Feeling** — five faces, best to worst. Tap the chosen one again to clear it:
   "meh" and "I have not said" are different answers.
4. **Rating** — five stars, and tapping the star you are on clears it, which is
   the only way back to unrated.
5. **Auto check-in** — Off · 30 min · 1 hour · 2 hours, defaulting to the hour.
   How long you have to stay before it counts as a visit without you tapping
   anything. The **?** beside the heading opens the explanation: the 150 m
   radius, the interval, and the twenty minutes of quiet that end a stay. It is
   a button rather than a tooltip because this is the one control on the sheet
   that keeps acting after the phone is back in a pocket. Off is the right
   answer for somewhere you are always at, like home.
6. **The buttons** — a new place can only be saved. An existing one leads with
   **"I'm here now"** (which saves the edits *and* counts a visit), then "Save
   changes", then delete.

An existing place also carries its count: `Checked in 7 times`, when the last one
was, and a line describing what the interval above will do — which follows the
picker as you change it, before anything is saved, because "what will this do"
is the question you are asking at that moment. See
[adr/0011](adr/0011-places-the-player-saves.md) for what counts as a stay and
[adr/0012](adr/0012-visit-history-for-every-place.md) for the interval.

Deleting is immediate, and the map offers **Undo** in a snackbar — the place goes
back with its id and its count, so undo is an undo and not a second attempt.

## 3 · District discovered

Triggered when a check-in was the player's first step into a district. Fires
*after* the sheet closes, as a full-screen fade-in on the root navigator: badge,
kicker, district name, "District 3 of 12 · TP.HCM", the XP pill, one button.

No navigation bar, nothing else to tap. Three seconds of pure reward.

## 4 · Explorer Logs

Header with `2 / 12 districts`, a Districts/Quests segmented control, then the
history — newest first. Four row types: district entered (green ✓), check-in
(green ✓), unknown site (blue ?), locked (dimmed, "travel there to reveal").

Locked rows are shown on purpose: an empty list is discouraging, a list with
five mysteries in it is an invitation.

## 5 · Quests

The weekly challenge sits on top in a gradient card with its own progress bar,
because it is the goal that survives a bad day. Below it: reveal a site, walk
5 km, enter a new district, and one locked teaser.

## 6 · Profile

Avatar, name, level line, then the headline number — **38% of the city charted**
— because that one number is the whole game. Under it: three stat tiles
(distance today, check-in places, streak), the city switcher, per-district
progress bars, and the city ranking card.

The gear in the corner leads to Settings: language, map layers, the nearby
radius, Fog, Backup, and in debug builds the design gallery and a discovery
preview.

### Backup

Everything the player has walked lives on one phone, and the fog is the only
thing in the app that cannot be earned twice. The screen says that first, then
counts what is at stake — fog, points, cities — and offers two buttons: **Save a
backup**, which hands one `.noplace` file to the system save dialog, and
**Restore from a backup**, which reads one back.

Restoring adds; it never wipes. See
[ADR 0010](adr/0010-backup-and-restore.md).

## The one flow that matters end to end

```
Map ──tap "Check in"──▶ Sheet ──tap "Check in here"──▶ rules apply
                                                          │
              ┌───────────────────────────────────────────┤
              ▼                                           ▼
   first step into a district?                     ordinary check-in
              │                                           │
              ▼                                           ▼
   /discovery full-screen              snackbar "Checked in at X"
              │                                           │
              └──────────────▶ back on the map ◀──────────┘
                    fog cleared, XP up, log row added
```

Every one of those effects is applied locally and immediately. Nothing in that
diagram waits on a server.
