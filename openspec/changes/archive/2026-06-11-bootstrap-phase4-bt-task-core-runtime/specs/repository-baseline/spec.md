## ADDED Requirements

### Requirement: Repository baseline SHALL keep BT task core runtime optional and isolated
The repository baseline SHALL treat the Step 18 BT task core runtime as optional Streaming/Domain orchestration that must not become a prerequisite for core playback, virtual media stream serving, piece-priority scheduling, timeline overlay rendering, RSS auto-download, online-rule runtime, diagnostics center, concrete UI, concrete network implementation, storage migration, or native-player implementation.

#### Scenario: Later BT playback slices are absent
- **WHEN** virtual media stream runtime, piece-priority scheduler runtime, timeline overlay runtime, concrete torrent engines, concrete UI pages, diagnostics center, and native-player adapters are not implemented
- **THEN** the BT task core runtime can still create deterministic tasks, persist metadata and file state, route lifecycle commands through adapter contracts, and expose replayable task projections

### Requirement: Repository baseline SHALL validate Step 18 boundary terms
The repository baseline SHALL include validation for BT task core runtime files that rejects later Phase 4 features and concrete implementation dependencies while allowing Streaming BT task contracts, storage task contracts, cache invalidation contracts, and deterministic adapter fixtures.

#### Scenario: Boundary checker runs
- **WHEN** the Step 18 BT task core runtime checker scans project files
- **THEN** forbidden dependencies on concrete UI, concrete torrent engines, FFI, socket/range servers, virtual stream serving, piece-priority scheduler runtime, timeline overlay rendering, RSS auto-download execution, online-rule parsing, diagnostics, network implementation, storage migration, MPV/VLC, or native-player bindings fail validation
