## ADDED Requirements

### Requirement: WebView session backfill SHALL provide runtime acceptance layer
The system SHALL expose manual WebView session backfill through a runtime facade that provides bootstrap composition, typed scoped outcomes, store-backed projections, restart replay, and unavailable/disposed/capability gates.

#### Scenario: Runtime wraps manual completion contract
- **WHEN** a manual challenge is completed through the runtime
- **THEN** the runtime delegates to `WebViewSessionBackfill.completeManually`, stores captured artifacts and challenge state, publishes invalidation events, and returns a typed projection

### Requirement: WebView session backfill SHALL replay same-origin artifacts through runtime projections
The system SHALL allow a runtime snapshot to replay challenge, artifact, and backfill attempt state from storage so provider session flows can determine whether same-origin artifacts are available after restart.

#### Scenario: Stored artifact is replayed after restart
- **WHEN** approved same-origin artifacts exist in storage for a provider scope
- **THEN** a fresh runtime can project those artifacts and prepare a retry descriptor without reading global browser state
