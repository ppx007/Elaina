## MODIFIED Requirements

### Requirement: Cache invalidation bus SHALL support RSS auto-download policy runtime decision events
The cache invalidation bus SHALL propagate RSS auto-download policy runtime evaluation decisions, candidate acceptances, candidate rejections, deduplication state changes, enqueue outcome recordings, and policy enable/disable changes published through the runtime acceptance layer using the existing event types. The runtime SHALL publish RssAutoDownloadFeedItemEvaluated, RssAutoDownloadCandidateAccepted, RssAutoDownloadCandidateRejected, RssAutoDownloadDedupeStateChanged, RssAutoDownloadEnqueueOutcomeRecorded, and RssAutoDownloadPolicyChanged events through the bus accepted at bootstrap construction.

#### Scenario: Runtime publishes feed item evaluated event on evaluation
- **WHEN** a feed item is evaluated through the runtime
- **THEN** an RssAutoDownloadFeedItemEvaluated event is published to the cache invalidation bus

#### Scenario: Runtime publishes candidate accepted event on handoff
- **WHEN** a candidate handoff is accepted through the runtime
- **THEN** an RssAutoDownloadCandidateAccepted event is published to the bus

#### Scenario: Runtime publishes policy changed event on disable
- **WHEN** a policy is disabled through the runtime
- **THEN** an RssAutoDownloadPolicyChanged event with changeKind disabled is published to the bus
