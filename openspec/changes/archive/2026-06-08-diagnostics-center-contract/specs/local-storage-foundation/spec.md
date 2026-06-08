## ADDED Requirements

### Requirement: Storage foundation SHALL expose diagnostics persistence contracts
The system SHALL expose storage-backed contracts for diagnostics event schemas, redacted diagnostics events, diagnostics snapshots, export requests, export outcomes, retention state, and diagnostics capability state.

#### Scenario: Diagnostics state survives restart
- **WHEN** diagnostics schemas, events, snapshots, exports, retention outcomes, or capability state are written to Storage
- **THEN** later diagnostics flows can restore local read-model state without direct UI, telemetry, provider, playback, network policy, BT, or database coupling

#### Scenario: Redacted event is persisted
- **WHEN** diagnostics records an event with sensitive payload keys
- **THEN** Storage receives only the redacted diagnostics record and never receives raw session artifact, authorization, cookie, token, or local secret values
