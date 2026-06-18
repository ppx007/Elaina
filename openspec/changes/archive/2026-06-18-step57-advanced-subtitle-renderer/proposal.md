# step57-advanced-subtitle-renderer

## Why

Step 24 defined deterministic advanced caption contracts and runtime
projections. Step 57 needs a concrete Playback-owned bridge that can map ordered
dual subtitle selection, ASS enhancement intent, and PGS subtitle intent to MPV
commands without moving UI overlay, Flutter widgets, subtitle parser mutation,
or native player details across layer boundaries.

## What Changes

- Add a concrete MPV advanced subtitle bridge in the approved Playback binding
  surface.
- Map primary subtitle, secondary subtitle, ASS enhancement, PGS subtitle load,
  and disable operations to deterministic MPV property/command plans.
- Normalize backend rejection into existing advanced caption failure outcomes.
- Add focused tests and checker coverage for command mapping, capability
  declaration, failure normalization, and boundary cleanliness.

## Non-Goals

- No Flutter UI, subtitle overlay, playback page, settings page, file picker,
  route, `lib/main.dart`, or `windows/**` changes.
- No custom ASS/PGS decoder, GPU renderer, Canvas/Widget implementation,
  diagnostics center, AVSyncGuard policy, VLC fallback, network, RSS, WebView,
  or BT work.
- No Matrix4 danmaku concrete rendering in this change.

## Validation

- Focused MPV binding tests for advanced subtitle bridge behavior.
- Advanced caption, advanced playback, and player-core checker coverage.
- OpenSpec validation, analyzer, Flutter analyzer, and Flutter test baseline
  before archive.
