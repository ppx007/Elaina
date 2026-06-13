# timeline-overlay-contract Specification

## Purpose
TBD - created by archiving change timeline-overlay-contract. Update Purpose after archive.
## Requirements
### Requirement: Timeline overlay contract SHALL expose immutable snapshots
The system SHALL define durable timeline overlay contracts for immutable playback progress, buffered ranges, BT piece states, priority windows, markers, heat layers, and layer descriptors without exposing concrete Flutter, download-engine, socket, file, FFI, HTTP server, pipe server, or libtorrent implementation details.

#### Scenario: Overlay snapshot is composed
- **WHEN** playback state, virtual stream buffered ranges, and scheduler plan summaries are available as contract-safe values
- **THEN** the timeline overlay contract can compose a snapshot from those values without importing concrete UI, native playback, streaming engine, storage implementation, file, socket, or network code

### Requirement: Timeline overlay contract SHALL model layers independently
The system SHALL represent playback progress, buffered ranges, piece states, scheduler priority windows, markers, and heat data as independently identifiable overlay layers with stable visibility and ordering metadata.

#### Scenario: User-visible layers are resolved
- **WHEN** a playback surface requests timeline overlay data
- **THEN** it receives ordered layer descriptors and layer payloads that can be shown, hidden, or reordered without mutating BT task, virtual stream, or scheduler state

### Requirement: Timeline overlay contract SHALL derive piece and buffer projections from existing contracts
The system SHALL derive timeline-safe piece and buffer projections only from virtual media stream descriptors, buffered range snapshots, and scheduler plan/application snapshots that are already exposed through Phase 4 contracts.

#### Scenario: Buffered and prioritized ranges overlap
- **WHEN** a virtual stream reports buffered ranges and the scheduler reports active priority windows for the same media file
- **THEN** the overlay snapshot exposes both projections as read-only layers without causing virtual stream byte serving or scheduler planning to depend on overlay behavior

### Requirement: Timeline overlay contract SHALL persist overlay-safe presentation state
The system SHALL allow storage of overlay-safe presentation state such as layer visibility, layer order, selected overlay profile, and latest derived snapshot metadata without persisting concrete UI widgets, native handles, engine objects, or byte-serving state.

#### Scenario: Layer preferences survive restart
- **WHEN** a user or default profile changes timeline layer visibility or order
- **THEN** the next playback session can restore those overlay preferences through Storage contracts without loading Flutter widgets, torrent engines, sockets, files, or network clients

### Requirement: Timeline overlay contract SHALL publish overlay invalidation events
The system SHALL publish cache invalidation events when timeline overlay snapshots are refreshed, layer configuration changes, or overlay composition is rejected because required read-model inputs are unavailable.

#### Scenario: Overlay snapshot refreshes
- **WHEN** new buffered range or piece-priority information changes the derived timeline overlay snapshot
- **THEN** a timeline overlay invalidation event is published so playback surfaces can refresh derived state without direct cross-module mutation

### Requirement: Timeline overlay contract MUST remain scoped to Step 21
The system MUST keep concrete rendering, gesture handling, playback engine control, BT task lifecycle mutation, scheduler mutation, RSS automation, diagnostics-center behavior, and Phase 5 advanced playback features outside the TimelineOverlay contract slice.

#### Scenario: Phase 4 checker runs
- **WHEN** boundary checks scan Step 21 contracts
- **THEN** no concrete Flutter rendering, concrete download engine, native playback binding, network implementation, diagnostics center, Anime4K, VLC fallback, RSS automation, provider metadata, or online rule runtime dependency is required by the timeline overlay contract

### Requirement: Immutable runtime snapshots
Timeline overlay contract SHALL expose immutable runtime snapshots derived from playback, virtual stream, BT piece, scheduler, marker, heat, and persisted profile inputs.

#### Scenario: Snapshot collections cannot be mutated by callers
- **WHEN** a caller receives a timeline overlay runtime snapshot
- **THEN** layer, marker, piece, heat, and priority collections SHALL be immutable to the caller.

### Requirement: Runtime composition failure normalization
Timeline overlay contract SHALL normalize missing duration, invalid stream length, duplicate layer identifiers, missing profile, dependency-unavailable, and disposed states into typed failures.

#### Scenario: Duplicate layer identifiers are rejected
- **WHEN** runtime composition receives duplicate layer identifiers
- **THEN** it SHALL return a typed invalid-layer failure and persist a composition rejection record where applicable.

### Requirement: Runtime profile and layer persistence
Timeline overlay contract SHALL persist overlay profiles, active profile per stream, ordered layer preferences, visibility, and latest snapshot metadata as overlay-safe presentation state.

#### Scenario: Active profile survives restart
- **WHEN** a stream has an active overlay profile persisted before restart
- **THEN** runtime bootstrap SHALL restore that active profile for subsequent snapshot composition.

### Requirement: Step 21 boundary protection
Timeline overlay contract SHALL keep rendering, gestures, playback control, BT task mutation, scheduler mutation, native player integration, diagnostics behavior, and Phase 5 features outside Step 21 runtime contracts.

#### Scenario: Runtime cannot execute seek
- **WHEN** a user-facing layer later requests a seek from a timeline position
- **THEN** Step 21 runtime SHALL expose only read-model data and SHALL NOT execute playback seek commands.
