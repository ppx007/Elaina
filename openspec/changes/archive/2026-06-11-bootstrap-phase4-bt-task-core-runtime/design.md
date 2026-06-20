## Context

The architecture plan places Phase 4 / Step 18 immediately after the archived Phase 3 / Step 17 seasonal indexer runtime. Step 18 is BT task core: magnet/torrent input, metadata, file list, and task management behind a replaceable `DownloadEngine` boundary.

Current code already has the important contracts in `lib/src/streaming/bt_task_core.dart` and storage primitives in `lib/src/foundation/storage/bt_task_storage_contracts.dart`: task identifiers, magnet/torrent sources, metadata, file descriptors, lifecycle states, capability declarations, `DownloadEngineAdapter`, `BtTaskCoreContract`, `DeterministicBtTaskCore`, `BtTaskStore`, and cache invalidation events. The missing slice is the runtime/bootstrap layer that makes those contracts operational in the same style as recent Phase 2/3 runtime slices: lifecycle-safe results, snapshots, observer wiring, deterministic smoke checks, boundary validation, and exports that prove Step 18 can run without concrete libtorrent, UI, virtual stream serving, or later Phase 4 features.

## Goals / Non-Goals

**Goals:**

- Provide a deterministic `BtTaskCoreRuntime` or bootstrap entry point that composes `DownloadEngineAdapter`, `BtTaskStore`, optional `CacheInvalidationBus`, and task-core lifecycle state behind safe runtime actions.
- Expose runtime result, failure, status, snapshot, task projection, metadata projection, file selection, observer, and disposed/unavailable behavior for task creation, metadata fetch, status/event observation, pause, resume, remove, and file selection.
- Persist normalized task, metadata, file, transfer snapshot, and latest event state through `BtTaskStore` while keeping Domain-facing reads replayable without concrete download-engine objects.
- Define the Step 18 storage and invalidation boundaries needed for atomic task-state transitions, restart reconciliation, runtime snapshot reads, and post-mutation cache invalidation.
- Keep capability-gated behavior explicit so unsupported task management, metadata fetching, virtual streaming, piece scheduling, timeline overlay, or long-background download capabilities do not leak adapter details or promise platform behavior.
- Add focused tests, smoke checks, and boundary validation proving the runtime remains Step 18 BT task core orchestration.

**Non-Goals:**

- No concrete libtorrent binding, FFI, socket server, torrent session, native engine implementation, platform download service, storage migration, or real torrent network I/O.
- No `VirtualMediaStream` range serving, pipe/range server, byte buffering, piece map implementation, or player source serving beyond durable handoff state.
- No `PiecePriorityScheduler` runtime behavior beyond preserving metadata/file state needed by later scheduler work.
- No `TimelineOverlay` rendering, Flutter download page, playback page UI, diagnostics center, MPV/VLC/native-player integration, or UI task management screen.
- No RSS auto-download worker, online-rule runtime, concrete network policy, provider gateway changes, or iOS long-background download guarantee.

## Decisions

1. **Build Step 18 as a runtime wrapper over existing BT task contracts.**
   - Rationale: `DeterministicBtTaskCore`, `DownloadEngineAdapter`, and `BtTaskStore` already express the task orchestration contract. The missing part is runtime lifecycle, snapshot projection, validation, and public bootstrap composition matching the previous runtime slices.
   - Alternative considered: replace the existing contracts with a new download service model. Rejected because it would duplicate established Streaming/storage contracts and risk coupling Domain or UI to engine details.

2. **Keep the download engine as an adapter, not an implementation.**
   - Rationale: Step 18 must prove replaceable engine-neutral orchestration. A deterministic adapter fixture is enough for tests and smoke checks; concrete libtorrent/native work can arrive behind the adapter later.
   - Alternative considered: introduce a mock libtorrent-like session. Rejected because even a mock session would normalize concrete engine concepts into the core contract too early.

3. **Persist replayable task state before exposing projections.**
   - Rationale: later virtual stream and scheduler slices need metadata, file offsets, piece length, selected files, lifecycle state, and latest transfer/event state without querying a concrete engine. Step 18 should make that durable handoff state reliable now.
   - Alternative considered: rely on adapter streams as the source of truth. Rejected because it would make restart, Domain reads, virtual stream handoff, and scheduler planning engine-dependent.

4. **Use capability-gated failures for unavailable behavior.**
   - Rationale: platforms may lack BT task management, metadata fetching, virtual streaming, piece scheduling, timeline overlay, or long-background execution. The runtime should return typed unavailable/unsupported outcomes rather than hidden fallbacks or platform promises.
   - Alternative considered: silently degrade commands to no-ops. Rejected because task management must be observable and testable.

5. **Validate boundaries with forbidden later-slice terms and dependency checks.**
   - Rationale: Phase 4 has adjacent steps that are tempting to implement together. Step 18 must not absorb virtual byte serving, scheduler planning, timeline rendering, RSS auto-download, concrete UI, or native engine work.
   - Alternative considered: implement all Phase 4 features as one large BT streaming runtime. Rejected because the architecture deliberately freezes BT playback across Steps 18-21.

6. **Treat Storage as the owner of runtime bootstrap state, not as an implementation detail of the BT runtime.**
   - Rationale: Step 18 task creation, metadata fetch, file selection, lifecycle commands, status observation, and event observation all change durable task read models. Storage contracts need to define atomic state-transition, restart reconciliation, runtime snapshot metadata, and schema-version boundaries so the runtime can resume without engine-owned persistence.
   - Alternative considered: keep restart semantics only inside `BtTaskCoreRuntime`. Rejected because that would let Streaming own persistence policy and bypass the Storage-layer boundary.

7. **Treat CacheInvalidationBus as the owner of invalidation semantics, not UI refresh.**
   - Rationale: task mutations affect task lists, task details, runtime snapshots, capability/status views, and repository-derived selectors. The bus should carry correlated invalidation events after durable mutations so consumers avoid stale reads without direct service-to-service cache mutation.
   - Alternative considered: refresh derived views directly from the runtime after every command. Rejected because it would introduce point-to-point coupling and UI/cache behavior into Step 18 orchestration.

## Risks / Trade-offs

- **[Risk] Runtime grows into a concrete torrent engine.** -> Mitigation: tests and boundary scripts reject libtorrent, FFI, socket/session, native engine, and platform service dependencies in Step 18 runtime files.
- **[Risk] Step 18 absorbs Step 19-21 behavior.** -> Mitigation: proposal/spec/tasks name virtual stream, scheduler, and timeline work only as handoff boundaries or non-goals.
- **[Risk] Persisted task state diverges from adapter updates.** -> Mitigation: runtime tests cover metadata fetch, status replay, event replay, lifecycle commands, and latest snapshot projection through `BtTaskStore`.
- **[Risk] Task mutations become visible before durable state is committed.** -> Mitigation: storage deltas require atomic transition semantics before projections or invalidation events are reported as successful.
- **[Risk] Derived task views stay stale after runtime commands.** -> Mitigation: cache invalidation deltas require correlated invalidation for task list/detail/runtime snapshot/capability views after persisted mutations.
- **[Risk] Unsupported platform behavior looks successful.** -> Mitigation: capability-gated tests cover task management and metadata fetching failures, including disposed runtime behavior.
- **[Risk] Runtime exports leak implementation details.** -> Mitigation: exports expose safe runtime/contracts only and validation rejects concrete UI, storage implementation, network, native-player, and engine bindings.

## Migration Plan

1. Add BT task core runtime result, failure, status, snapshot, task projection, metadata/file projection, observer, command, and lifecycle values under `lib/src/streaming/`.
2. Extend storage-facing runtime composition so task creation, metadata fetch, file selection, lifecycle commands, status observation, and event observation persist atomic task-state transitions before replayable projections or invalidation are exposed.
3. Implement `BtTaskCoreRuntime` or `BtTaskCoreBootstrap` that composes existing `BtTaskCoreContract` or `DeterministicBtTaskCore`, `DownloadEngineAdapter`, `BtTaskStore`, optional `CacheInvalidationBus`, and update streams.
4. Add deterministic runtime actions for task creation, metadata fetch, task listing/projection, file projection, file selection, pause, resume, remove, status watch, event watch, latest transfer snapshot, and disposal.
5. Publish correlated cache invalidation events for persisted task list, task detail, runtime snapshot, capability/status, and repository-derived selector changes without direct UI refresh or cross-module cache mutation.
6. Export safe Step 18 runtime surfaces through `lib/elaina.dart` without exporting concrete torrent engines, UI pages, range servers, scheduler runtimes, timeline rendering, diagnostics, network implementations, storage migrations, or native-player bindings.
7. Add focused tests, a Dart smoke checker, and a PowerShell boundary checker that chains existing BT streaming core validation.
8. Run `openspec validate "bootstrap-phase4-bt-task-core-runtime" --strict`, `openspec validate --all`, `dart analyze`, focused BT task runtime tests, and BT runtime checker scripts.

Rollback before archive is deleting the new runtime/test/tool files and removing this change directory. No persisted schema migration, concrete engine state, native resource, network I/O, UI state, virtual stream server, scheduler state, timeline rendering, or platform background work is introduced.

## Open Questions

- Whether concrete libtorrent, aria2, or platform-specific engines become the first real adapter should be deferred until after Step 18 runtime contracts are validated.
- Whether download task UI consumes runtime snapshots directly or through a separate Domain service should be deferred to the download page/UI slice.
- Whether persisted transfer history needs more than the latest snapshot should be deferred until diagnostics and long-running download UX requirements are concrete.
