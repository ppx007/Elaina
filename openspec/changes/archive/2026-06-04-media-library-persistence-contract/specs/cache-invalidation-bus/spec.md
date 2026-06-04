## MODIFIED Requirements

### Requirement: Cache invalidation SHALL be event-driven
The system SHALL define a `CacheInvalidationBus` that propagates business events used to invalidate cached state and refresh derived views across modules, including media library, playback history, and provider binding mutations.

#### Scenario: A state-changing business event occurs
- **WHEN** a flow produces an event such as `DanmakuPosted`, `BindingChanged`, `ProviderAuthChanged`, `LibraryItemAdded`, or `HistoryRecorded`
- **THEN** the event is published through `CacheInvalidationBus` for interested consumers to process

### Requirement: Consumers MUST react without direct cross-module mutation
The system MUST allow modules to invalidate or refresh their cached state in response to bus events without directly mutating another module's internal cache structures, including media catalog-derived views.

#### Scenario: Binding state changes
- **WHEN** a Bangumi binding or equivalent domain association changes
- **THEN** subscribed consumers invalidate or refresh affected derived state through their own handlers instead of reaching into another module's cache implementation

## ADDED Requirements

### Requirement: Media library mutations SHALL publish invalidation events
The system SHALL publish explicit invalidation events when media library items are added, updated, or removed so cached detail and catalog views can refresh without direct mutation.

#### Scenario: A catalog item is removed
- **WHEN** a media library item is removed from persistent storage
- **THEN** a removal event is published on the cache invalidation bus for subscribers to refresh derived catalog state
