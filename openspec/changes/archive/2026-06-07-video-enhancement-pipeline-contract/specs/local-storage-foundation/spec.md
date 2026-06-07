## ADDED Requirements

### Requirement: Storage foundation SHALL expose video enhancement persistence contracts
The system SHALL expose storage-backed contracts for video enhancement profiles, active profile selection, and latest enhancement pipeline state metadata.

#### Scenario: Enhancement profile state survives restart
- **WHEN** an enhancement profile or active profile selection is written to Storage
- **THEN** later Playback flows can restore declarative enhancement intent without direct database, shader file, renderer, native plugin, or UI persistence coupling
