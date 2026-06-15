## ADDED Requirements

### Requirement: Local storage foundation SHALL support WebView session backfill runtime replay
The local storage foundation SHALL allow the WebView session backfill runtime to persist and replay challenge requests, normalized session artifacts, backfill attempts, artifact revocation state, and capability state through existing `WebViewSessionBackfillStore` contracts.

#### Scenario: Runtime rebuilds projection from store after restart
- **WHEN** a new runtime instance is created for a provider scope with stored challenge, artifact, attempt, and capability records
- **THEN** the runtime projection reads those records from storage without requiring a concrete browser or WebView session

#### Scenario: Runtime records backfill attempt after retry preparation
- **WHEN** retry descriptor preparation succeeds or fails
- **THEN** the runtime records a `StoredWebViewSessionBackfillAttemptRecord` before returning the projection
