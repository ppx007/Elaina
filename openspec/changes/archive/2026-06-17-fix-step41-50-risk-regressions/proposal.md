# fix-step41-50-risk-regressions

## Why

The Step 41-50 baseline still had three review findings that could leak unsafe
or untyped behavior through otherwise typed runtime contracts.

## What Changes

- Reject unsafe regex shapes through typed online-rule validation before they can
  execute.
- Convert online-rule normalization failures into typed evaluation failures in
  the test harness and source runtime.
- Convert video-detail action load failures into typed action results instead of
  leaking repository `StateError`s.

## Non-Goals

- No UI, `lib/main.dart`, `windows/**`, native player, BT, WebView, crawler, or
  source-specific scraper changes.
- No new real network fetch behavior.
- No broad parser or regex-engine rewrite.

## Validation

- Focused provider online-rule tests.
- Focused video-detail runtime tests.
- Existing online-rule, video-detail, and automation checker scripts.
- OpenSpec validation, analyzer, and full Flutter tests before archive when
  feasible in the current environment.
