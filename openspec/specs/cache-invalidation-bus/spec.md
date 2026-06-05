# cache-invalidation-bus Specification

## Purpose
TBD - created by archiving change bootstrap-phase-0-foundation. Update Purpose after archive.
## Requirements
### Requirement: Cache invalidation SHALL be event-driven
The system SHALL define a `CacheInvalidationBus` that propagates business events used to invalidate cached state and refresh derived views across modules, including media library, playback history, provider binding mutations, seasonal catalog updates, Bangumi match queue changes, BT task lifecycle changes, virtual media stream range changes, and piece priority scheduler changes.

#### Scenario: A state-changing business event occurs
- **WHEN** a flow produces an event such as `DanmakuPosted`, `BindingChanged`, `ProviderAuthChanged`, `LibraryItemAdded`, `HistoryRecorded`, `SeasonalCatalogUpdated`, `BangumiMatchEnqueued`, `BangumiMatchApplied`, `BtTaskCreated`, `BtMetadataUpdated`, `BtTaskLifecycleChanged`, `BtTaskRemoved`, `VirtualStreamCreated`, `VirtualStreamRangeBuffered`, `VirtualStreamClosed`, `PiecePriorityPlanGenerated`, `PiecePriorityPlanApplied`, or `PiecePriorityProfileChanged`
- **THEN** the event is published through `CacheInvalidationBus` for interested consumers to process

### Requirement: Consumers MUST react without direct cross-module mutation
The system MUST allow modules to invalidate or refresh their cached state in response to bus events without directly mutating another module's internal cache structures, including media catalog-derived views.

#### Scenario: Binding state changes
- **WHEN** a Bangumi binding or equivalent domain association changes
- **THEN** subscribed consumers invalidate or refresh affected derived state through their own handlers instead of reaching into another module's cache implementation

### Requirement: Media library mutations SHALL publish invalidation events
The system SHALL publish explicit invalidation events when media library items are added, updated, or removed so cached detail and catalog views can refresh without direct mutation.

#### Scenario: A catalog item is removed
- **WHEN** a media library item is removed from persistent storage
- **THEN** a removal event is published on the cache invalidation bus for subscribers to refresh derived catalog state

### Requirement: New invalidation use cases SHALL extend by adding events
The system SHALL support future invalidation needs by adding new event types and subscribers rather than introducing point-to-point invalidation coupling.

#### Scenario: A later feature needs invalidation
- **WHEN** a new feature requires cache refresh behavior in a future phase
- **THEN** the feature defines or reuses an event on `CacheInvalidationBus` instead of adding direct service-to-service invalidation calls

### Requirement: Seasonal indexer mutations SHALL publish invalidation events
The system SHALL publish explicit invalidation events when seasonal catalog entries are updated, Bangumi match work is enqueued, or automatic matches are applied.

#### Scenario: Seasonal catalog changes
- **WHEN** seasonal indexing persists new or updated catalog entries
- **THEN** a seasonal catalog invalidation event is published for subscribers to refresh derived state

### Requirement: BT task mutations SHALL publish invalidation events
The system SHALL publish explicit invalidation events when BT tasks are created, metadata becomes available, lifecycle status changes, file selections change, or tasks are removed.

#### Scenario: BT task lifecycle changes
- **WHEN** BT task orchestration persists a new lifecycle state or removes a task
- **THEN** a BT task invalidation event is published so derived views and diagnostics can refresh without direct cross-module mutation

### Requirement: Virtual media stream mutations SHALL publish invalidation events
The system SHALL publish explicit invalidation events when virtual streams are created, buffered ranges change, range requests fail, or streams are closed.

#### Scenario: Virtual stream buffered range changes
- **WHEN** stream orchestration records newly available bytes for a virtual stream
- **THEN** a virtual stream invalidation event is published so playback surfaces and later timeline consumers can refresh derived state without direct cross-module mutation

### Requirement: Piece priority scheduler mutations SHALL publish invalidation events
The system SHALL publish explicit invalidation events when piece priority plans are generated, applied, rejected, or when the active scheduler profile changes.

#### Scenario: Scheduler profile changes
- **WHEN** scheduler orchestration selects a different strategy profile
- **THEN** a scheduler invalidation event is published so diagnostics and later timeline consumers can refresh derived state without direct cross-module mutation

