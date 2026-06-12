## ADDED Requirements

### Requirement: Piece priority scheduler SHALL expose runtime bootstrap projections
The piece priority scheduler capability SHALL expose runtime/bootstrap projections for active profile state, latest generated plan, ordered priority rules, latest application outcome, typed planning failures, and restart visibility.

#### Scenario: Runtime snapshot is requested
- **WHEN** a caller reads scheduler runtime state after profile selection, plan generation, and application recording have been persisted
- **THEN** the capability returns immutable projections reconstructed from scheduler storage contracts

### Requirement: Piece priority scheduler SHALL gate plan generation by stream and task state
The piece priority scheduler capability SHALL reject planning when required BT metadata, selected file state, file-piece maps, virtual stream state, or strategy profile state is unavailable or inconsistent.

#### Scenario: Selected file is missing
- **WHEN** a scheduler plan is requested for a virtual stream whose backing BT file record is missing or skipped
- **THEN** the capability returns a typed file-map failure and does not generate priority rules

### Requirement: Piece priority scheduler SHALL provide timeline-safe priority projections
The piece priority scheduler capability SHALL expose generated plan summaries, priority rule ranges, active profile metadata, and application outcomes as read-only data for later timeline overlays without owning overlay composition or rendering.

#### Scenario: Timeline reads scheduler state later
- **WHEN** a later timeline overlay runtime needs current playback and seek priority windows
- **THEN** it can read scheduler projections without regenerating plans, applying priorities, or importing concrete download-engine objects
