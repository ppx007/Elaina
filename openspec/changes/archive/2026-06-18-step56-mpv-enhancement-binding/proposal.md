# step56-mpv-enhancement-binding

## Why

Steps 31-35 made concrete local playback available through the Playback layer,
and Steps 36-55 filled provider, storage, RSS, online rule, BT, and streaming
runtime slices. Step 56 needs to connect the existing declarative video
enhancement profile intent to the concrete MPV binding without moving native
player details into UI, Domain, provider, storage, streaming, network, or the
Phase 5 deterministic enhancement runtime.

## What Changes

- Add a Playback-owned MPV enhancement binding that maps scaler, HDR tone
  mapping, deband, and Anime4K-style shader intent to deterministic MPV
  property/command plans.
- Extend the media_kit/libmpv backend boundary with neutral property/command
  calls so the concrete binding can apply enhancement plans through libmpv
  without exposing media_kit types.
- Report enhancement capabilities only from the concrete MPV composition path
  that can apply the MPV command plan.
- Add focused tests and checker coverage for command mapping, failure
  normalization, capability declaration, and import boundaries.

## Non-Goals

- No Flutter UI, settings page, playback overlay, file picker, video surface,
  route, `lib/main.dart`, or `windows/**` changes.
- No shader bundle manager, shader compiler, downloaded shader registry,
  Anime4K preset import workflow, diagnostics center behavior, AVSyncGuard
  drift policy, VLC fallback, network, RSS, WebView, or BT work.
- No broad renderer abstraction beyond the concrete MPV enhancement binding
  needed for Step 56.

## Validation

- Focused MPV enhancement binding tests.
- Advanced playback and player-core boundary checker coverage.
- OpenSpec validation, analyzer, Flutter analyzer, and Flutter test baseline
  before archive.
