## ADDED Requirements

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
