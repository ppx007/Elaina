## Why

Phase 5 Step 25 is the final advanced playback contract slice: fallback from the primary player adapter to VLC or another secondary adapter. The bootstrap fallback contract already names optional fallback selection and capability hiding, but it lacks durable adapter registration, typed selection outcomes, invalidation events, capability reevaluation, failure normalization, tests, and checker coverage comparable to Steps 22-24.

## What Changes

- Add durable fallback adapter storage contracts for registered fallback candidates, active fallback configuration, fallback selection history, and latest fallback state metadata.
- Deepen `PlaybackFallbackStrategy` with typed registration, evaluation, selection, disable, and capability-reevaluation outcomes/failures instead of nullable selection success.
- Add a deterministic fallback strategy that evaluates primary adapter failures, source compatibility, candidate priority, and candidate capability matrices without concrete VLC bindings.
- Publish fallback invalidation events when adapters register/deregister, fallback capability state changes, fallback selection changes, or fallback state is disabled/rejected.
- Refine capability matrix behavior so fallback support and hidden capability reasons are explicit after fallback selection.
- Preserve optional fallback semantics: no concrete VLC package, native plugin, media-kit/libmpv coupling, Flutter UI, diagnostics center, Phase 6 automation, or mandatory secondary adapter dependency.
- Add focused tests, runtime checks, Phase 5 checker rules, and documentation proving Step 25 remains adapter-neutral and optional.

## Capabilities

### New Capabilities
- `vlc-fallback-adapter-contract`: Durable Step 25 contract for fallback adapter registration, typed fallback selection, capability hiding, invalidation, and optional secondary adapter behavior.

### Modified Capabilities
- `vlc-fallback-adapter`: Refine the bootstrap fallback strategy into typed outcomes, deterministic evaluation, and optional capability hiding semantics.
- `local-storage-foundation`: Add fallback adapter storage responsibilities for candidate registration, active fallback configuration, selection history, and latest fallback state metadata.
- `cache-invalidation-bus`: Add fallback adapter invalidation events for registration, capability reevaluation, selection changes, and state transitions.
- `playback-capability-matrix`: Require explicit fallback adapter support/unsupported reasons and hidden capability reporting after fallback selection.
- `mpv-adapter-boundary`: Clarify that normalized primary adapter failures can be consumed by fallback strategy contracts without exposing MPV, VLC, native, or UI dependencies.

## Impact

- Affected Dart contracts: `lib/src/playback/fallback_adapter.dart`, `lib/src/playback/capability_matrix.dart`, `lib/src/foundation/storage/storage_contracts.dart`, `lib/src/foundation/cache_invalidation/cache_invalidation_bus.dart`, and `lib/elaina.dart`.
- New storage contract file expected under `lib/src/foundation/storage/` for fallback adapter persistence.
- Verification updates expected in `test/playback/`, `tools/player_core_runtime_check.dart`, `tools/check_advanced_playback_core.ps1`, and `docs/phase5-advanced-playback-core.md`.
- No new external dependencies, native bindings, VLC packages, Flutter widgets, diagnostics center integration, RSS automation, online rule runtime, WebView handling, DNS/network policy, or Phase 6 provider automation.
