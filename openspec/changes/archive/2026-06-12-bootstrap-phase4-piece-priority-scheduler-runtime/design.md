## Context

Phase 4 Step 18 archived a deterministic BT task runtime that persists task metadata, selected file state, lifecycle, transfer snapshots, and replayable projections. Phase 4 Step 19 archived a virtual media stream runtime that creates stream descriptors from selected BT files, persists buffered ranges, records range failures, and exposes playback-safe handoff projections.

Step 20 is the next Phase 4 slice: `PiecePriorityScheduler`. Existing code already contains scheduler contracts, deterministic planning, plan application recording, storage contracts, and baseline tests. This change should therefore formalize the runtime/bootstrap acceptance boundary around that existing scheduler surface rather than introduce a new torrent engine, timeline renderer, UI, or byte-serving implementation.

## Goals / Non-Goals

**Goals:**

- Define a Step 20 runtime/bootstrap surface for piece priority planning over persisted BT task state and virtual stream state.
- Preserve deterministic plan generation from strategy profiles, playback windows, seek targets, file-piece maps, and buffered range snapshots.
- Persist active profile selection, generated plans, plan rules, and latest application outcomes so scheduler state is restart-safe.
- Treat plan application as an adapter-neutral boundary that records accepted, rejected, or unavailable outcomes without direct concrete engine mutation.
- Publish scheduler invalidations only after storage-visible profile, plan, rule, or application state changes.
- Expose timeline-safe priority projections as read-only data for later Step 21 timeline overlays.
- Add focused tests and validation checkers that prove scheduler runtime behavior and Step 20 isolation.

**Non-Goals:**

- No Step 21 `TimelineOverlay` runtime, overlay composition, heat maps, marker rendering, or timeline UI.
- No concrete torrent engine, libtorrent, FFI, socket, HTTP/range server, pipe server, filesystem byte serving, or platform download priority implementation.
- No MPV, VLC, media-kit, platform channel, native player, playback UI, download page, or Flutter widget dependency.
- No RSS auto-download, online-rule runtime, diagnostics center, network policy, storage migration, or Phase 5 advanced playback implementation.
- No scheduler ownership of virtual stream lifecycle, byte delivery, or task lifecycle commands.

## Decisions

### Decision: Runtime wraps existing scheduler contracts

Use the existing `DeterministicPiecePriorityScheduler`, `PiecePriorityPlanApplier`, `DeterministicPiecePriorityPlanApplicationRecorder`, and `PiecePrioritySchedulerStore` as the implementation anchor. Add or harden a runtime/bootstrap layer only where callers need lifecycle-safe actions, replayable projections, restart reconciliation, or validation-friendly composition.

Alternative considered: replace the existing scheduler with a new runtime implementation. Rejected because the existing code already models the Step 20 core and replacement would add churn without clarifying architecture.

### Decision: Plan application remains adapter-neutral

Step 20 may accept a `PiecePriorityPlanApplier` boundary and record accepted, rejected, or unavailable outcomes, but it must not mutate concrete engine priority APIs directly. Concrete libtorrent/native engine application belongs behind future adapter implementations.

Alternative considered: call concrete engine priority APIs from the scheduler. Rejected because Phase 4 contracts require engine-neutral planning and replaceable download engines.

### Decision: Scheduler projections are persisted read models

Runtime snapshots should be reconstructed from storage records: active profile, latest plan, rules, and latest application event. Later Step 21 timeline overlays can consume those projections as read-only data without regenerating plans or applying priorities.

Alternative considered: keep scheduler state only in memory. Rejected because restart-safe Phase 4 behavior and timeline consumers need replayable storage-backed state.

### Decision: Buffered-piece avoidance uses virtual stream snapshots

The scheduler should treat virtual stream buffered range records as input data and avoid fully buffered pieces when generating new rules. It should not own byte serving or stream lifecycle mutation.

Alternative considered: let virtual stream runtime push priority changes directly. Rejected because virtual streams are range/lifecycle contracts and scheduler planning is a separate Step 20 concern.

## Risks / Trade-offs

- [Risk] Existing deterministic scheduler may already satisfy much of Step 20, leading to over-implementation. -> Mitigation: proposal tasks should focus on acceptance tests, runtime projections, checkers, and minimal hardening.
- [Risk] Plan application could be mistaken for concrete engine control. -> Mitigation: specs and checkers must require adapter-neutral outcomes and forbid libtorrent/FFI/native/player terms in new runtime files.
- [Risk] Timeline-safe projection requirements could drift into Step 21 overlay composition. -> Mitigation: Step 20 may expose generated plan summaries and priority windows only; overlay composition/rendering remains an explicit non-goal.
- [Risk] Scheduler invalidation could race storage persistence. -> Mitigation: require storage writes before publishing plan/profile/application invalidations.

## Migration Plan

1. Add failing/coverage tests around existing scheduler behavior and new runtime/bootstrap projections.
2. Add minimal runtime/bootstrap hardening around existing scheduler contracts if needed.
3. Add smoke and boundary checkers for Step 20 runtime files.
4. Export public runtime surfaces only after tests pass.
5. Run focused tests, Dart analyzer, OpenSpec strict validation, and global OpenSpec validation.

No persisted production migration is required in this planning/runtime-contract slice.
