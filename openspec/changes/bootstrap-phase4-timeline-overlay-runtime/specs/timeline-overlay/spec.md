## ADDED Requirements

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
