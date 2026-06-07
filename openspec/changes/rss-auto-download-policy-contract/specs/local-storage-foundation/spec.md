## ADDED Requirements

### Requirement: Storage foundation SHALL expose RSS auto-download persistence contracts
The system SHALL expose storage-backed contracts for RSS auto-download policies, matcher rules, evaluation history, accepted candidates, rejected candidates, deduplication state, and enqueue outcomes.

#### Scenario: RSS automation state survives restart
- **WHEN** RSS auto-download policies, candidate history, or enqueue outcomes are written to Storage
- **THEN** later automation flows can restore policy state and avoid duplicate BT handoffs without direct UI, RSS fetcher, torrent engine, or platform service coupling
