## ADDED Requirements

### Requirement: Storage foundation SHALL expose advanced caption persistence contracts
The system SHALL expose storage-backed contracts for advanced caption profiles, active feature selection, dual-subtitle preferences, and latest renderer state metadata.

#### Scenario: Advanced caption state survives restart
- **WHEN** advanced caption feature toggles, selected subtitle tracks, and renderer state metadata are written to Storage
- **THEN** later playback preparation can restore advanced caption state without direct UI, renderer, or provider coupling
