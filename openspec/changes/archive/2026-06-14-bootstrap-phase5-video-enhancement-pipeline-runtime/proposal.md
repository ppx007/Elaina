## Why

Phase 5 Step 22 needs a runtime acceptance layer for the existing declarative video enhancement pipeline contracts. The current contract can evaluate/apply enhancement profiles, but there is no bootstrap/runtime surface that restores durable state, exposes typed action outcomes, or validates the Step 22 boundary before future AVSyncGuard and advanced playback work build on it.

## What Changes

- Add a Step 22 `VideoEnhancementPipelineRuntime` and bootstrap surface around the existing deterministic enhancement profile contracts.
- Persist and replay active enhancement profile state, latest pipeline state, budget pressure, and degradation targets through storage-safe contracts.
- Return typed runtime outcomes for evaluate, apply, disable, degradation request, unavailable runtime, rejected profile, and disposed runtime states.
- Publish profile/capability/state invalidation events only after storage-visible state changes.
- Add focused runtime tests, a Dart smoke checker, and a PowerShell boundary checker for Step 22.
- Keep concrete shader graphs, MPV/VLC/native renderer bindings, AVSyncGuard policy, diagnostics, network/RSS automation, captions, fallback adapter behavior, and Flutter rendering out of this slice.

## Capabilities

### New Capabilities
- `phase5-video-enhancement-pipeline-runtime`: Runtime/bootstrap acceptance layer for Phase 5 Step 22 video enhancement profile evaluation, application, disable, degradation, restart replay, and boundary validation.

### Modified Capabilities
- `video-enhancement-pipeline`: Refine runtime-facing requirements for bootstrap projections, typed runtime outcomes, and render-budget handoff without AVSyncGuard policy ownership.
- `video-enhancement-pipeline-contract`: Require runtime action outcomes, restart-safe profile/state replay, and Step 22 boundary checks over the existing declarative contract.
- `local-storage-foundation`: Require persisted enhancement runtime state sufficient to distinguish disabled, evaluated, applied, rejected, degraded, active-profile, and latest budget-pressure replay states.
- `cache-invalidation-bus`: Require Step 22 profile/capability/state invalidations to publish only after corresponding state is storage-visible.
- `repository-baseline`: Add the Step 22 optional runtime baseline and boundary-validation guard.

## Impact

- Affected production code: `lib/src/playback/video_enhancement_pipeline.dart`, new `lib/src/playback/video_enhancement_pipeline_runtime.dart`, `lib/src/foundation/storage/video_enhancement_storage_contracts.dart`, `lib/src/foundation/cache_invalidation/cache_invalidation_bus.dart`, and `lib/elaina.dart`.
- Affected tests/tools: new `test/playback/video_enhancement_pipeline_runtime_test.dart`, `tools/video_enhancement_pipeline_runtime_check.dart`, and `tools/check_video_enhancement_pipeline_runtime.ps1`; existing contract tests remain regression gates.
- No new package dependencies, native bindings, renderer integrations, platform channels, UI components, diagnostics center behavior, or AVSyncGuard policy implementation are introduced.
