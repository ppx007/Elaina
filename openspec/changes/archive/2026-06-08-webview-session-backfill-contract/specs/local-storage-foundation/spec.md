## ADDED Requirements

### Requirement: Storage foundation SHALL expose WebView session backfill persistence contracts
The system SHALL expose storage-backed contracts for WebView challenge requests, normalized session artifacts, backfill attempts, retry outcomes, artifact expiry, artifact revocation, and platform capability state.

#### Scenario: Backfill state survives restart
- **WHEN** a challenge request, captured artifact, backfill attempt, expiry, revocation, or capability state is written to Storage
- **THEN** later provider session flows can resume or reject the backfill state through Storage contracts without direct UI, WebView adapter, provider, browser profile, or database coupling

#### Scenario: Artifact is revoked
- **WHEN** a user or provider session boundary revokes a captured artifact
- **THEN** Storage records the artifact as inactive so later retry descriptors cannot attach it to provider traffic
