## Why

Phase 3 / Step 17 is archived, so the next architecture-plan slice is Phase 4 / Step 18: BT task core. The project already has engine-neutral BT task contracts and storage primitives, but it needs a deterministic runtime slice that proves magnet/torrent task creation, metadata persistence, file selection, lifecycle commands, adapter event replay, and cache invalidation can work without binding UI, playback, or Domain code to libtorrent or any concrete download engine.

## What Changes

- Add a deterministic Phase 4 BT task core runtime/bootstrap that composes `DownloadEngineAdapter`, `BtTaskStore`, optional `CacheInvalidationBus`, and runtime-safe lifecycle/snapshot surfaces around the existing BT task contracts.
- Add runtime actions for creating magnet/torrent tasks, ensuring metadata, selecting files, pausing/resuming/removing tasks, projecting persisted task state, observing adapter status/events, and handling unsupported capabilities or disposed runtime state.
- Add explicit storage-foundation and cache-invalidation deltas so Step 18 task mutations have durable restart/reconciliation semantics and correlated invalidation events for task read models.
- Add focused tests and smoke/boundary checks proving Step 18 remains BT task management and metadata/file-state orchestration only.
- Keep virtual byte serving, range servers, piece-priority scheduling, timeline overlays, RSS auto-download, concrete torrent engines, native bindings, and UI download screens out of this slice.
- No breaking changes.

## Capabilities

### New Capabilities
- `phase4-bt-task-core-runtime`: Deterministic runtime/bootstrap for engine-neutral BT task creation, metadata persistence, file selection, lifecycle commands, status/event replay, snapshots, tests, smoke checks, and validation.

### Modified Capabilities
- `bt-task-core`: Existing BT task core foundation gains deterministic runtime/bootstrap requirements for task orchestration, persisted state projection, adapter update handling, lifecycle-safe outcomes, and validation.
- `bt-task-core-contract`: Existing BT task core contracts gain runtime behavior requirements for capability-gated adapter command routing, durable metadata/file/transfer/event persistence, replayable Domain snapshots, and virtual-stream/scheduler handoff state.
- `local-storage-foundation`: Existing storage foundation gains Step 18 runtime requirements for atomic BT task state transitions, restart reconciliation, runtime snapshot metadata, and storage-boundary enforcement without concrete database implementation.
- `cache-invalidation-bus`: Existing cache invalidation bus gains Step 18 runtime requirements for correlated BT task list/detail/snapshot/capability invalidation after task mutations without direct UI refresh or point-to-point cache mutation.
- `repository-baseline`: Repository baseline gains a requirement that Step 18 BT task core runtime remains Streaming/Domain task orchestration and must not expand into virtual media stream serving, piece scheduling, timeline overlays, RSS auto-download, concrete UI, native torrent engines, or platform background guarantees.

## Impact

- Affected code: `lib/src/streaming/`, BT task storage contract consumers, public Dart barrel exports, focused streaming runtime tests, runtime smoke checks, and validation scripts.
- Affected specs: new `phase4-bt-task-core-runtime` plus deltas for `bt-task-core`, `bt-task-core-contract`, `local-storage-foundation`, `cache-invalidation-bus`, and `repository-baseline`.
- Dependencies: no concrete libtorrent binding, FFI, socket server, range server, virtual media stream implementation, piece-priority scheduler implementation, timeline overlay rendering, RSS auto-download worker, Flutter download page, storage migration, network implementation, diagnostics center, MPV/VLC/native player binding, or long-background iOS behavior is introduced in this slice.
