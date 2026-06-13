# timeline-overlay Specification

## Purpose
TBD - created by archiving change bootstrap-bt-streaming-core. Update Purpose after archive.
## Requirements
### Requirement: Timeline overlay SHALL expose playback and buffer read models
The system SHALL define timeline overlay contracts for playback progress, buffered ranges, and BT piece states without giving UI direct control over download tasks.

#### Scenario: Timeline is rendered
- **WHEN** UI renders a playback timeline
- **THEN** it consumes overlay read models rather than concrete BT task or download engine objects

### Requirement: Timeline overlay SHALL support layered markers
The system SHALL define marker or heat layers that can represent buffer, piece, danmaku, subtitle, or future diagnostic hints as separate overlay layers.

#### Scenario: Multiple timeline layers are available
- **WHEN** playback, buffer, and marker data are available
- **THEN** the timeline overlay exposes them as distinct layers that UI can show or hide

### Requirement: Timeline overlay MUST remain presentation-facing
The system MUST keep timeline overlay contracts as read models and avoid making them responsible for BT task lifecycle, RSS auto-download, or diagnostics-center behavior.

#### Scenario: User inspects piece progress
- **WHEN** UI displays piece progress on the timeline
- **THEN** it reads overlay data and does not mutate BT task or scheduler state through the overlay

### Requirement: Timeline overlay SHALL align with durable Step 21 contracts
The timeline overlay capability SHALL be backed by durable Step 21 timeline overlay contracts that expose immutable snapshots, layer descriptors, and read-only range projections for playback surfaces.

#### Scenario: Bootstrap overlay is refined
- **WHEN** the Step 21 timeline overlay contract is implemented
- **THEN** the bootstrap timeline overlay capability delegates concrete contract behavior to `timeline-overlay-contract` requirements while preserving its presentation-facing boundary

### Requirement: Timeline overlay SHALL keep overlay composition read-only
The timeline overlay capability SHALL treat progress, buffer, piece, marker, and heat data as read-only projections and MUST NOT provide mutation APIs for BT task lifecycle, virtual stream byte serving, or piece priority scheduling.

#### Scenario: Overlay displays priority state
- **WHEN** the overlay displays scheduler priority windows on a playback timeline
- **THEN** it reads derived priority-layer data and does not apply, reject, or regenerate scheduler plans through the overlay

### Requirement: Runtime bootstrap projections
Timeline overlay SHALL expose runtime/bootstrap projections for active profile, ordered layers, latest snapshot metadata, and composition failures without requiring UI rendering state.

#### Scenario: Runtime projection exposes layer order
- **WHEN** a timeline overlay runtime snapshot is read
- **THEN** it SHALL include stable layer identifiers, kinds, visibility, and ordering metadata.

### Requirement: Overlay composition remains read-only
Timeline overlay SHALL compose progress, buffer, piece, priority, marker, and heat layers from upstream projections without mutating those upstream domains.

#### Scenario: Priority layer consumes scheduler data
- **WHEN** priority windows are included in a timeline overlay snapshot
- **THEN** the overlay SHALL consume them as read-only projection data and SHALL NOT regenerate or apply scheduler plans.

### Requirement: Runtime layer configuration
Timeline overlay SHALL allow runtime layer configuration changes only as presentation-state changes over persisted layer records.

#### Scenario: Hidden layer remains persisted
- **WHEN** a layer is hidden by runtime configuration
- **THEN** its layer descriptor SHALL remain persisted with visibility set to hidden rather than deleting upstream projection data.
