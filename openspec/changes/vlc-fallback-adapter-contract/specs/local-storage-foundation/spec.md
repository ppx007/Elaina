## ADDED Requirements

### Requirement: Storage foundation SHALL expose fallback adapter persistence contracts
The system SHALL expose storage-backed contracts for fallback adapter candidates, active fallback configuration, fallback selection history, and latest fallback strategy state metadata.

#### Scenario: Fallback adapter state survives restart
- **WHEN** fallback candidates, active fallback configuration, selection history, or latest fallback state metadata are written to Storage
- **THEN** later Playback flows can restore fallback strategy state without direct UI, native adapter, VLC package, or platform player coupling
