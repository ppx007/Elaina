## Context

Phase 5 Step 22 already has declarative video enhancement contracts in `VideoEnhancementPipeline`, `EnhancementProfileStore`, and `CacheInvalidationBus`. The deterministic pipeline can evaluate, apply, disable, and degrade enhancement profiles, and storage can persist active profiles plus latest pipeline state metadata. What is missing is the runtime acceptance layer that bootstraps these contracts into a restart-safe surface with typed outcomes, durable projections, and explicit Step 22 boundary validation.

This change follows the adjacent runtime slices: keep the contract implementation deterministic, wrap it with a runtime/bootstrap surface, expose immutable projections, publish invalidations only after storage-visible mutations, and add focused test/checker coverage before later Phase 5 work depends on the surface.

## Goals / Non-Goals

**Goals:**
- Add `VideoEnhancementPipelineRuntime` and `VideoEnhancementPipelineBootstrap` around existing pipeline/storage/cache contracts.
- Expose typed runtime action results for evaluate, apply, disable, degradation request, unavailable dependency, rejected profile, and disposed runtime states.
- Restore active profile, latest pipeline state, render budget pressure, and degradation target through restart-safe projections.
- Preserve the Step 22 boundary: declarative enhancement intent only, with AVSyncGuard receiving pressure data but owning sync policy.
- Add focused runtime tests, a Dart smoke checker, and a PowerShell boundary checker.

**Non-Goals:**
- No concrete MPV shader graph, Anime4K shader bundle, native renderer, FFI, platform channel, media-kit, or VLC fallback implementation.
- No AVSyncGuard policy implementation, drift threshold decision, or ordered degradation execution.
- No Flutter UI, widget, gesture, tooltip, diagnostics center, network, RSS automation, captions, or fallback adapter behavior.
- No new package dependency or storage migration.

## Decisions

### Runtime wraps the existing deterministic pipeline
The runtime SHALL compose `EnhancementProfileStore`, `VideoEnhancementPipeline`, `PlaybackCapabilityMatrix`, and optional `CacheInvalidationBus` rather than moving evaluation logic out of `video_enhancement_pipeline.dart`.

Alternative considered: widen `VideoEnhancementPipeline` itself into a runtime. Rejected because existing contract tests already validate the deterministic contract, and adjacent slices keep bootstrap/restart concerns in separate runtime files.

### Storage state remains sufficient unless RED tests prove otherwise
The existing store records profiles, active profile selection, and latest pipeline state, including supported/rejected/degraded states, failure reason, budget pressure, and degradation target. The runtime should first use these contracts for restart projection.

Alternative considered: add new storage records up front. Rejected because speculative storage widening would create migration surface without a failing contract.

### Invalidation ordering is storage-first
Runtime methods that change profile or pipeline state SHALL persist the relevant state before publishing `EnhancementProfileChanged`, `EnhancementCapabilityReevaluated`, or `EnhancementPipelineStateChanged`.

Alternative considered: rely only on the inner deterministic pipeline's events. Rejected for runtime acceptance because tests need to prove callers can observe storage-visible state after invalidation.

### AVSyncGuard receives pressure data but remains policy owner
Runtime projections MAY expose latest budget pressure and candidate degradation target from storage state, but they MUST NOT evaluate drift, choose AV sync health transitions, or execute AVSyncGuard degradation ordering.

Alternative considered: add a convenience degradation policy to Step 22. Rejected because Step 23 owns drift thresholds and red-line policy.

### Boundary checks are acceptance criteria
The PowerShell checker SHALL reject concrete renderer/shader/native/UI/network/diagnostics/later-phase leakage in runtime, tests, and checker files while allowing declarative Step 22 terms such as `VideoEnhancement`, `RenderBudgetInput`, and `AVSyncGuard` references in contract handoff language.

Alternative considered: rely only on Dart analyzer and unit tests. Rejected because scope leakage is the main failure mode for this phase boundary.

## Risks / Trade-offs

- [Risk] Runtime duplicates some invalidation responsibilities already present in the deterministic pipeline -> Mitigation: tests assert storage-visible ordering and runtime can suppress or coordinate duplicate publication if required.
- [Risk] Checker forbidden terms can false-positive on allowed declarative words -> Mitigation: pattern lists must distinguish allowed profile/pressure terms from concrete renderer/native/UI implementation terms.
- [Risk] Restart projection may under-specify historical states -> Mitigation: runtime exposes current active profile and latest pipeline state only; deeper history remains out of scope until diagnostics/storage migration work.
- [Risk] Step 22 could drift into Step 23 policy -> Mitigation: specs and checker explicitly reject AVSyncGuard policy, drift thresholds, and ordered degradation execution.

## Migration Plan

1. Add RED runtime tests for bootstrap projection, supported/unsupported actions, restart replay, invalidation ordering, unavailable/disposed behavior, and boundary regressions.
2. Implement the minimal runtime/bootstrap surface and export it from `lib/elaina.dart`.
3. Add Dart smoke checker and PowerShell boundary checker.
4. Run focused playback tests, smoke checker, boundary checker, `dart analyze`, and OpenSpec validation.
5. Mark tasks complete only after evidence exists.

Rollback is straightforward because this change adds an optional runtime surface; reverting the runtime/export/tests/checkers leaves existing Step 22 deterministic contracts intact.
