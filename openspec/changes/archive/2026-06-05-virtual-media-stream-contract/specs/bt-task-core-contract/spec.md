## ADDED Requirements

### Requirement: BT task core contract SHALL provide virtual stream handoff state
The system SHALL expose enough persisted BT task metadata, file selection state, and lifecycle state for virtual media stream creation to proceed without querying concrete download engines directly.

#### Scenario: Virtual stream requests task file state
- **WHEN** the virtual media stream registry creates a stream for a task file
- **THEN** it reads task metadata, selected file records, and lifecycle state through BT task core Storage contracts rather than using adapter-specific torrent objects
