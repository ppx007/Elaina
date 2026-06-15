## MODIFIED Requirements

### Requirement: Cache invalidation bus SHALL support online rule source runtime decision events
The cache invalidation bus SHALL propagate online rule source runtime manifest changes, validation state changes, target evaluations, and unsupported operation recordings published through the runtime acceptance layer using the existing event types. The runtime SHALL publish OnlineRuleManifestChanged, OnlineRuleValidationStateChanged, OnlineRuleTargetEvaluated, and OnlineRuleUnsupportedOperationRecorded events through the bus accepted at bootstrap construction.

#### Scenario: Runtime publishes validation state changed event on validate
- **WHEN** a manifest is validated through the runtime
- **THEN** an OnlineRuleValidationStateChanged event is published to the cache invalidation bus

#### Scenario: Runtime publishes target evaluated event on evaluate
- **WHEN** a document is evaluated through the runtime
- **THEN** an OnlineRuleTargetEvaluated event is published to the bus

#### Scenario: Runtime publishes manifest changed event on disable
- **WHEN** a manifest is disabled through the runtime
- **THEN** an OnlineRuleManifestChanged event with changeKind disabled is published to the bus
