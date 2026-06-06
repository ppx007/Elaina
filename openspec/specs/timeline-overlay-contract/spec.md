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

