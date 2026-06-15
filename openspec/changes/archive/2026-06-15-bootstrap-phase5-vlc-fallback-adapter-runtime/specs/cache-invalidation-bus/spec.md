## ADDED Requirements

### Requirement: Cache invalidation bus SHALL support fallback runtime state transition events
The system SHALL allow the fallback adapter runtime to publish `FallbackStrategyStateChanged` and `FallbackSelectionChanged` events when the runtime wraps strategy operations that change fallback state.

#### Scenario: Runtime publishes strategy state transition on selection
- **WHEN** the runtime wraps `selectFallback()` and the strategy publishes `FallbackStrategyStateChanged`
- **THEN** the invalidation event is observable through the cache invalidation bus

### Requirement: Cache invalidation bus SHALL support fallback runtime registration events
The system SHALL allow the fallback adapter runtime to observe `FallbackAdapterRegistrationChanged` events when candidates are registered or deregistered through the runtime.

#### Scenario: Runtime publishes registration change on candidate registration
- **WHEN** the runtime wraps `registerCandidate()` and the strategy publishes `FallbackAdapterRegistrationChanged`
- **THEN** the invalidation event is observable through the cache invalidation bus

### Requirement: Cache invalidation bus SHALL support fallback runtime capability reevaluation events
The system SHALL allow the fallback adapter runtime to observe `FallbackCapabilityReevaluated` events when capabilities are reevaluated through the runtime.

#### Scenario: Runtime publishes capability reevaluation on reevaluateCapabilities
- **WHEN** the runtime wraps `reevaluateCapabilities()` and the strategy publishes `FallbackCapabilityReevaluated`
- **THEN** the invalidation event is observable through the cache invalidation bus
