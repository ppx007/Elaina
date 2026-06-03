## Why

The playback shell can render mock state and dispatch page intents, but the controller boundary does not yet close a reactive intent-to-state loop for Flutter consumers. This change turns the existing controller contracts into the next stable orchestration boundary before native playback, providers, streaming, storage, or network systems are introduced.

## What Changes

- Extend the playback controller contract so page intents can be handled through a deterministic controller-facing boundary that updates observable playback state.
- Add a mock controller or driver bridge that maps `PlaybackPageIntent` values to controller commands and state snapshots without native playback or provider data.
- Keep `PlaybackPageContract`, `PlaybackStateObservable`, and `FlutterPlaybackPage` aligned so the shell can exercise controller-driven state changes in tests.
- Add validation that the controller loop remains framework-neutral below the UI layer and does not import Flutter, MPV, VLC, provider, gateway, storage, streaming, network, diagnostics, danmaku, Anime4K, or production state-management packages.

## Capabilities

### New Capabilities
- `playback-controller-contract`: Reactive controller orchestration boundary that accepts playback page intents, exposes observable playback state, and can be exercised with deterministic mock playback behavior.

### Modified Capabilities
- `flutter-playback-shell-contract`: The shell must be able to consume a controller-driven shell driver while preserving its UI-only layer boundary and mock-first scope.

## Impact

- Affects Domain playback controller contracts and UI playback contract integration.
- Affects the Flutter playback shell driver or tests so they can run through the controller boundary rather than only local mock state mutation.
- Does not add native video surfaces, MPV/libmpv/media-kit bindings, provider metadata, online parsing, gateway, storage, network, BT streaming, diagnostics, VLC fallback, routing, persistence, theming, or production state management.
