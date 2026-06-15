## ADDED Requirements

### Requirement: RSS auto-download policy SHALL support runtime acceptance layer
The system SHALL allow policy evaluation to be consumed through a runtime facade that provides storage-backed projections, typed scoped outcomes, restart replay, and dispose/unavailable/capability gates instead of calling the deterministic evaluator directly from UI or application flows.

#### Scenario: Runtime wraps evaluator with storage and projections
- **WHEN** the Step 26 runtime acceptance layer is implemented
- **THEN** policy evaluation is consumed through RssAutoDownloadPolicyRuntime.evaluate() which delegates to the deterministic evaluator, persists results to RssAutoDownloadPolicyStore, and returns a typed projection

### Requirement: RSS auto-download policy decisions SHALL propagate through invalidation bus
The system SHALL propagate RSS auto-download policy evaluation decisions (feed item evaluated, candidate accepted, candidate rejected, dedupe state changed, enqueue outcome recorded, policy changed) through the CacheInvalidationBus accepted at bootstrap construction so downstream consumers can refresh derived state.

#### Scenario: Runtime publishes evaluation events
- **WHEN** an evaluation is processed through the runtime for a supported scope
- **THEN** RssAutoDownloadFeedItemEvaluated and appropriate candidate events are published to the cache invalidation bus
