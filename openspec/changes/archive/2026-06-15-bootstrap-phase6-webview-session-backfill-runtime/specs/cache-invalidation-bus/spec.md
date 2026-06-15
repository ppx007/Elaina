## ADDED Requirements

### Requirement: Cache invalidation bus SHALL support WebView session backfill runtime events
The cache invalidation bus SHALL carry WebView session backfill runtime events for challenge lifecycle changes, artifact capture, backfill attempt outcomes, artifact state changes, and capability changes.

#### Scenario: Runtime records challenge capture
- **WHEN** manual completion captures approved session artifacts through the runtime
- **THEN** `WebViewSessionChallengeChanged` and `WebViewSessionArtifactCaptured` events are published through the bus

#### Scenario: Runtime records retry preparation outcome
- **WHEN** a retry descriptor succeeds or fails through the runtime
- **THEN** `WebViewSessionBackfillOutcomeRecorded` is published after the attempt is stored

#### Scenario: Runtime records artifact revocation
- **WHEN** an artifact is revoked through the runtime
- **THEN** `WebViewSessionArtifactStateChanged` is published through the bus
