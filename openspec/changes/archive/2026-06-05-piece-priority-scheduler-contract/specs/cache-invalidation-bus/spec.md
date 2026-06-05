## MODIFIED Requirements

### Requirement: Cache invalidation SHALL be event-driven
The system SHALL define a `CacheInvalidationBus` that propagates business events used to invalidate cached state and refresh derived views across modules, including media library, playback history, provider binding mutations, seasonal catalog updates, Bangumi match queue changes, BT task lifecycle changes, virtual media stream range changes, and piece priority scheduler changes.

#### Scenario: A state-changing business event occurs
- **WHEN** a flow produces an event such as `DanmakuPosted`, `BindingChanged`, `ProviderAuthChanged`, `LibraryItemAdded`, `HistoryRecorded`, `SeasonalCatalogUpdated`, `BangumiMatchEnqueued`, `BangumiMatchApplied`, `BtTaskCreated`, `BtMetadataUpdated`, `BtTaskLifecycleChanged`, `BtTaskRemoved`, `VirtualStreamCreated`, `VirtualStreamRangeBuffered`, `VirtualStreamClosed`, `PiecePriorityPlanGenerated`, `PiecePriorityPlanApplied`, or `PiecePriorityProfileChanged`
- **THEN** the event is published through `CacheInvalidationBus` for interested consumers to process

## ADDED Requirements

### Requirement: Piece priority scheduler mutations SHALL publish invalidation events
The system SHALL publish explicit invalidation events when piece priority plans are generated, applied, rejected, or when the active scheduler profile changes.

#### Scenario: Scheduler profile changes
- **WHEN** scheduler orchestration selects a different strategy profile
- **THEN** a scheduler invalidation event is published so diagnostics and later timeline consumers can refresh derived state without direct cross-module mutation
