# step60-full-feature-gate

## Why

Steps 56-59 completed concrete advanced playback, fallback, and diagnostics
core slices. Step 60 needs a single non-UI full feature gate that proves the
current core implementation can pass OpenSpec, analyzer, tests, smoke gates,
and boundary checkers before it is treated as release-ready for UI integration.

## What Changes

- Add a PowerShell full feature gate that orchestrates existing validators
  instead of duplicating their logic.
- Include OpenSpec validation, Dart/Flutter analysis, full Flutter tests, core
  checker scripts, non-UI smoke gates, diagnostics runtime checks, and optional
  native player smoke.
- Add documentation that defines when to run the gate and how native player
  smoke is handled.
- Add checker coverage that keeps the full feature gate non-UI and
  boundary-clean.

## Non-Goals

- No Flutter UI, app shell, route, widget, diagnostics page, video surface,
  file picker, `lib/main.dart`, or `windows/**` changes.
- No new native package, network client, remote telemetry, upload path, or
  platform runner behavior.
- No replacement for focused checker scripts; the full gate composes them.

## Validation

- Focused execution of the full feature gate.
- OpenSpec validation, analyzer, Flutter analyzer, and Flutter test baseline.
- Archive and re-run OpenSpec all validation.
