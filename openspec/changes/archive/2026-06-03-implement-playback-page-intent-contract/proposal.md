## Why

The playback page now has UI-owned surface descriptors, but it still lacks a framework-neutral contract for translating enabled controls into Domain playback commands. This change defines that intent boundary before any Flutter widget shell is introduced, keeping UI interactions capability-driven and testable in pure Dart.

## What Changes

- Add a playback page intent contract that represents user actions such as play/pause, seek, stop, opening secondary panels, and selecting tracks.
- Gate each executable intent against the active surface descriptor and Domain playback capabilities before dispatching to `PlaybackController`.
- Return explicit intent results for executed, ignored, and unsupported actions so future widgets can render deterministic feedback without importing playback internals.
- Keep the contract plain Dart and independent of Flutter widgets, native player bindings, provider systems, streaming systems, danmaku, subtitle rendering, BT, Anime4K, VLC fallback, online rules, and diagnostics integrations.

## Capabilities

### New Capabilities
- `playback-page-intent-contract`: UI-owned playback page intents and action dispatch rules that bridge surface descriptors to Domain playback controller commands.

### Modified Capabilities

## Impact

- Affects UI playback contract code under `lib/src/ui/playback/`.
- Affects Dart-only runtime validation under `tools/player_core_runtime_check.dart` and checker wiring if new boundary checks are needed.
- Does not add Flutter, MPV, provider, streaming, storage, gateway, network, or native player dependencies.
