## Why

The Player core runtime slice now exposes capability-driven playback surface state, but the UI layer still only forwards raw Domain state and does not define a stable page-facing surface model. This change creates a Dart-only playback page surface contract so future Flutter widgets can render controls and panels without importing Playback internals, native player engines, providers, streaming, or later-phase systems.

## What Changes

- Add a UI-owned playback page surface contract that maps `PlaybackSurfaceState` into stable, renderable UI control and panel descriptors.
- Keep the surface contract Dart-only and framework-neutral; no Flutter widget, native player binding, video surface, styling, animation, or layout implementation is added.
- Add runtime checks proving unsupported capabilities are hidden rather than exposed as active controls.
- Extend player-core validation to assert the UI layer remains free of concrete MPV/VLC/native/provider/streaming dependencies.
- Preserve the current Domain/Playback boundary: Domain exposes controller state and commands; UI owns presentation mapping.

## Capabilities

### New Capabilities

- `playback-page-surface-contract`: Defines the UI-layer playback page surface model, mapping rules, and validation contract for renderable controls and panel entry points.

### Modified Capabilities

- `playback-page-foundation`: Clarifies that playback page foundation is consumed through a UI-owned surface contract rather than raw widgets or concrete player/native dependencies.

## Impact

- Affected code: `lib/src/ui/playback/`, `lib/src/domain/playback/` only as imported contracts, and project checker scripts under `tools/`.
- Affected specs: new `playback-page-surface-contract` plus modified `playback-page-foundation`.
- Dependencies: no new runtime package dependency is expected.
- Boundaries: UI may depend on Domain-facing playback contracts; Domain/Playback MUST NOT import UI contracts; UI MUST NOT import MPV, VLC, libmpv, media-kit, provider internals, streaming internals, or native player bindings.
