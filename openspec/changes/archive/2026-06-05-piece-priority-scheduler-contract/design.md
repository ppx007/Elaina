## Context

Phase 4 Step 18 completed durable BT task orchestration and Step 19 completed durable virtual stream range state. Step 20 now needs to turn the existing `PiecePriorityScheduler` bootstrap into a durable, deterministic contract that can plan current-window, seek-target, first-piece, and tail-piece priorities without exposing concrete torrent engine objects to Playback or UI.

The current `piece_priority_scheduler.dart` defines piece maps, playback windows, seek targets, priority rules, plans, profiles, a scheduler interface, and a plan applier interface. It does not yet define durable profile/plan records, deterministic planning behavior, persisted plan application state, or scheduler invalidation events.

## Goals / Non-Goals

**Goals:**

- Persist priority strategy profiles, generated piece priority plans, and latest plan application events through Storage contracts.
- Add deterministic scheduler behavior that derives piece priorities from persisted BT task metadata, file-piece maps, playback windows, seek targets, and virtual stream buffered range state.
- Preserve Playback/UI isolation by keeping scheduler inputs and outputs in Streaming/Foundation contracts, not UI widgets or player adapter internals.
- Add typed plan outcomes and application outcomes for missing metadata, missing file maps, stale stream state, unsupported profile, and adapter rejection.
- Publish scheduler invalidation events when plans are generated, applied, rejected, or when the active profile changes.
- Extend runtime validation, deterministic tests, and Phase 4 boundary checkers for Step 20.

**Non-Goals:**

- No concrete libtorrent, FFI, socket, HTTP server, file I/O, platform networking, or native engine implementation.
- No TimelineOverlay refinement or visual progress-layer rendering; that remains Step 21.
- No RSS auto-download, online rule runtime, diagnostics center expansion, UI task screen, or advanced playback feature work.
- No concrete piece priority engine command beyond an engine-neutral `PiecePriorityPlanApplier` contract.
- No guarantee of iOS long-background BT download behavior.

## Decisions

1. **Use dedicated scheduler storage records.**
   Add Storage-layer records for priority profiles, generated plans, plan rules, and latest plan application events instead of overloading `BtTaskStore` or `VirtualMediaStreamStore`. This keeps task state, stream state, and scheduler state independently queryable.

2. **Make deterministic planning depend on persisted metadata and explicit maps.**
   `DeterministicPiecePriorityScheduler` should reject planning when BT metadata or file-piece maps are unavailable. This avoids raw engine probing and makes replay across restart deterministic.

3. **Treat virtual stream buffered ranges as scheduler input, not ownership.**
   The scheduler may read buffered ranges to avoid reprioritizing already available ranges, but virtual streams do not depend on scheduler behavior to serve ranges.

4. **Keep plan application abstract.**
   The change defines plan application outcomes and persistence, but does not call libtorrent or platform APIs. Concrete priority application remains adapter work behind `PiecePriorityPlanApplier`.

5. **Publish coarse scheduler invalidation events.**
   Events should identify task id, stream id, profile id, plan id, and failure kind as needed, but must not carry raw engine objects, piece buffers, or UI state.

## Risks / Trade-offs

- **Risk: Scheduler contract accidentally becomes a concrete engine strategy.** → Mitigation: checker forbids `libtorrent`, FFI, sockets, HTTP servers, files, and platform dependencies in streaming contracts.
- **Risk: Step 20 bleeds into TimelineOverlay.** → Mitigation: explicitly exclude timeline rendering and progress-layer requirements from this change.
- **Risk: Priority plans duplicate BT metadata.** → Mitigation: plan records reference task id, stream id, file index, and piece ranges while metadata remains owned by BT task storage.
- **Risk: Playback starts manipulating piece priorities directly.** → Mitigation: handoff and checker rules keep playback/UI dependent on virtual stream sources, not scheduler contracts.

## Migration Plan

- Add scheduler storage records and deterministic in-memory store contracts.
- Extend `piece_priority_scheduler.dart` with plan outcomes, application outcomes, deterministic scheduler behavior, and persisted plan application hooks.
- Add scheduler invalidation events and runtime/checker coverage.
- Add deterministic tests for profile persistence, plan generation, seek reprioritization, buffered-range avoidance, plan rejection, and application events.
- Validate with analyzer, focused tests, full tests, runtime checks, Phase 4 checker, automation checker, and OpenSpec validation.

## Open Questions

- Whether the default strategy profile should be stored as an explicit record or exposed as a pure constant until user profiles exist.
- Whether Step 20 should persist all generated plans or only the latest plan per task/stream/profile tuple.
