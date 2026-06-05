## ADDED Requirements

### Requirement: BT task core contract SHALL provide scheduler metadata state
The system SHALL expose enough persisted BT task metadata, piece length, file offsets, and selected file records for piece priority planning to proceed without querying concrete download engines directly.

#### Scenario: Scheduler requests task piece state
- **WHEN** the piece priority scheduler plans priorities for a virtual stream file
- **THEN** it reads task metadata, piece length, file offsets, and selected file records through BT task core Storage contracts rather than using adapter-specific torrent objects
