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

### Requirement: Phase 4 BT task core runtime SHALL remain Step 18 scoped
The system MUST keep Flutter UI, playback source handoff, concrete range
servers, virtual byte serving, piece-priority application, timeline overlay
rendering, RSS auto-download execution, diagnostics center, WebView, network
policy implementation, storage migration, MPV/VLC/media-kit, and native player
bindings outside the neutral BT task runtime. Step 52 MAY add a neutral runtime
composition contract and a concrete libtorrent composition factory through the
approved adapter surface, but native/libtorrent package imports MUST remain
limited to the approved concrete adapter file and tests.

#### Scenario: Boundary validation runs
- **WHEN** Step 52 runtime validation scans project files
- **THEN** native/libtorrent package imports are allowed only in the approved
  concrete BT adapter file and tests, while neutral streaming contracts remain
  free of concrete engine dependencies
