## Context

Step 22 added `VideoEnhancementPipelineRuntime` and `VideoEnhancementPipelineBootstrap` as the acceptance layer wrapping the deterministic video enhancement pipeline with storage-backed projections, typed outcomes, and restart replay. The existing `DeterministicAVSyncGuard` in `av_sync_guard.dart` similarly evaluates drift samples, records health/degradation decisions to `AVSyncGuardStore`, and publishes invalidation events — but it lacks a bootstrap/runtime facade that provides scoped projections, typed result gates, unavailable/disposed state handling, and restart-replay data.

The current `DeterministicAVSyncGuard` directly uses `AVSyncGuardStore` and `CacheInvalidationBus` internally. The runtime layer will wrap it under a scoped contract so playback surfaces consume a stable `snapshot()`/`ingestSample()`/`requestDegradation()`/`checkRecovery()` API without depending on guard internals.

## Goals / Non-Goals

**Goals:**
- Add `AVSyncGuardBootstrap` that accepts guard store, per-scope guard maps, per-scope capability matrices, optional bus, and clock to create a runtime instance.
- Add `AVSyncGuardRuntime` that gates disposed/unavailable/unsupported states, delegates to the per-scope `DeterministicAVSyncGuard`, and returns typed `AVSyncGuardRuntimeActionResult<T>` outcomes.
- Add `AVSyncGuardRuntimeProjection` exposing current health, latest drift, latest degradation action, sample window metadata, and restart-replay projection from both in-memory and stored state.
- Add `AVSyncGuardRuntimeRestartProjection` to persist health and latest degradation action across restarts.
- Persist all health transitions and degradation decisions through the existing `AVSyncGuardStore` so projections can be rebuilt without in-memory guard state.
- Export the new runtime from the barrel file.
- Add focused tests, Dart smoke checker, and PowerShell boundary checker.

**Non-Goals:**
- No changes to `DeterministicAVSyncGuard` implementation or its interface.
- No integration with concrete timing probes, MPV properties, native FFI, or renderer callbacks.
- No VLC fallback selection logic or diagnostics center integration.
- No network policy, RSS automation, WebView session handling, or online source rule integration.
- No Flutter UI or widget changes.
- No changes to `AVSyncGuardStore` interface or storage contracts.

## Decisions

1. **Runtime wraps DeterministicAVSyncGuard rather than replacing it.**
   The deterministic guard already handles sample window evaluation, health transitions, degradation ordering, and invalidation events. The runtime adds the acceptance facade (dispose/unavailable gates, typed outcomes, projection snapshots, restart replay) without duplicating guard logic.
   Alternative: Merge runtime state into the guard directly. Rejected because it breaks the single-responsibility separation and makes the guard harder to test in isolation.

2. **`AVSyncGuardRuntimeActionResult<T>` mirrors the Step 22 pattern.**
   Using a generic result type with `success/failed/unavailable/disposed` constructors keeps the API consistent across runtime layers and simplifies consuming code.

3. **Restart projection reads from existing store — no new storage records.**
   The `AVSyncGuardStore` already records health and degradation history. The restart projection reads `latestHealth` and `degradationHistory` to rebuild its view. No new storage types are needed.

4. **Projection combines in-memory and stored state.**
   In-memory fields track the latest decision, latest drift, and sample count from the current session. Stored fields provide the durable baseline. Together they form the full projection without requiring the runtime to maintain all guard state.

5. **Scope-gate pattern matches Step 22.**
   `_gate()` checks disposed → unavailable → missing scope in order, returning early with typed failures. This is identical to the video enhancement pipeline runtime pattern.

## Risks / Trade-offs

- **Double health recording**: The `DeterministicAVSyncGuard` already records health to the store on `ingestSample()` and `checkRecovery()`. The runtime layer does not duplicate this — it reads from the store for projection but does not write additional health records. Risk: if the guard recording is incomplete, projections may show stale data. Mitigation: guard recording is deterministic and already tested.
- **Scope isolation**: The runtime creates one `DeterministicAVSyncGuard` per scope. Risk: memory usage scales with scope count. Mitigation: expected scope count is small (1-3 adapters).
- **Sample window warmup**: When restarting, the new guard instance starts with an empty sample window, so initial evaluations use single-sample mode until the window fills. Risk: first few evaluations after restart are less stable than a full window. Mitigation: this matches the guard's existing behavior and is documented in the contract spec.
