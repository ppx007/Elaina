## MODIFIED Requirements

### Requirement: Cache invalidation SHALL be event-driven
The system SHALL define a `CacheInvalidationBus` that propagates business events used to invalidate cached state and refresh derived views across modules, including media library, playback history, provider binding mutations, seasonal catalog updates, Bangumi match queue changes, BT task lifecycle changes, and virtual media stream range changes.

#### Scenario: A state-changing business event occurs
- **WHEN** a flow produces an event such as `DanmakuPosted`, `BindingChanged`, `ProviderAuthChanged`, `LibraryItemAdded`, `HistoryRecorded`, `SeasonalCatalogUpdated`, `BangumiMatchEnqueued`, `BangumiMatchApplied`, `BtTaskCreated`, `BtMetadataUpdated`, `BtTaskLifecycleChanged`, `BtTaskRemoved`, `VirtualStreamCreated`, `VirtualStreamRangeBuffered`, or `VirtualStreamClosed`
- **THEN** the event is published through `CacheInvalidationBus` for interested consumers to process

## ADDED Requirements

### Requirement: Virtual media stream mutations SHALL publish invalidation events
The system SHALL publish explicit invalidation events when virtual streams are created, buffered ranges change, range requests fail, or streams are closed.

#### Scenario: Virtual stream buffered range changes
- **WHEN** stream orchestration records newly available bytes for a virtual stream
- **THEN** a virtual stream invalidation event is published so playback surfaces and later timeline consumers can refresh derived state without direct cross-module mutation
