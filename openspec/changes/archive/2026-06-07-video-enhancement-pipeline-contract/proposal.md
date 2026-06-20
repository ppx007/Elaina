## Why

Phase 4 BT playback contracts are complete, so the plan moves to Phase 5 Step 22: durable video enhancement contracts. The existing `video-enhancement-pipeline` bootstrap defines declarative profile intent, but it does not yet provide persistence, deterministic evaluation/application outcomes, invalidation events, or focused verification comparable to the completed Phase 4 contract slices.

## What Changes

- Introduce a durable `video-enhancement-pipeline-contract` capability for enhancement profile persistence, deterministic profile evaluation, application/disable outcomes, render-budget reporting, and enhancement invalidation events.
- Refine the bootstrap `video-enhancement-pipeline` capability from high-level profile intent into a Step 22 contract boundary with explicit storage, capability gating, adapter rejection, render-budget, and AVSyncGuard handoff behavior.
- Extend local storage responsibilities for user/default enhancement profiles and active per-adapter or per-playback enhancement selection.
- Extend cache invalidation with enhancement events for profile selection, capability reevaluation, and pipeline state changes.
- Clarify playback capability matrix behavior for unsupported scaler, HDR, deband, and Anime4K-style profile rows.
- Keep concrete MPV shader graphs, Anime4K shader bundles, platform renderer plugins, VLC fallback behavior, diagnostics center integration, and Phase 6 automation out of scope.

## Capabilities

### New Capabilities
- `video-enhancement-pipeline-contract`: Durable Step 22 contract for storage-backed enhancement profiles, deterministic evaluation/application outcomes, render-budget snapshots, and enhancement invalidation events.

### Modified Capabilities
- `video-enhancement-pipeline`: Refine bootstrap requirements into durable Step 22 contracts for profile persistence, capability-gated profile evaluation, render-budget reporting, and typed application/disable failures.
- `local-storage-foundation`: Add storage responsibilities for video enhancement profiles, active profile selection, and latest pipeline state metadata.
- `cache-invalidation-bus`: Add video enhancement invalidation events for profile changes, capability reevaluation, and pipeline state transitions.
- `playback-capability-matrix`: Clarify advanced enhancement capability gating and unsupported reason behavior for scaler, HDR, deband, and Anime4K-style presets.

## Impact

- Affected code: `lib/src/playback/video_enhancement_pipeline.dart`, `lib/src/foundation/storage/`, `lib/src/foundation/cache_invalidation/`, `lib/src/playback/capability_matrix.dart` if capability helpers need refinement, `lib/elaina.dart`, focused tests, runtime checks, and `tools/check_advanced_playback_core.ps1`.
- Affected specs: new `video-enhancement-pipeline-contract` plus deltas for `video-enhancement-pipeline`, `local-storage-foundation`, `cache-invalidation-bus`, and `playback-capability-matrix`.
- Dependencies: existing Playback capability/profile contracts, Storage, and CacheInvalidationBus only; no concrete MPV/VLC/libmpv/media-kit shader implementation, no FFI/native plugin, no Flutter widget/rendering code, no diagnostics center, and no Phase 6 provider/network automation.
