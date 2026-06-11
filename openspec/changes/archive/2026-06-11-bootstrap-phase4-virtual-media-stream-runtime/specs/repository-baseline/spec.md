## ADDED Requirements

### Requirement: Repository baseline SHALL keep virtual media stream runtime optional and isolated
The repository baseline SHALL treat the Step 19 virtual media stream runtime as optional Streaming/Playback handoff orchestration that must not become a prerequisite for piece-priority scheduling, timeline overlay rendering, RSS auto-download, online-rule runtime, diagnostics center, concrete UI, concrete network implementation, storage migration, concrete torrent engines, or native-player implementation.

#### Scenario: Later BT playback slices are absent
- **WHEN** piece-priority scheduler runtime, timeline overlay runtime, concrete range servers, concrete torrent engines, concrete UI pages, diagnostics center, and native-player adapters are not implemented
- **THEN** the virtual media stream runtime can still create deterministic stream descriptors, persist lifecycle and buffered range state, publish invalidation payloads, and expose playback handoff projections

### Requirement: Repository baseline SHALL validate Step 19 boundary terms
The repository baseline SHALL include validation for virtual media stream runtime files that rejects later Phase 4 features and concrete implementation dependencies while allowing Streaming virtual stream contracts, BT task projections, storage contracts, cache invalidation contracts, and playback source handoff contracts.

#### Scenario: Boundary checker runs
- **WHEN** the Step 19 virtual media stream runtime checker scans project files
- **THEN** forbidden dependencies on concrete UI, concrete torrent engines, FFI, sockets, range servers, pipe servers, filesystem byte reads, piece-priority scheduler runtime, timeline overlay rendering, RSS auto-download execution, online-rule parsing, diagnostics, network implementation, storage migration, MPV/VLC, or native-player bindings fail validation
