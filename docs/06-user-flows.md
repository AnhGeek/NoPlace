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
                └── …/design-gallery          DesignGalleryScreen (debug only)

Pushed on the root navigator, above everything:
    /discovery                    DistrictDiscoveredScreen (full-screen, fade in)
    (modal)                       CheckInSheet
```

Tapping the active tab again pops that tab back to its root.

## 1 · Map — the home screen

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
│                             │
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

The fog is cumulative and **stored on the device**: everywhere the player has
stood stays uncovered across launches, and previously-visited streets still
render with no network at all, from the tile cache. See
[adr/0005](adr/0005-tile-caching-and-fog-persistence.md).

## 2 · Check-in sheet

Opened by the card's button, by tapping a pin, or by "Wrong place?".

1. **Header** — pin, name, `category · distance · never visited`, reward.
2. **Three tiles** — explorers here, first-visit ×2, streak kept.
3. **Check in here** — the only orange thing on the sheet.
4. **"Not this place?"** — up to three alternatives, all of them within the
   check-in radius so the app can never offer something the rules would refuse.
   Tapping one re-targets the sheet in place.
5. **Not now** — dismiss.

While the request is in flight the button is disabled. On failure the sheet
stays open and says why ("You're too far away…"); it never closes on a silent
error.

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

The gear in the corner leads to Settings (language, and in debug builds the
design gallery and a discovery preview).

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
