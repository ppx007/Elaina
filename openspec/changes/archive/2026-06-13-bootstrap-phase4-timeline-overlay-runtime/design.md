## Context

Phase 4 Step 18 created a replayable BT task core runtime, Step 19 created virtual media stream runtime projections, and Step 20 created piece priority scheduler runtime projections. The architecture plan lists Step 21 as `TimelineOverlay`, where playback progress, buffered ranges, BT blocks, high-energy heat, and scheduler priority windows become timeline layers.

The current codebase already has `DeterministicTimelineOverlayComposer`, `TimelineOverlayStore`, cache invalidation events, and contract tests. What is missing is the runtime/bootstrap acceptance layer that ties those contracts together with lifecycle-safe outcomes, persisted presentation state, restart-safe snapshots, public export, smoke validation, and strict boundary checks.

## Goals / Non-Goals

**Goals:**
- Add `TimelineOverlayRuntime` and `TimelineOverlayBootstrap` as a Step 21 runtime boundary around the existing composer and store contracts.
- Compose immutable overlay snapshots from playback state, virtual stream descriptors, buffered ranges, BT piece segments, scheduler priority windows, markers, heat values, and persisted layer configuration.
- Persist overlay-safe state: profiles, active profile per stream, ordered layer preferences, visibility, and latest snapshot metadata.
- Publish cache invalidation after storage-visible profile selection, layer configuration, successful snapshot refresh, and rejected composition.
- Return typed action outcomes for composition, profile selection, layer configuration, missing profile, invalid layer state, dependency-unavailable inputs, rejected composition, and disposed runtime state.
- Provide read-only timeline-safe projections for future UI layers.

**Non-Goals:**
- No Flutter widgets, timeline drawing, gestures, hover states, tooltips, visual design, or UI layout.
- No playback engine control, seek execution, pause/resume commands, MPV/VLC/media-kit integration, or platform channels.
- No BT task lifecycle mutation, torrent polling, libtorrent, FFI, sockets, file IO, pipe servers, HTTP/range servers, or concrete byte serving.
- No scheduler plan generation/application. Timeline overlay consumes scheduler projections only.
- No RSS automation, online-rule runtime, diagnostics-center behavior, Anime4K, AV sync, captions, storage migrations, or Phase 5 features.

## Decisions

1. **Runtime wraps existing composer instead of replacing it.**
   - Decision: `TimelineOverlayRuntime` SHALL call the existing `TimelineOverlayComposer` contract and project its output into runtime snapshots.
   - Alternative: Reimplement composition logic inside the runtime.
   - Rationale: Existing composer contracts already encode layer ordering, buffer projection, and failure semantics; duplicating them risks divergence.

2. **Persist presentation state, not rendered UI state.**
   - Decision: Storage SHALL persist profiles, active profile, layer order/visibility/configuration, and latest snapshot metadata only.
   - Alternative: Persist rendered pixels, widget state, or interaction state.
   - Rationale: Step 21 is a runtime/read-model slice; rendering and gestures belong to later UI work.

3. **Overlay consumes scheduler and stream projections as read-only inputs.**
   - Decision: Runtime SHALL accept virtual stream descriptors, buffered range snapshots, BT piece segments, scheduler priority windows, markers, and heat values as data inputs.
   - Alternative: Let overlay regenerate scheduler plans or mutate stream lifecycle.
   - Rationale: Step 20 owns priority planning/application and Step 19 owns stream lifecycle/range state.

4. **Cache invalidation follows storage visibility.**
   - Decision: Runtime SHALL persist profile/layer/snapshot metadata before publishing invalidation events.
   - Alternative: Publish invalidations optimistically before storage writes.
   - Rationale: Consumers must avoid stale post-mutation reads after layer/profile/snapshot changes.

5. **Boundary checks are part of the acceptance contract.**
   - Decision: A PowerShell checker SHALL reject UI, concrete IO, native player, scheduler mutation, diagnostics, and later-phase leakage in the Step 21 runtime surfaces.
   - Alternative: Rely on code review only.
   - Rationale: Step 21 is close to UI and playback domains, so regression checks are needed to preserve layer isolation.

## Risks / Trade-offs

- Scope creep into UI rendering -> Mitigation: runtime outputs only immutable snapshots and layer descriptors; checker rejects Flutter widget/rendering terms.
- Scheduler coupling -> Mitigation: runtime consumes priority windows/rules as projections and never imports or calls scheduler plan generation/application paths.
- Invalidation races -> Mitigation: storage-before-invalidation ordering is required for profile, layer, snapshot, and rejection paths.
- Over-broad BT dependency -> Mitigation: overlay accepts engine-neutral piece/block projections only; it does not read torrent engine handles or mutate BT task state.
- Snapshot shape churn -> Mitigation: expose stable, immutable projections and keep raw composer details behind runtime mapping.

## Migration Plan

1. Add focused red tests for Step 21 runtime composition, profiles, layer ordering, typed failures, restart projections, and invalidation ordering.
2. Implement minimal runtime/bootstrap wrapper around existing timeline composer and store contracts.
3. Add public export only after focused tests pass.
4. Add Dart smoke checker and PowerShell boundary checker.
5. Run focused timeline tests, smoke checker, boundary checker, `dart analyze`, strict OpenSpec validation, and global OpenSpec validation.
6. Mark OpenSpec tasks complete only after validation passes.

No persisted production migration is required in this planning/runtime slice.

## Open Questions

- None blocking. If implementation reveals that existing `TimelineOverlayStore` lacks a small replay field, extend only deterministic contract scaffolding and keep concrete storage migrations out of scope.
