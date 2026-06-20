## Why

Phase 5 Step 24 (advanced caption rendering) has a fully implemented contract layer (`AdvancedCaptionRenderer` interface + `DeterministicAdvancedCaptionRenderer` + storage + invalidation) but no runtime/bootstrap acceptance layer. Without the runtime, the playback domain cannot declaratively gate operations by scope, project typed action results across all caption operations, or replay active profile + renderer state + dual subtitle selection after restart — the same gap that Steps 22/23 filled for video enhancement and AV sync guard.

## What Changes

- Add `AdvancedCaptionRuntimeBootstrap` that accepts a caption store, per-scope renderer map, per-scope capabilities, optional cache invalidation bus, and creates scoped `AdvancedCaptionRuntime` instances
- Add `AdvancedCaptionRuntime` that gates all operations (evaluate, renderMatrixDanmaku, renderDualSubtitles, renderAdvancedSubtitle, disable, acceptDegradation) behind disposed/unavailable/unsupported checks with typed `AdvancedCaptionRuntimeActionResult<T>` outcomes
- Add `AdvancedCaptionRuntimeFailureKind` domain failure kinds (capabilityUnsupported, unavailable, disposed, featureDisabled, profileNotFound, dualSubtitleOrderRejected, staleEvaluation, avSyncDegradation)
- Add `AdvancedCaptionRuntimeProjection` / `AdvancedCaptionRuntimeRestartProjection` that combine in-memory latest state with stored active profile, renderer state, and dual subtitle selection for restart replay
- Add validation checkers (Dart smoke + PowerShell boundary) and OpenSpec delta specs

## Capabilities

### New Capabilities
- `phase5-advanced-caption-rendering-runtime`: Runtime acceptance layer for advanced caption rendering — bootstrap, projection, restart replay, gate states, and boundary constraints

### Modified Capabilities
- `advanced-caption-rendering`: Add runtime projection and typed action result requirements
- `advanced-caption-rendering-contract`: Add runtime ActionResult scenario and boundary enforcement update
- `cache-invalidation-bus`: Add runtime-published caption invalidation events (profile change, capability reevaluation, state change, dual subtitle selection, degradation)
- `local-storage-foundation`: Add runtime restart replay and degradation decision persistence requirements
- `repository-baseline`: Add Step 24 runtime boundary baseline entry

## Impact

- New file: `lib/src/playback/advanced_caption_rendering_runtime.dart`
- Barrel export addition in `lib/elaina.dart`
- New test: `test/playback/advanced_caption_rendering_runtime_test.dart`
- New checkers: `tools/advanced_caption_rendering_runtime_check.dart`, `tools/check_advanced_caption_rendering_runtime.ps1`
- Six delta spec files under `openspec/changes/.../specs/`
