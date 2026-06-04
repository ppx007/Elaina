## MODIFIED Requirements

### Requirement: Cache invalidation SHALL be event-driven
The system SHALL define a `CacheInvalidationBus` that propagates business events used to invalidate cached state and refresh derived views across modules, including media library, playback history, provider binding mutations, seasonal catalog updates, and Bangumi match queue changes.

#### Scenario: A state-changing business event occurs
- **WHEN** a flow produces an event such as `DanmakuPosted`, `BindingChanged`, `ProviderAuthChanged`, `LibraryItemAdded`, `HistoryRecorded`, `SeasonalCatalogUpdated`, `BangumiMatchEnqueued`, or `BangumiMatchApplied`
- **THEN** the event is published through `CacheInvalidationBus` for interested consumers to process

## ADDED Requirements

### Requirement: Seasonal indexer mutations SHALL publish invalidation events
The system SHALL publish explicit invalidation events when seasonal catalog entries are updated, Bangumi match work is enqueued, or automatic matches are applied.

#### Scenario: Seasonal catalog changes
- **WHEN** seasonal indexing persists new or updated catalog entries
- **THEN** a seasonal catalog invalidation event is published for subscribers to refresh derived state
