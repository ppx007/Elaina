## 1. Streaming Runtime Contracts

- [x] 1.1 Add BT task core runtime result, failure, status, snapshot, task projection, metadata projection, file projection, observer, command, and lifecycle value objects under `lib/src/streaming/`.
- [x] 1.2 Implement disposed, unavailable, unsupported, failed, ignored, and success outcomes for task creation, metadata fetch, projection, file selection, lifecycle commands, status observation, and event observation.
- [x] 1.3 Reuse existing `BtTaskCoreContract`, `DeterministicBtTaskCore`, `DownloadEngineAdapter`, `BtCapabilityMatrix`, `BtTaskStore`, BT task storage records, and cache invalidation contracts instead of introducing parallel task, adapter, storage, or capability models.
- [x] 1.4 Confirm existing storage and cache invalidation contracts cover Step 18 red-state gaps for atomic task-state transitions, restart reconciliation, correlated invalidation, and post-mutation read ordering before adding runtime code.

## 2. BT Task Core Runtime

- [x] 2.1 Implement a `BtTaskCoreRuntime` or `BtTaskCoreBootstrap` composition entry point that wires `DownloadEngineAdapter`, `BtTaskStore`, optional `CacheInvalidationBus`, deterministic clock, and existing BT task core orchestration.
- [x] 2.2 Add deterministic task creation for magnet and torrent-data sources that routes through the adapter, persists task records, records creation events, publishes optional invalidation, and returns runtime-safe outcomes.
- [x] 2.3 Add deterministic metadata fetch and file projection actions that persist metadata records, file records, piece length, offsets, lifecycle state, metadata events, and optional invalidation without concrete engine handles.
- [x] 2.4 Add atomic storage transition handling so task creation, metadata fetch, file selection, lifecycle commands, status observation, and event observation update related task, metadata, file, transfer, event, and visibility state before returning replayable runtime outcomes.
- [x] 2.5 Add deterministic task listing, task lookup, latest transfer snapshot projection, latest event projection, restart reconciliation projection, and replayable runtime snapshot actions built from `BtTaskStore` state.
- [x] 2.6 Add deterministic pause, resume, remove, and file-selection actions that capability-check task management, route through `DownloadEngineAdapter`, persist lifecycle or selection changes, record events, and publish correlated invalidation.
- [x] 2.7 Add deterministic status and event observation wiring that stores adapter status snapshots, metadata updates, lifecycle updates, piece completion events, failures, and correlated invalidation while yielding engine-neutral events.
- [x] 2.8 Add post-mutation invalidation semantics for BT task list projections, task detail projections, runtime snapshots, capability/status views, and repository-derived selectors without direct UI refresh or cross-module cache mutation.

## 3. Source Neutrality, Exports, and Boundaries

- [x] 3.1 Export only safe Step 18 BT task core runtime and contract surfaces through `lib/celesteria.dart` without exporting concrete torrent engines, FFI, range servers, scheduler runtimes, timeline rendering, diagnostics, network implementations, storage migrations, UI pages, or native-player bindings.
- [x] 3.2 Keep virtual media stream, piece priority scheduler, and timeline overlay behavior limited to durable handoff state and explicit non-goals; do not implement range serving, piece prioritization, or timeline rendering in this change.
- [x] 3.3 Keep RSS auto-download, online-rule runtime, concrete ProviderGateway changes, diagnostics center, platform background services, and iOS long-background guarantees outside the Step 18 runtime.
- [x] 3.4 Preserve existing Phase 0-3 runtime checker behavior while adding Step 18 BT task core runtime validation.
- [x] 3.5 Preserve Storage-layer and CacheInvalidationBus ownership boundaries; do not add concrete database schemas, storage migrations, event transports, UI refreshes, polling loops, or direct cache mutation in this change.

## 4. Tests and Validation

- [x] 4.1 Add focused BT task core runtime tests for magnet task creation, torrent-data task creation, unsupported capability handling, disposed behavior, task projection, immutable snapshots, and task listing.
- [x] 4.2 Add metadata and file-state tests for metadata fetch, file record persistence, piece length and offset handoff state, selected/skipped/streaming-target file projection, missing task behavior, and adapter failure normalization.
- [x] 4.3 Add lifecycle command tests for pause, resume, remove, file selection, event recording, optional cache invalidation, task-not-found handling, and unsupported task-management capability.
- [x] 4.4 Add status/event observation tests for transfer snapshot persistence, metadata event replay, piece completion event recording, failed task event handling, and replayable Domain state after adapter streams complete.
- [x] 4.5 Add storage restart reconciliation tests for resumable, paused, terminal, failed, removed, and incomplete task records without querying concrete torrent-engine persistence.
- [x] 4.6 Add cache invalidation tests for task list, task detail, runtime snapshot, capability/status, and repository-derived selector invalidation after persisted mutations, including post-mutation read ordering.
- [x] 4.7 Add boundary tests or script checks proving Step 18 runtime does not own concrete torrent engines, FFI, socket/range servers, virtual byte serving, piece-priority scheduling, timeline overlay rendering, RSS auto-download execution, online-rule parsing, diagnostics, concrete UI, network implementation, storage migration, MPV/VLC, or native-player behavior.
- [x] 4.8 Add `tools/bt_task_core_runtime_check.dart` smoke validation covering deterministic task creation, metadata fetch, file selection, lifecycle commands, status/event observation, storage projection, restart reconciliation, correlated invalidation, unsupported capability outcomes, disposed behavior, and existing BT streaming core smoke behavior.
- [x] 4.9 Add `tools/check_bt_task_core_runtime.ps1` boundary validation that chains `check_bt_streaming_core.ps1` and rejects forbidden Step 19+ / Phase 6+ / concrete UI / native engine / FFI / socket server / range server / scheduler runtime / timeline rendering / RSS auto-download / online-rule / diagnostics / network / storage migration / native-player dependencies in Step 18 runtime files.
- [x] 4.10 Run `openspec validate "bootstrap-phase4-bt-task-core-runtime" --strict`, `openspec validate --all`, `dart analyze`, focused BT task core runtime tests, BT task core runtime checker scripts, and existing Phase 0-3 runtime smoke checks.
