## ADDED Requirements

### Requirement: Storage foundation SHALL expose online rule runtime persistence contracts
The system SHALL expose storage-backed contracts for online rule source manifests, manifest versions, rule sets, extraction operations, validation issues, evaluation snapshots, page retrieval outcomes, unsupported operations, and source capability state.

#### Scenario: Online rule source state survives restart
- **WHEN** online rule manifests, validation issues, evaluation snapshots, or retrieval outcomes are written to Storage
- **THEN** later online rule flows can restore source state and validation decisions without direct UI, crawler, WebView, JavaScript runtime, or network resolver coupling
