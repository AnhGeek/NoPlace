# 0004 — Build the UI against a fake world, not stubs

**Status:** Accepted · 2026-07-30

## Context

The UI had to be built before any backend existed. The usual approach is stub
widgets with hard-coded strings, replaced later. That produces screens that have
never seen state change, and a "later" that is always more expensive than
expected.

## Decision

`data/fake/fake_world_store.dart` holds the entire game world in memory and
**applies the real rules**: a first visit doubles the XP, a check-in appends a
log entry, entering an undiscovered district triggers a discovery and awards its
XP, an out-of-range check-in is refused with a typed failure.

It is exposed through the same repository interfaces the real implementation
will implement, and swapped in one file
(`data/repository_providers.dart`).

Shared numbers live in `domain/rules/exploration_rules.dart`, so the UI and the
store cannot disagree — the check-in sheet only ever offers places inside the
radius the rules will accept.

## Consequences

- Every screen has been exercised with state that actually changes: check in on
  the device and the fog clears, the XP rises, a log row appears.
- The rule tests in `test/data/` are written against behaviour, not against the
  fake. When the API arrives, the same expectations become its contract.
- Loading and error states are real code paths, not a `TODO` — the fake even
  delays 320 ms on write, so the button's pending state is honest.
- **The fake is code we will delete.** That is fine: it paid for itself before
  the first endpoint existed.
- The seeded world is Ho Chi Minh City, and some seed values (the 8% charted for
  an undiscovered district, `District.index`) are chosen to reproduce the
  original design study rather than to be internally derivable.

## What would change our mind

Nothing about this decision is meant to survive the real API — the fake is a
scaffold, not a layer. When the remote repositories land, the fakes move to
`test/` as fixtures and stop shipping in the app.
