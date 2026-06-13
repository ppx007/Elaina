## ADDED Requirements

### Requirement: Overlay-safe stream projections
Virtual media stream SHALL expose stream descriptors, duration/length metadata, and buffered range snapshots as read-only inputs for timeline overlay runtime composition.

#### Scenario: Timeline consumes buffered ranges
- **WHEN** timeline overlay runtime receives virtual stream buffered ranges
- **THEN** it SHALL treat them as read-only projection data and SHALL NOT close, fail, or mutate the stream.

### Requirement: Overlay boundary over stream lifecycle
Virtual media stream lifecycle operations SHALL remain owned by virtual stream runtime and SHALL NOT be performed by timeline overlay runtime.

#### Scenario: Overlay sees closed stream state
- **WHEN** a stream is closed before timeline composition
- **THEN** the overlay runtime SHALL return a typed unavailable or rejected composition outcome instead of reopening or mutating the stream.
