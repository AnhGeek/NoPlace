# Design system

Everything visual lives in `app/lib/design_system/`. Feature code imports the
barrel:

```dart
import '../../../design_system/components/components.dart';
```

## The one rule

**Components read tokens. Features read components.**

A screen that imports `design_tokens.g.dart` for a colour is telling you a
component is missing. Two exceptions, both deliberate:

- layout constants (`NpSpace`, `NpRadius`, `NpSize`) — screens need to lay
  themselves out, and there is no honest way to hide that;
- `NpTypography` styles — text is content, and wrapping every label in a widget
  would cost more than it saves.

Colours are never one of the exceptions. If a screen needs a colour, add a
semantic token and expose it through a component parameter.

## The catalogue

| Component | Use it for |
| --- | --- |
| `NpCard` | Any panel: list rows, tiles, sheets. Handles the dimmed "locked" state |
| `NpListRow` + `NpRowMark` | A log or quest row: mark, title, subtitle, reward |
| `NpPrimaryButton` | The single orange action on a screen |
| `NpGhostButton` | The second action ("Not now", "Save changes"); `emphasized` lights it up when it has work waiting |
| `NpPill` / `NpXpLabel` | Small numeric badges: "+14%", "+100 XP" |
| `NpChip` | Selectable pill in a horizontal row (the map switcher); `dimmed` for one that names something not on this phone yet |
| `NpSegmentedControl` | Two or three filters over *the same* list |
| `NpTopTabs` | Full-width scope switch over the map |
| `NpBottomNavBar` | The four destinations; goes transparent over the map |
| `NpProgressBar` / `NpProgressRow` | Charting progress, quest progress |
| `NpStatTile` | Square icon + number + caption |
| `NpMapPin` / `NpPlayerMarker` | Places on the map, and you |
| `NpFogOverlay` | The fog of war |
| `NpSearchField` | The floating search bar |
| `NpSheetSurface` + `showNpModalSheet` | Every bottom sheet |
| `NpScreenHeader` / `NpAvatar` | List-screen heading, profile picture |

Run the app in debug and open **Settings → Design system gallery** to see all of
them live on the device you care about.

## Type ramp

`NpTypography` exposes named roles, not sizes: `display`, `headline`, `title`,
`label`, `bodyLarge`, `body`, `footnote`, `caption`, `overline`, `stat`,
`statHero`. Pick the role that matches the *job* of the text. If none fits, that
is a design conversation, not a `copyWith`.

The same ramp is installed as Material's `TextTheme`, so stock widgets
(`AppBar`, `SnackBar`, `ListTile`) inherit it.

## Colour discipline

- **Orange (`accentDefault`) means "do this next".** One per screen.
- **Green** is progress and streaks. **Blue** is informational. **Purple** is
  rarity. **Burnt orange** is a warning.
- Category colours (food, café, landmark, park, market) exist to tell pins apart
  at a glance, and carry no other meaning.
- Locked content is 45% opacity (`NpOpacity.locked`), never a different colour.

## Adding a component

1. Does an existing one nearly fit? Add a parameter before adding a widget.
2. Name it `Np<Thing>`, put it in `components/`, export it from
   `components.dart`.
3. Read tokens only — no literal colours, sizes or durations.
4. Add it to the gallery. If it has states (selected, disabled, locked), show
   all of them there.
5. Give it a doc comment saying *when to use it*, not what it renders.

## Accessibility

- Every tappable target is at least `NpSize.touchTarget` (48 dp).
- Interactive components carry `Semantics` (`button`, `selected`) — see
  `NpSegmentedControl` and `NpBottomNavBar`.
- Text scaling is clamped to 1.3× in `NoPlaceApp`; every screen must survive
  that without clipping. `test/features/profile_screen_test.dart` pins the
  smallest supported viewport (360 × 740).
- Decorative animation (the player's pulse ring) is excluded from semantics.
