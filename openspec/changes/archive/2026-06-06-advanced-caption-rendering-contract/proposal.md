## Why

Phase 5 Step 22 and Step 23 now provide durable video enhancement and AV sync guard contracts, so the plan moves to Phase 5 Step 24: advanced danmaku and subtitle rendering. The existing `advanced-caption-rendering` bootstrap defines feature names and request shapes, but it does not yet provide storage-backed preferences, typed rendering outcomes, deterministic capability evaluation, invalidation events, or focused verification comparable to the completed Phase 5 contract slices.

## What Changes

- Introduce a durable `advanced-caption-rendering-contract` capability for advanced caption preference persistence, deterministic feature evaluation, typed render/degradation outcomes, and advanced caption invalidation events.
- Refine the bootstrap `advanced-caption-rendering` capability from high-level Matrix4 danmaku, dual-subtitle, PGS, and ASS enhancement requests into a Step 24 contract boundary with explicit feature flags, capability rejection, ordered subtitle state, and degradation behavior.
- Extend local storage responsibilities for advanced caption profiles, active per-playback feature selection, dual-subtitle preferences, and latest caption renderer state metadata.
- Extend cache invalidation with advanced caption events for feature changes, capability reevaluation, renderer state transitions, dual-subtitle selection, and AVSyncGuard-driven degradation.
- Clarify playback capability matrix behavior for Matrix4 danmaku, dual subtitles, PGS subtitle rendering, and ASS subtitle enhancement support and unsupported reasons.
- Clarify basic danmaku and subtitle boundaries so Matrix4 transforms, dual subtitles, PGS image subtitle intent, and ASS enhancement remain rendering-layer contracts without mutating basic parser, cue, filter, or density contracts.
- Clarify AVSyncGuard handoff so `disableAdvancedCaptions` remains a declarative degradation decision consumed by Step 24 contracts, not a direct renderer mutation.
- Keep concrete GPU/Flutter rendering, PGS decoding, ASS layout engines, native plugins, FFI, VLC fallback behavior, diagnostics center integration, and Phase 6 automation out of scope.

## Capabilities

### New Capabilities
- `advanced-caption-rendering-contract`: Durable Step 24 contract for storage-backed advanced caption preferences, deterministic feature evaluation, typed rendering outcomes, degradation handling, and advanced caption invalidation events.

### Modified Capabilities
- `advanced-caption-rendering`: Refine bootstrap requirements into durable Step 24 contracts for Matrix4 danmaku, ordered dual subtitles, PGS image subtitle intent, ASS enhancement intent, feature flags, and typed outcomes.
- `local-storage-foundation`: Add storage responsibilities for advanced caption profiles, active feature selection, dual-subtitle selection, and latest renderer state metadata.
- `cache-invalidation-bus`: Add advanced caption invalidation events for feature changes, capability reevaluation, renderer state transitions, dual-subtitle selection, and degradation state changes.
- `playback-capability-matrix`: Clarify explicit support and unsupported reason behavior for Matrix4 danmaku, dual subtitles, PGS subtitle rendering, and ASS subtitle enhancement.
- `av-sync-guard`: Clarify that advanced caption degradation is a declarative AVSyncGuard decision consumed by Step 24 contracts without direct renderer mutation.
- `basic-danmaku-rendering`: Clarify that Matrix4 danmaku transforms are advanced rendering overlays that preserve basic player-clock, filter, and density contracts.
- `basic-subtitle-core`: Clarify that dual subtitles, PGS rendering intent, and ASS enhancement are advanced rendering contracts that preserve basic subtitle source, parser, cue, scanner, and offset contracts.

## Impact

- Affected code: `lib/src/playback/advanced_caption_rendering.dart`, `lib/src/playback/danmaku/`, `lib/src/playback/subtitle/`, `lib/src/playback/av_sync_guard.dart` if degradation handoff types need refinement, `lib/src/playback/capability_matrix.dart`, `lib/src/foundation/storage/`, `lib/src/foundation/cache_invalidation/cache_invalidation_bus.dart`, `lib/celesteria.dart`, focused tests, runtime checks, and `tools/check_advanced_playback_core.ps1`.
- Affected specs: new `advanced-caption-rendering-contract` plus deltas for `advanced-caption-rendering`, `local-storage-foundation`, `cache-invalidation-bus`, `playback-capability-matrix`, `av-sync-guard`, `basic-danmaku-rendering`, and `basic-subtitle-core`.
- Dependencies: existing Playback caption/danmaku/subtitle contracts, Storage, CacheInvalidationBus, PlaybackCapabilityMatrix, and AVSyncGuard degradation decisions only; no concrete Flutter widget tree, GPU renderer, PGS decoder, ASS layout engine, VLC adapter, diagnostics center, native plugin, FFI, or Phase 6 provider/network automation.
