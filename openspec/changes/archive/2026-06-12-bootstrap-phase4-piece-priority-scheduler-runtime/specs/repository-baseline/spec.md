## ADDED Requirements

### Requirement: Repository baseline SHALL keep piece priority scheduler runtime optional and isolated
The repository baseline SHALL treat the Step 20 piece priority scheduler runtime as optional Streaming orchestration that must not become a prerequisite for timeline overlay rendering, RSS auto-download, online-rule runtime, diagnostics center, concrete UI, concrete network implementation, storage migration, concrete torrent engines, concrete byte-serving implementations, or native-player implementation.

#### Scenario: Later BT playback slices are absent
- **WHEN** timeline overlay runtime, concrete range servers, concrete torrent engines, concrete UI pages, diagnostics center, and native-player adapters are not implemented
- **THEN** the piece priority scheduler runtime can still generate deterministic plans, persist profile/plan/rule/application state, publish invalidation payloads, and expose read-only scheduler projections

### Requirement: Repository baseline SHALL validate Step 20 boundary terms
The repository baseline SHALL include validation for piece priority scheduler runtime files that rejects later Phase 4 timeline features and concrete implementation dependencies while allowing Streaming scheduler contracts, BT task projections, virtual stream projections, storage contracts, cache invalidation contracts, and deterministic adapter fixtures.

#### Scenario: Boundary checker runs
- **WHEN** the Step 20 piece priority scheduler runtime checker scans project files
- **THEN** forbidden dependencies on concrete UI, concrete torrent engines, FFI, sockets, range servers, pipe servers, filesystem byte reads, timeline overlay rendering, RSS auto-download execution, online-rule parsing, diagnostics, network implementation, storage migration, MPV/VLC, media-kit, platform channels, or native-player bindings fail validation
