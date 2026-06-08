## ADDED Requirements

### Requirement: Cache invalidation bootstrap SHALL manage bus lifecycle
The system SHALL provide Phase 0 bootstrap wiring for a lifecycle-managed CacheInvalidationBus that can publish, observe, and close foundation invalidation streams deterministically.

#### Scenario: Foundation runtime is disposed
- **WHEN** the Phase 0 foundation runtime bootstrap is disposed or closed
- **THEN** the cache invalidation bus rejects later publishes and releases its stream resources deterministically

### Requirement: Cache invalidation bootstrap SHALL remain cross-layer and payload-only
The cache invalidation bootstrap SHALL carry event payloads across foundation services without directly invoking UI refreshes, playback controls, provider retries, BT commands, network policy mutation, or storage migrations.

#### Scenario: Storage event is published
- **WHEN** a foundation storage or provider gateway operation publishes a cache invalidation event
- **THEN** subscribers receive the typed event payload without the bus performing downstream lifecycle or mutation actions
