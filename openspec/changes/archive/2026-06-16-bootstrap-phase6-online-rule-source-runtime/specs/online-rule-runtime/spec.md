## ADDED Requirements

### Requirement: Online rule runtime SHALL support runtime acceptance layer
The system SHALL allow manifest validation and document evaluation to be consumed through a runtime facade that provides storage-backed projections, typed scoped outcomes, restart replay, and dispose/unavailable/capability gates instead of calling the deterministic runtime directly from UI or application flows.

#### Scenario: Runtime wraps deterministic evaluator with storage and projections
- **WHEN** the Step 27 runtime acceptance layer is implemented
- **THEN** manifest validation is consumed through OnlineRuleSourceRuntime.validate() which delegates to the deterministic runtime, persists results to OnlineRuleRuntimeStore, and returns a typed projection

### Requirement: Online rule runtime decisions SHALL propagate through invalidation bus
The system SHALL propagate online rule validation state changes, manifest changes, target evaluations, and unsupported operation recordings through the CacheInvalidationBus accepted at bootstrap construction so downstream consumers can refresh derived state.

#### Scenario: Runtime publishes validation events
- **WHEN** a manifest is validated through the runtime for a supported scope
- **THEN** OnlineRuleValidationStateChanged and OnlineRuleManifestChanged events are published to the cache invalidation bus
