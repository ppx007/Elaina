## Why

The current baseline contains several behavior-affecting literal values in
production/runtime scaffold code. These values are deterministic and mostly
intentional, but their meaning is not named at the boundary where future work
will tune clocks, page sizes, subtitle scoring, Bangumi auto-match thresholds,
and unavailable-provider sentinel policies.

Leaving those values inline makes future changes brittle: callers must hunt for
repeated literals, and reviewers cannot tell whether a number is a fixture, a
domain invariant, or a runtime policy.

## What Changes

- Add named deterministic baseline defaults for contract clocks and common list
  limits.
- Replace inline subtitle scanner confidence literals with named scoring
  constants.
- Replace repeated seasonal Bangumi automatic-match thresholds with a named
  default.
- Replace duplicated unavailable-provider gateway policies with named sentinel
  constants.
- Name mock playback timestamps and UI demo seek positions that live under
  `lib/src` rather than test fixtures.

## Impact

- Affected code includes foundation defaults, media/RSS/seasonal/subtitle
  runtime scaffolding, subtitle scanner scoring, ACG unavailable providers,
  playback mock surfaces, tests, tools, and active OpenSpec specs.
- Tests and smoke check fixtures may continue to use local literal values when
  the values are clearly scenario data rather than reusable production policy.
