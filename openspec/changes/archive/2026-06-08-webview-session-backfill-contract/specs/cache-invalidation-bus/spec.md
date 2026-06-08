## ADDED Requirements

### Requirement: WebView session backfill mutations SHALL publish invalidation events
The system SHALL publish explicit invalidation events when WebView challenge requests are created, challenge state changes, session artifacts are captured, backfill attempts complete, artifacts expire or are revoked, or platform capability state changes.

#### Scenario: Session artifact is captured
- **WHEN** a manual WebView challenge flow captures an approved same-origin session artifact
- **THEN** a WebView session backfill invalidation event is published so provider state, derived views, and future diagnostics snapshots can refresh without direct cross-module mutation

#### Scenario: Backfill capability changes
- **WHEN** isolated WebView capture or session artifact support becomes available or unavailable for a platform/provider scope
- **THEN** a capability invalidation event is published through CacheInvalidationBus rather than directly mutating provider or UI caches
