## Context

Phase 4 is complete and archived through `timeline-overlay-contract`, so the architecture plan moves to Phase 5 Step 22: `VideoEnhancementPipeline`. The Phase 5 bootstrap already created declarative enhancement profile value types and an abstract `VideoEnhancementPipeline` interface, but it did not add durable profile persistence, typed deterministic evaluation/application outcomes, invalidation events, or focused verification comparable to the completed Phase 4 contract slices.

This change deepens Step 22 without implementing concrete renderer behavior. The contract must describe profile intent and adapter capability negotiation for scaler, HDR handling, deband, and Anime4K-style presets while keeping MPV shader graphs, Anime4K bundles, native plugins, VLC fallback, diagnostics center behavior, and AVSyncGuard policy implementation outside this slice.

## Goals / Non-Goals

**Goals:**
- Define storage-backed enhancement profile records for built-in, user-defined, and active selected profiles.
- Define deterministic profile evaluation, application, disable, and degradation-request outcomes with typed failures.
- Publish enhancement invalidation events when profile selection, capability evaluation, or pipeline state changes.
- Preserve render-budget inputs as contract data that can be consumed by future AVSyncGuard work without making this change own sync policy.
- Add focused tests and checker coverage that prove Step 22 remains declarative, capability-gated, and implementation-neutral.

**Non-Goals:**
- No concrete MPV/libmpv/media-kit shader graph, shader compiler, Anime4K shader bundle, native plugin, FFI, or platform renderer implementation.
- No AVSyncGuard deterministic degradation policy implementation; this change only exposes budget/degradation handoff values for Step 23.
- No VLC fallback adapter behavior, fallback selection, or capability hiding beyond enhancement capability status.
- No diagnostics center, DNS/network policy, online rule runtime, RSS automation, WebView challenge handling, Flutter widgets, or UI rendering implementation.

## Decisions

1. **Keep profiles declarative and adapter-neutral.**
   - Decision: profile contracts store scaler/HDR/deband/Anime4K intent, not MPV options or shader file paths.
   - Rationale: UI and Domain code need a portable enhancement vocabulary before concrete adapters exist.
   - Alternative considered: persist concrete MPV shader options now. Rejected because it would make MPV the architecture default and violate adapter replaceability.

2. **Use typed outcomes for every pipeline action.**
   - Decision: evaluation, apply, disable, and degradation request flows should return typed outcomes/failures rather than `void` or thrown implementation exceptions.
   - Rationale: Phase 4 deterministic contracts use explicit success/failure results and tests can verify capability rejection without native adapters.
   - Alternative considered: keep the bootstrap `Future<void> apply()` shape only. Rejected because it cannot express unsupported profile components, stale capability reports, or adapter rejection deterministically.

3. **Persist only profile and pipeline-state metadata.**
   - Decision: storage should cover enhancement profiles, active profile selection, and latest pipeline state metadata; it must not store renderer internals.
   - Rationale: restart-safe user/default profile selection is required, but shader state belongs to future concrete adapters.
   - Alternative considered: no storage in Step 22. Rejected because earlier durable contract slices persist profile/selection state when user-facing configuration exists.

4. **Publish enhancement events through `CacheInvalidationBus`.**
   - Decision: define events for profile changes, capability reevaluation, and pipeline state transitions.
   - Rationale: existing slices refresh derived state through event-driven invalidation rather than direct module mutation.
   - Alternative considered: direct callbacks from Playback to UI. Rejected because it bypasses the established bus and would couple future UI to Playback internals.

## Risks / Trade-offs

- **Risk: Enhancement profiles become MPV-specific too early.** → Mitigation: checker rules and specs forbid shader graphs, shader paths, libmpv/media-kit bindings, and native plugin terms in Step 22 contracts.
- **Risk: Step 22 overlaps with AVSyncGuard.** → Mitigation: expose render-budget snapshots and requested degradation targets only; deterministic drift/degradation policy remains Step 23.
- **Risk: Capability gating becomes ambiguous.** → Mitigation: evaluation outcomes must include supported/unsupported status and reason strings for unsupported profile components.
- **Risk: Profile persistence creates migration obligations.** → Mitigation: keep records small, schema-neutral, and implementation-independent so future concrete stores can migrate profiles without renderer state.

## Migration Plan

1. Add `video-enhancement-pipeline-contract` specs and deltas for existing affected specs.
2. Extend Dart contracts with profile storage records, deterministic pipeline evaluator, typed outcomes/failures, and invalidation events.
3. Update public exports, runtime checks, tests, and advanced playback checker rules.
4. Validate with OpenSpec, analyzer, tests, runtime checks, and Phase 5 checker scripts.

Rollback is straightforward because this change introduces contract/value/state scaffolding only; no concrete native renderer or external dependency is introduced.

## Open Questions

- None blocking for the contract slice. Concrete MPV shader mapping, Anime4K preset files, HDR tone-map algorithms, and AVSyncGuard degradation ordering are intentionally deferred.
