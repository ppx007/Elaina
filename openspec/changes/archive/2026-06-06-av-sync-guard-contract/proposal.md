## Why

Phase 5 Step 22 now exposes video enhancement render-budget pressure and degradation targets as contract data, but the existing `av-sync-guard` bootstrap only defines one-shot drift samples and an abstract guard interface. The next architecture-plan step is Phase 5 Step 23: durable AV sync guard contracts for sustained drift evaluation, deterministic red-line degradation, state persistence, and invalidation without implementing concrete MPV/native timing probes.

## What Changes

- Introduce a durable `av-sync-guard-contract` capability for persisted sync guard policy/state, sample history metadata, deterministic health transitions, degradation decisions, and invalidation events.
- Refine the bootstrap `av-sync-guard` capability from a single-sample interface into a Step 23 contract boundary with typed evaluation/degradation outcomes, 40ms target and 120ms red-line semantics, sustained drift windows, and recovery behavior.
- Extend local storage responsibilities for AV sync policy configuration, latest guard health, sampled drift metadata, and degradation decision history.
- Extend cache invalidation with AV sync events for sample ingestion, health transitions, degradation decisions, and recovery state changes.
- Clarify playback capability matrix behavior for `avSyncGuard` support and unsupported reasons before playback surfaces or adapters rely on automatic degradation.
- Keep concrete MPV/libmpv timing probes, native plugins, FFI, renderer frame callbacks, VLC fallback selection, diagnostics center integration, Flutter UI rendering, and Phase 6 automation out of scope.

## Capabilities

### New Capabilities
- `av-sync-guard-contract`: Durable Step 23 contract for storage-backed AV sync guard policy/state, sustained drift evaluation, deterministic degradation outcomes, and AV sync invalidation events.

### Modified Capabilities
- `av-sync-guard`: Refine bootstrap requirements into typed durable contracts for sample evaluation, health transitions, red-line degradation, recovery, and ordered policy decisions.
- `video-enhancement-pipeline`: Clarify how enhancement budget pressure and degradation targets are consumed by AVSyncGuard without making the enhancement pipeline own drift policy.
- `local-storage-foundation`: Add storage responsibilities for AV sync guard policy, latest health state, sample history metadata, and degradation decision history.
- `cache-invalidation-bus`: Add AV sync invalidation events for sample ingestion, health transitions, degradation decisions, and recovery updates.
- `playback-capability-matrix`: Clarify `avSyncGuard` capability gating and unsupported reason behavior.

## Impact

- Affected code: `lib/src/playback/av_sync_guard.dart`, `lib/src/playback/video_enhancement_pipeline.dart` if handoff types need refinement, `lib/src/playback/capability_matrix.dart`, `lib/src/foundation/storage/`, `lib/src/foundation/cache_invalidation/cache_invalidation_bus.dart`, `lib/elaina.dart`, focused tests, runtime checks, and `tools/check_advanced_playback_core.ps1`.
- Affected specs: new `av-sync-guard-contract` plus deltas for `av-sync-guard`, `video-enhancement-pipeline`, `local-storage-foundation`, `cache-invalidation-bus`, and `playback-capability-matrix`.
- Dependencies: existing Playback contracts, VideoEnhancementPipeline budget-pressure read models, Storage, and CacheInvalidationBus only; no concrete MPV/VLC/libmpv/media-kit timing integration, no FFI/native plugin, no Flutter widget/rendering code, no diagnostics center, and no Phase 6 provider/network automation.
