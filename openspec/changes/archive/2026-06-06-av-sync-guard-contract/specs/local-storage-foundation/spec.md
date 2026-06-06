## ADDED Requirements

### Requirement: Storage foundation SHALL expose AV sync guard persistence contracts
The system SHALL expose storage-backed contracts for AV sync guard policy configuration, latest health state, sample history metadata, and degradation decision history.

#### Scenario: AV sync guard state survives restart
- **WHEN** AV sync policy, health, sample metadata, or degradation decisions are written to Storage
- **THEN** later Playback flows can restore deterministic guard state without direct database, renderer, native plugin, diagnostics, or UI persistence coupling
