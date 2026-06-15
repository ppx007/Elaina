## Why

The AVSyncGuard deterministic implementation already evaluates drift, records health and degradation decisions, and publishes cache invalidation events. However there is no bootstrap/runtime acceptance layer that provides storage-backed restart replay, typed scoped outcomes, unavailable/disposed gates, or projection snapshots — the same gap that Step 22 filled for VideoEnhancementPipeline. Without this layer, playback flows cannot restore guard state across process restarts or consume scoped AV sync decisions through a stable runtime contract.

## What Changes

- Add `AVSyncGuardBootstrap` to accept guard store, per-scope determinstic guard instances, per-scope capability matrices, optional cache invalidation bus, and injected clock, then produce a runtime via `createRuntime()`.
- Add `AVSyncGuardRuntime` with scoped `snapshot()`, `ingestSample()`, `requestDegradation()`, `checkRecovery()`, and `dispose()` — all returning typed `AVSyncGuardRuntimeActionResult<T>` outcomes.
- Add `AVSyncGuardRuntimeProjection` exposing current health, latest drift, latest degradation target, sample count, and restart-replay fields from both in-memory and stored guard state.
- Add `AVSyncGuardRuntimeRestartProjection` so restart flows can replay active health and latest decision without re-ingesting samples.
- Add `AVSyncGuardRuntimeFailureKind` (unsupported, unavailable, disposed, policyNotConfigured, insufficientSamples) and `AVSyncGuardRuntimeFailure` for typed error outcomes.
- Gate all operations against disposed/unavailable/unsupported-capability states.
- Persist health transitions and degradation decisions via existing `AVSyncGuardStore` on each applicable operation so projections survive restart.
- Export the new runtime from the barrel file.
- Add focused runtime tests, Dart smoke checker, and PowerShell boundary checker.

## Capabilities

### New Capabilities
- `phase5-av-sync-guard-runtime`: Runtime acceptance layer for AV sync guard — bootstrap, scoped projections, typed outcomes, restart replay, dispose/unavailable gates.

### Modified Capabilities
- `av-sync-guard`: Add requirement for runtime acceptance layer that wraps deterministic guard with storage-backed projections and typed runtime outcomes.
- `av-sync-guard-contract`: Add requirement for runtime-level action results, restart projection contracts, and boundary scope guard against native/MPV/VLC/FFI/renderer/diagnostics dependencies.
- `cache-invalidation-bus`: Add requirement that AV sync guard runtime publishes invalidation events through the bus on health transitions, degradation decisions, and recovery.
- `local-storage-foundation`: Add requirement for AV sync guard runtime to persist and replay health and degradation state via existing guard store contracts.
- `repository-baseline`: Add Step 23 runtime acceptance boundary and scope constraint.

## Impact

- New file: `lib/src/playback/av_sync_guard_runtime.dart`
- Modified barrel: `lib/celesteria.dart` (add export)
- New test: `test/playback/av_sync_guard_runtime_test.dart`
- New tools: `tools/av_sync_guard_runtime_check.dart`, `tools/check_av_sync_guard_runtime.ps1`
- No changes to existing `av_sync_guard.dart` or `av_sync_guard_storage_contracts.dart`
- No native/UI/MPV/VLC/FFI/shader/diagnostics/network/RSS/captions/fallback dependencies
