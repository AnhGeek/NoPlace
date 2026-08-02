# The product

## In one sentence

NoPlace turns the city you live in into a map you have to walk to uncover.

## The loop

1. **Open the app.** The city is dark except where you have been.
2. **Walk.** The fog lifts around you as you move.
3. **Check in.** Standing next to a place lets you claim it — first visits are
   worth double.
4. **Get pulled further.** An unidentified site 480 m away, a district you have
   never entered, a streak you do not want to break.

Everything in the app serves that loop. A screen that does not either *show
progress* or *point at the next step* does not belong.

## Who it is for

People who already live somewhere and have stopped looking at it. Not tourists
— tourists have guidebooks. The product assumes you will see the same streets
again, and rewards noticing what is on them.

## Design principles

1. **The map is the product.** Chrome is translucent, dark and thin. If a panel
   can be smaller, it should be.
2. **Never lie about location.** GPS drifts. The check-in prompt always offers a
   one-tap correction, and we never reject a check-in the UI just offered.
3. **Reward before request.** XP, streaks and discoveries land immediately and
   locally. Nothing waits on a server round trip to feel good.
4. **Locked, not hidden.** Undiscovered content is shown dimmed with a reason
   ("travel there to reveal"). Knowing what is out there is the pull.
5. **One accent colour.** Orange means *do this next*. If everything is orange,
   nothing is.

## What "done" means for a feature

- Works in English and Vietnamese, with no clipped text at 1.3× font scale.
- Uses design-system components; no ad-hoc colours, spacings or text styles.
- Has a widget test for its screen and a unit test for any rule it introduces.
- `flutter analyze` reports zero issues.
- Verified on a real device, not just the simulator.

## Deliberately out of scope for now

Accounts, friends, sharing, notifications, offline maps, and any form of
in-app purchase. See [backlog.md](backlog.md).
