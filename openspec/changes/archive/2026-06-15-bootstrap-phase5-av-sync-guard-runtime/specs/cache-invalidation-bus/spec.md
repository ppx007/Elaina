## MODIFIED Requirements

### Requirement: Cache invalidation bus SHALL support AV sync guard runtime health transitions
The cache invalidation bus SHALL propagate AV sync guard health transitions, degradation decisions, sample ingestion, and recovery state changes published through the runtime acceptance layer so playback surfaces and future diagnostics consumers can refresh derived state without direct cross-module mutation. The runtime SHALL publish the same event types that the deterministic guard already emits, delivered through the bus accepted at bootstrap construction.

#### Scenario: Runtime publishes health transition on ingestion
- **WHEN** a sample is ingested through the runtime and the deterministic guard health transitions
- **THEN** an `AVSyncHealthTransitioned` event is published to the cache invalidation bus accepted at bootstrap

#### Scenario: Runtime publishes degradation decision
- **WHEN** a degradation request is accepted through the runtime
- **THEN** an `AVSyncDegradationDecisionRecorded` event is published to the bus
