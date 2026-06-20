## Context

Phase 5 Step 22 deepened `VideoEnhancementPipeline` with budget-pressure snapshots and degradation targets, but it intentionally left deterministic drift policy to AVSyncGuard. The existing `av_sync_guard.dart` bootstrap defines `AVSyncSample`, `AVSyncPolicy`, `AVSyncDecision`, and an abstract `AVSyncGuard`, but it has no durable policy/state records, no sample history window, no typed evaluation/degradation outcomes, and no invalidation events.

This change deepens Phase 5 Step 23 without binding Elaina to MPV/libmpv timing APIs or native renderer callbacks. The contract must normalize adapter-provided drift/frame timing data, decide health transitions from declared policy thresholds, and emit deterministic degradation decisions that later concrete adapters can execute.

## Goals / Non-Goals

**Goals:**
- Define storage-backed AV sync policy, latest health, sample history metadata, and degradation decision records.
- Define deterministic guard evaluation over drift samples and enhancement pressure using the 40ms target and 120ms red-line thresholds.
- Define typed evaluation and degradation outcomes/failures rather than throwing concrete adapter exceptions.
- Publish cache invalidation events when sync samples are ingested, health changes, degradation is requested, or guard state recovers.
- Preserve Step 22 enhancement budget handoff as input data while making AVSyncGuard own drift/degradation policy ordering.
- Add focused tests and checker coverage that prove Step 23 remains adapter-neutral and implementation-neutral.

**Non-Goals:**
- No concrete MPV/libmpv/media-kit property polling, native plugin, FFI, platform renderer callback, or shader timing implementation.
- No concrete VideoEnhancementPipeline adapter application; AVSyncGuard emits decisions, it does not execute renderer changes.
- No VLC fallback adapter selection or failover behavior; fallback remains Step 25.
- No advanced caption renderer implementation; caption degradation actions remain declarative until Step 24 deepens that slice.
- No diagnostics center integration, DNS/network policy, online rule runtime, RSS automation, WebView challenge handling, Flutter widgets, or UI rendering implementation.

## Decisions

1. **Use sample windows, not single-sample spikes, for state transitions.**
   - Decision: AVSyncGuard contracts should persist bounded sample metadata and evaluate sustained drift windows before transitioning from target to warning or degraded.
   - Rationale: a one-sample spike can occur during seek, buffering, or adapter startup; deterministic guard decisions need stable state rather than noise.
   - Alternative considered: evaluate only the latest sample. Rejected because it would make red-line degradation too twitchy and hard to test.

2. **Keep threshold policy declarative and storage-safe.**
   - Decision: policy records store target drift, warning/red-line thresholds, recovery threshold, sample-window size, and ordered degradation actions as simple values.
   - Rationale: future platforms can tune policy without persisting renderer handles, MPV properties, or native state.
   - Alternative considered: encode concrete MPV timing property names in policy. Rejected because it would violate adapter replaceability.

3. **Emit typed outcomes for evaluation and degradation requests.**
   - Decision: evaluation returns health/outcome data; degradation request returns a typed accepted/rejected outcome with the chosen `AVSyncDegradationAction`.
   - Rationale: Phase 4 and Step 22 contracts use explicit outcomes that are easy to test without native adapters.
   - Alternative considered: keep `AVSyncDecision evaluate(sample)` only. Rejected because it cannot express missing capability, insufficient sample history, or rejected degradation deterministically.

4. **Publish AV sync state through CacheInvalidationBus.**
   - Decision: define events for sample ingestion, health transition, degradation decision, and recovery.
   - Rationale: existing contract slices refresh derived state through event-driven invalidation instead of cross-module mutation.
   - Alternative considered: direct callbacks into playback UI or diagnostics. Rejected because UI and diagnostics are outside this slice.

## Risks / Trade-offs

- **Risk: AVSyncGuard becomes a concrete MPV timing adapter too early.** → Mitigation: specs and checker rules forbid libmpv/media-kit/native/FFI/timing-probe dependencies in Step 23 contracts.
- **Risk: The guard overlaps with VideoEnhancementPipeline execution.** → Mitigation: AVSyncGuard emits ordered degradation decisions only; concrete enhancement application remains future adapter work.
- **Risk: Sustained drift windows delay degradation.** → Mitigation: policy includes red-line threshold semantics and sample-window sizing so tests can model immediate vs sustained transitions deterministically.
- **Risk: Recovery semantics are ambiguous.** → Mitigation: define recovery as a health transition contract with explicit threshold/window inputs, not as diagnostics/UI behavior.

## Migration Plan

1. Add `av-sync-guard-contract` specs and deltas for affected capabilities.
2. Extend Dart contracts with AV sync storage records, deterministic guard outcomes, sample window evaluation, and invalidation events.
3. Update public exports, runtime checks, tests, and advanced playback checker rules.
4. Validate with OpenSpec, analyzer, tests, runtime checks, and Phase 5 checker scripts.

Rollback is straightforward because this change introduces contract/value/state scaffolding only; no concrete native renderer, external dependency, or adapter runtime is introduced.

## Open Questions

- None blocking for the contract slice. Concrete MPV timing property mapping, platform renderer sampling, diagnostics snapshots, and adapter execution of degradation decisions are intentionally deferred.
