## ADDED Requirements

### Requirement: Diagnostics center SHALL expose runtime acceptance projection
The diagnostics center SHALL expose a runtime acceptance projection that summarizes local schema, event, snapshot, export, retention, and capability state from deterministic storage while preserving read-only diagnostics semantics.

#### Scenario: Runtime projection summarizes local diagnostics
- **WHEN** diagnostics runtime snapshot is requested after local events have been recorded
- **THEN** the projection reports stored local diagnostics state without mutating playback, provider, RSS, online rule, WebView, BT, network policy, or UI state
