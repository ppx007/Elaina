## ADDED Requirements

### Requirement: Storage foundation SHALL persist BT runtime bootstrap state atomically
The storage foundation SHALL provide BT task storage contracts that allow Step 18 runtime bootstrap flows to persist task identity, source binding, lifecycle state, metadata availability, selected files, transfer snapshot metadata, latest event metadata, and runtime snapshot visibility as atomic task-state transitions.

#### Scenario: Runtime command changes task state
- **WHEN** BT task creation, metadata fetch, file selection, lifecycle command, status observation, or event observation changes persisted task state
- **THEN** storage records the related task, metadata, file, transfer, event, and visibility state as one coherent transition before the runtime reports the mutation as replayable

### Requirement: Storage foundation SHALL support BT runtime restart reconciliation
The storage foundation SHALL expose enough persisted BT task state for runtime bootstrap code to distinguish resumable, paused, terminal, failed, removed, and incomplete task records after restart without querying a concrete torrent engine directly.

#### Scenario: Runtime starts after process restart
- **WHEN** the BT task core runtime bootstraps from persisted storage
- **THEN** it can rebuild task projections and identify which tasks require adapter reconciliation, which are terminal, and which are not safely resumable using storage contracts rather than engine-owned persistence

### Requirement: Storage foundation SHALL version BT runtime task records
The storage foundation SHALL keep BT runtime task records compatible with schema/version evolution so later Phase 4 and diagnostics consumers can extend handoff metadata without direct database, file layout, or engine coupling.

#### Scenario: Task storage shape evolves
- **WHEN** a later change adds task handoff metadata, transfer metadata, or diagnostics metadata to BT task storage
- **THEN** schema/version handling preserves existing task records and exposes the evolved shape through Storage-layer contracts

### Requirement: Storage foundation MUST enforce BT runtime storage boundaries
The storage foundation MUST prevent UI, Playback, Provider, concrete torrent engines, virtual stream servers, piece schedulers, timeline overlays, and diagnostics consumers from bypassing approved BT task storage contracts for Step 18 runtime state.

#### Scenario: Derived consumer needs task state
- **WHEN** a derived consumer needs BT task identity, lifecycle, metadata, file selection, transfer, or event state
- **THEN** it reads through BT task storage or runtime projection contracts rather than direct database, filesystem, engine session, or module-owned cache access
