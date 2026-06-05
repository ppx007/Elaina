## Why

Step 18 needs the BT task core to move beyond bootstrap shape into durable, engine-neutral task orchestration. The just-archived `seasonal-indexer-contract` completed Step 17, leaving the next plan-aligned gap at magnet/torrent task persistence, lifecycle commands, file selection state, and capability-gated download behavior.

## What Changes

- Add Storage-backed BT task records for source, metadata, file selection, lifecycle state, transfer status, and latest task events.
- Add a Domain-facing BT task core contract that coordinates `DownloadEngineAdapter` task creation, metadata fetch, status replay, file selection, pause/resume/remove commands, and persisted task state.
- Add cache invalidation events for BT task creation, metadata readiness, lifecycle changes, file selection changes, and task removal.
- Refine BT capability handling so unsupported long-background download and unavailable engine capabilities are represented through contracts instead of hidden UI assumptions.
- Keep concrete libtorrent/FFI/socket implementations, VirtualMediaStream byte serving, piece-priority scheduling, timeline overlay UI, RSS auto-download, and BT enqueueing from automation rules out of scope.

## Capabilities

### New Capabilities

- `bt-task-core-contract`: Domain and Storage contracts for engine-neutral BT task creation, lifecycle persistence, metadata/file selection state, adapter command orchestration, and BT task invalidation events.

### Modified Capabilities

- `bt-task-core`: Refine bootstrap BT task requirements into durable task persistence, lifecycle command orchestration, and capability-gated behavior.
- `local-storage-foundation`: Add BT task, metadata, file selection, and event persistence responsibilities.
- `cache-invalidation-bus`: Add BT task lifecycle and metadata/file-selection invalidation events.

## Impact

Affected code includes Streaming BT task contracts, Storage foundation records/stores, cache invalidation events, runtime validation, boundary checker scripts, and deterministic contract tests. `DownloadEngineAdapter` remains an adapter boundary; this change does not introduce concrete torrent engine APIs, network sockets, FFI, UI download pages, VirtualMediaStream range serving, piece-priority scheduling, or RSS auto-download integration.
