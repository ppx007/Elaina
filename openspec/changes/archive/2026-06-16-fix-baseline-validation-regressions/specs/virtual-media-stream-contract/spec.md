## MODIFIED Requirements

### Requirement: Virtual media stream contract SHALL normalize range failures
The virtual media stream contract SHALL provide normalized failures for missing
stream, wrong stream, closed stream, failed stream, missing task metadata,
missing selected file, skipped selected file, out-of-bounds range, unavailable
adapter boundary, and disposed runtime state. A missing selected file SHALL be
reported as `fileUnavailable`; a selected file explicitly marked skipped SHALL
be reported as `fileSkipped`.

#### Scenario: Skipped selected file is requested
- **WHEN** stream creation is requested for a persisted BT task file whose selection state is skipped
- **THEN** stream creation returns a typed `fileSkipped` failure without probing concrete IO, engine, network, or native-player implementations
