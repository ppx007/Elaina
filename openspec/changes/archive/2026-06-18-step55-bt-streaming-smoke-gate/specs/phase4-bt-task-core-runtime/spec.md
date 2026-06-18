## MODIFIED Requirements

### Requirement: Phase 4 BT task core runtime SHALL compose engine-neutral task orchestration
The system SHALL provide a BT task core runtime or bootstrap surface that
composes `DownloadEngineAdapter`, `BtTaskStore`, optional cache invalidation,
and existing BT task core contracts without exposing concrete torrent engine
APIs to UI, playback, provider, storage, network, or Domain callers. The runtime
MAY receive concrete adapters through a neutral BT task runtime composition
contract, including the Step 51 libtorrent adapter, while preserving
engine-neutral projections and outcomes.

#### Scenario: Runtime creates a magnet task
- **WHEN** the runtime receives a magnet task creation request and task-management capability is supported
- **THEN** it routes creation through the adapter boundary, persists an engine-neutral task record, records a creation event, publishes optional invalidation, and returns a runtime-safe success result

#### Scenario: Runtime uses concrete BT adapter
- **WHEN** app composition injects the concrete libtorrent adapter through the
  BT task runtime composition contract
- **THEN** runtime projections, storage records, invalidation events, and action
  results remain engine-neutral and do not expose libtorrent plugin values

#### Scenario: Runtime composition observes task state
- **WHEN** a composed runtime observes adapter status or task events
- **THEN** it persists normalized transfer snapshots and events that can be
  replayed after restart without a concrete engine handle

#### Scenario: Runtime participates in BT streaming smoke gate
- **WHEN** Step 55 creates a task through the concrete libtorrent composition
  boundary and ensures metadata for a streamable file
- **THEN** the runtime stores engine-neutral task, metadata, file-selection,
  lifecycle, and event projections that virtual streams and schedulers can
  consume without concrete libtorrent objects
