## Context

Phase 4 now has contract scaffolding for BT task metadata, virtual media streams, and deterministic piece priority scheduling. The remaining Step 21 gap is a playback-facing timeline overlay contract that can combine playback position, buffered ranges, piece state, priority-plan state, and future marker/heat layers into immutable read models for UI consumption.

The current bootstrap `timeline-overlay` spec intentionally states the boundary at a high level. This change turns that boundary into durable Dart contracts while preserving the project rule that UI surfaces render framework-neutral descriptors and never import BT engine, scheduler, libtorrent, socket, file, or native playback implementation details.

## Goals / Non-Goals

**Goals:**
- Define immutable timeline overlay snapshot, range, piece, marker, heat, and layer descriptor contracts.
- Derive overlay snapshots from already-available playback state, virtual stream buffered ranges, and scheduler plan/application snapshots.
- Persist only overlay-safe state such as layer visibility/order and latest derived snapshot metadata when useful for restart-safe presentation.
- Publish invalidation events when overlay snapshots or layer configuration change so playback surfaces can refresh without direct cross-module mutation.
- Add focused tests and boundary checkers that prove the overlay remains presentation-facing and Step 21-scoped.

**Non-Goals:**
- No concrete Flutter widget, gesture recognizer, canvas painter, theme, animation, or layout implementation.
- No libtorrent, native download engine, socket, HTTP server, pipe server, file I/O, FFI, or platform networking integration.
- No timeline-owned mutation of BT task lifecycle, virtual stream byte serving, or scheduler planning/application.
- No diagnostics center, Anime4K, AVSyncGuard, VLC fallback, RSS automation, provider metadata, danmaku rendering, or advanced subtitle rendering implementation.

## Decisions

1. **Use immutable read models instead of service callbacks.**
   - Decision: `TimelineOverlaySnapshot` and related values should be plain Dart values that can be produced deterministically from input snapshots.
   - Rationale: UI needs stable data to render, not authority to drive streaming or scheduler state.
   - Alternative considered: expose live service handles for timeline rendering. Rejected because it would couple UI to streaming internals and make tests depend on runtime services.

2. **Represent every visual concern as a layer.**
   - Decision: progress, buffered ranges, piece states, priority windows, markers, and heat data should appear as separate ordered/visible layers.
   - Rationale: this matches the architecture plan's “timeline Layer 可增删” extension point and allows later danmaku, subtitle, or diagnostics hints without rewriting the overlay core.
   - Alternative considered: a single flattened timeline DTO. Rejected because it would make future layer additions breaking and obscure visibility policy.

3. **Consume existing contracts, never concrete producers.**
   - Decision: overlay composition accepts playback-state values, virtual stream descriptors/ranges, and scheduler plan/application summaries only through contract-safe inputs.
   - Rationale: Step 21 must complete the Phase 4 BT playback boundary without reaching into engines or file/network implementations.
   - Alternative considered: let overlay read BT task stores or scheduler stores directly. Rejected because it creates cross-layer data ownership and makes overlay responsible for lifecycle state.

4. **Publish refresh events through `CacheInvalidationBus`.**
   - Decision: define timeline overlay invalidation events for snapshot refresh and layer configuration changes.
   - Rationale: existing Phase 4 contracts already use invalidation events to refresh derived state; the overlay should follow the same pattern.
   - Alternative considered: direct callbacks from scheduler/streaming into UI. Rejected because it violates event-driven invalidation and creates point-to-point coupling.

## Risks / Trade-offs

- **Risk: Overlay contracts accidentally become UI implementation.** → Mitigation: ban Flutter widgets, `BuildContext`, painters, themes, and gesture concepts from the contract and checker scripts.
- **Risk: Overlay contracts start owning scheduler or streaming state.** → Mitigation: model composition as pure read-model derivation and publish refresh events only; no mutation APIs for BT tasks, virtual streams, or scheduler plans.
- **Risk: Layer model is too generic to test.** → Mitigation: define concrete required layer kinds and deterministic scenarios for progress, buffered ranges, pieces, priority windows, and markers.
- **Risk: Later diagnostics or heat layers need more metadata.** → Mitigation: include extensible layer ids/kinds and opaque, typed marker metadata without introducing diagnostics-center dependencies in Step 21.

## Migration Plan

1. Add the `timeline-overlay-contract` spec and deltas for affected existing specs.
2. Implement plain Dart timeline overlay contracts and deterministic composer utilities.
3. Add storage/invalidation exposure only for overlay-safe layer configuration and snapshot refresh state.
4. Add focused tests and update Phase 4 runtime/boundary checks.
5. Validate with OpenSpec, analyzer, tests, and Phase 4 checker scripts before archive.

Rollback is straightforward: remove the new Step 21 contracts/spec deltas before archive, because no concrete runtime migration or external dependency is introduced.

## Open Questions

- None blocking for the contract slice. Concrete timeline rendering, gesture semantics, visual density, and diagnostics heat-map styling are intentionally deferred to later UI and diagnostics work.
