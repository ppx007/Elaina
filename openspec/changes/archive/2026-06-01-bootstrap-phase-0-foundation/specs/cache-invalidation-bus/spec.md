## ADDED Requirements

### Requirement: Cache invalidation SHALL be event-driven
The system SHALL define a `CacheInvalidationBus` that propagates business events used to invalidate cached state and refresh derived views across modules.

#### Scenario: A state-changing business event occurs
- **WHEN** a flow produces an event such as `DanmakuPosted`, `BindingChanged`, or `ProviderAuthChanged`
- **THEN** the event is published through `CacheInvalidationBus` for interested consumers to process

### Requirement: Consumers MUST react without direct cross-module mutation
The system MUST allow modules to invalidate or refresh their cached state in response to bus events without directly mutating another module's internal cache structures.

#### Scenario: Binding state changes
- **WHEN** a Bangumi binding or equivalent domain association changes
- **THEN** subscribed consumers invalidate or refresh affected derived state through their own handlers instead of reaching into another module's cache implementation

### Requirement: New invalidation use cases SHALL extend by adding events
The system SHALL support future invalidation needs by adding new event types and subscribers rather than introducing point-to-point invalidation coupling.

#### Scenario: A later feature needs invalidation
- **WHEN** a new feature requires cache refresh behavior in a future phase
- **THEN** the feature defines or reuses an event on `CacheInvalidationBus` instead of adding direct service-to-service invalidation calls
