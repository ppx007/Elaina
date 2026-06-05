## MODIFIED Requirements

### Requirement: Cache invalidation SHALL be event-driven
The system SHALL define a `CacheInvalidationBus` that propagates business events used to invalidate cached state and refresh derived views across modules, including media library, playback history, provider binding mutations, seasonal catalog updates, Bangumi match queue changes, and BT task lifecycle changes.

#### Scenario: A state-changing business event occurs
- **WHEN** a flow produces an event such as `DanmakuPosted`, `BindingChanged`, `ProviderAuthChanged`, `LibraryItemAdded`, `HistoryRecorded`, `SeasonalCatalogUpdated`, `BangumiMatchEnqueued`, `BangumiMatchApplied`, `BtTaskCreated`, `BtMetadataUpdated`, `BtTaskLifecycleChanged`, or `BtTaskRemoved`
- **THEN** the event is published through `CacheInvalidationBus` for interested consumers to process

## ADDED Requirements

### Requirement: BT task mutations SHALL publish invalidation events
The system SHALL publish explicit invalidation events when BT tasks are created, metadata becomes available, lifecycle status changes, file selections change, or tasks are removed.

#### Scenario: BT task lifecycle changes
- **WHEN** BT task orchestration persists a new lifecycle state or removes a task
- **THEN** a BT task invalidation event is published so derived views and diagnostics can refresh without direct cross-module mutation
