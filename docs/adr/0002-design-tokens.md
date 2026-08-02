# 0002 — Design tokens as a build step, dark theme only

**Status:** Accepted · 2026-07-30

## Context

The visual language started as an HTML study (`map-pulse.html`) with values
inlined in CSS. The same brand has to appear in the Flutter app, the marketing
site, App Store screenshots, an eventual iOS widget and the Android splash
screen. Copying `#F56B26` into five places is how brands drift.

We also had to decide whether to build for two themes now or one.

## Decision

1. Tokens live in `design/tokens/*.json` in the W3C DTCG draft format, split
   into a **primitive palette** and a **semantic layer**.
2. A dependency-free Dart package (`tools/token_builder/`) compiles them to
   Dart, CSS, Swift, Android XML and flat JSON. Outputs are committed.
3. Design-system components read the generated constants directly
   (`NpColors.accentDefault`) rather than a `ThemeExtension`.
4. **Dark theme only.**

## Consequences

- One edit, one command, and every platform agrees.
- CI can prove nobody hand-edited a generated file
  (`build_tokens.dart --check`).
- Because components read `NpColors` statically, there is no per-theme lookup
  and no `Theme.of(context)` in the hot path — but there is also **no way to run
  a second theme today**. That is the deliberate trade.
- The ad-hoc values from the HTML study (6/10/13/18 px paddings) were snapped
  onto a 4 pt scale on the way in. Some screens are one or two pixels off the
  mock-up. That is the correct outcome: the scale is the design, the mock-up was
  a sketch.

## What would change our mind

A second theme — light mode, or a high-contrast accessibility theme. The token
files already support it (add `semantic.light.json` with the same keys); the
work is teaching the generator to emit one class per theme and converting the
components' static references to a `ThemeExtension` lookup. Roughly a day, and
it should be done the moment a second theme is actually on the roadmap — not
speculatively.
