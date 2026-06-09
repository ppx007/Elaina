## Why

Phase 2 / Step 11 Dandanplay provider runtime is complete, so the architecture plan's next slice is Phase 2 / Step 12: basic danmaku rendering. Existing code defines danmaku comments, filters, density policy, render lanes, and a `BasicDanmakuRenderer` contract, but there is no deterministic runtime that turns player-clock-aligned comments into render frames or exposes those frames to Domain and playback-page surface descriptors.

## What Changes

- Add a deterministic basic danmaku runtime for scrolling, top, and bottom comments using `PlayerClockSnapshot` as the only timing source.
- Add concrete basic renderer behavior for filtering, density limits, lane grouping, clock-window eligibility, and lifecycle-safe frame resolution without Matrix4 effects, Flutter widgets, native rendering handles, ProviderGateway access, or Dandanplay network coupling.
- Add Domain-facing danmaku state projection and playback surface descriptors so future UI can consume framework-neutral overlay data without depending on Playback internals.
- Add bridge helpers that normalize Dandanplay comment records into Playback-layer `DanmakuComment` values while keeping provider retrieval/posting and rendering separated.
- Add focused tests and validation scripts proving basic danmaku remains player-clock-driven, deterministic, density/filter-aware, and independent from advanced caption rendering, providers, RSS, BT, online-rule, network, storage, and concrete UI rendering.
- No breaking changes.

## Capabilities

### New Capabilities
- `phase2-basic-danmaku-runtime`: Deterministic runtime/bootstrap for player-clock-aligned basic danmaku rendering, frame snapshots, lifecycle behavior, Dandanplay comment normalization, Domain state projection, surface descriptors, tests, and validation.

### Modified Capabilities
- `basic-danmaku-rendering`: Existing basic danmaku contracts gain runtime, lifecycle, deterministic renderer, and provider-comment normalization requirements.
- `playback-state-contract`: Playback state gains a framework-neutral basic danmaku overlay state that remains independent from provider/network/native-renderer concerns.
- `playback-page-surface-contract`: Playback page surface descriptors gain a framework-neutral basic danmaku overlay descriptor while preserving UI ownership and excluding concrete renderer/widget/native-player dependencies.
- `repository-baseline`: The repository baseline gains a requirement that Step 12 basic danmaku runtime remains a playback overlay capability and must not become a Provider, RSS, BT, online-rule, network, storage, Flutter UI, Matrix4, or native-player prerequisite.

## Impact

- Affected code: `lib/src/playback/danmaku/`, `lib/src/domain/playback/`, `lib/src/domain/acg/` or a narrow danmaku bridge module, `lib/src/ui/playback/`, public Dart barrel exports, focused playback danmaku tests, runtime smoke checks, and validation scripts.
- Affected specs: new `phase2-basic-danmaku-runtime` plus deltas for `basic-danmaku-rendering`, `playback-state-contract`, `playback-page-surface-contract`, and `repository-baseline`.
- Dependencies: no concrete Flutter widget, Canvas/CustomPainter, Matrix4 advanced danmaku, native player, MPV/VLC renderer binding, ProviderGateway, Dandanplay HTTP transport, RSS, BT, online-rule, network policy, storage migration, or diagnostics integration is introduced in this runtime slice.
