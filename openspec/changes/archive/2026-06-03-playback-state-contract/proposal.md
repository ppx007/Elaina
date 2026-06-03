## Why

Playback page surface descriptors and intents now define what the page can show and what actions it can dispatch, but the project still lacks a stable playback state snapshot contract for status, timeline, buffering, and current-track state. This change freezes that state boundary before introducing Flutter widgets or native playback event streams.

## What Changes

- Add a pure Dart playback state contract with immutable playback snapshot, status, timeline, buffering, and active track state types.
- Add a minimal state observation boundary that can be driven by `PlaybackController` or future adapter event sources without introducing Flutter state management or native event bindings.
- Define how state snapshots relate to capability-driven controls and playback page intents without modifying already archived surface or intent contracts.
- Keep this slice independent of Flutter widgets, MPV/native events, provider metadata, streaming, storage, gateway, network, queues, diagnostics, danmaku, advanced subtitles, BT, Anime4K, VLC fallback, and online rules.

## Capabilities

### New Capabilities
- `playback-state-contract`: Playback state snapshot, timeline, buffering, active-track, and observation contracts used by Domain/Playback consumers.

### Modified Capabilities

## Impact

- Affects Domain/Playback contract code under `lib/src/domain/playback/` and/or `lib/src/playback/`.
- Affects Dart-only runtime validation under `tools/player_core_runtime_check.dart` and checker wiring if new boundary checks are needed.
- May update `docs/phase1-player-core.md` or architecture notes to record the state boundary.
- Does not add Flutter, native player bindings, provider, streaming, storage, gateway, network, or external package dependencies.
