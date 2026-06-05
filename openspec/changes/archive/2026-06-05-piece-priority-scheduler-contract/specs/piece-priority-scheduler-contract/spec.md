## ADDED Requirements

### Requirement: Piece priority scheduler contract SHALL persist plan state
The system SHALL define durable piece priority scheduler contracts for strategy profiles, generated plans, plan rules, and latest plan application events without exposing concrete download-engine, socket, file, FFI, or libtorrent implementation details.

#### Scenario: Priority plan state survives restart
- **WHEN** a priority strategy profile is selected and a plan is generated for a task-backed virtual stream
- **THEN** later Streaming flows can reconstruct the active profile, generated rules, and latest application state through Storage contracts

### Requirement: Piece priority scheduler contract SHALL plan from persisted task and stream state
The system SHALL generate priority plans only from engine-neutral BT task metadata, explicit file-piece maps, virtual stream descriptors, playback windows, seek targets, and buffered range snapshots already available through contracts.

#### Scenario: Scheduler input is unavailable
- **WHEN** metadata, file-piece maps, or stream state required for planning is unavailable
- **THEN** plan generation returns a typed failure without probing a concrete download engine or exposing torrent internals

### Requirement: Piece priority scheduler contract SHALL prioritize playback and seek windows
The system SHALL expose planning contracts that can prioritize current playback windows, pending seek targets, first pieces, tail pieces, and configurable lookahead windows through strategy profiles.

#### Scenario: Seek target is requested
- **WHEN** playback reports a pending seek target for a virtual stream
- **THEN** the scheduler emits a plan that raises target-window priority and can lower stale playback-window priorities using engine-neutral priority rules

### Requirement: Piece priority scheduler contract SHALL publish scheduler invalidation events
The system SHALL publish cache invalidation events when priority plans are generated, applied, rejected, or when the active scheduler profile changes.

#### Scenario: Priority plan is applied
- **WHEN** a priority plan applier accepts or rejects a generated plan
- **THEN** a scheduler invalidation event is published so diagnostics and later timeline consumers can refresh derived state without direct cross-module mutation

### Requirement: Piece priority scheduler contract MUST remain scoped to Step 20
The system MUST keep timeline overlay rendering, RSS automation, UI task screens, concrete engine/network implementations, and advanced playback features outside the PiecePriorityScheduler contract slice.

#### Scenario: Phase 4 checker runs
- **WHEN** boundary checks scan Step 20 contracts
- **THEN** no concrete engine implementation, timeline overlay rendering, RSS automation, UI dependency, or advanced playback dependency is required by the scheduler contract
