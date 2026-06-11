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

### Requirement: Timeline overlay mutations SHALL publish invalidation events
The system SHALL publish explicit invalidation events when timeline overlay snapshots refresh, layer configuration changes, or overlay composition is rejected because required read-model inputs are unavailable.

#### Scenario: Timeline layer configuration changes
- **WHEN** timeline overlay layer visibility, ordering, or active overlay profile changes
- **THEN** a timeline overlay invalidation event is published so playback surfaces and later diagnostics consumers can refresh derived state without direct cross-module mutation

### Requirement: AV sync guard mutations SHALL publish invalidation events
The system SHALL publish explicit invalidation events when AV sync samples are ingested, guard health transitions, degradation decisions are recorded, or guard state recovers.

#### Scenario: AV sync health transitions
- **WHEN** sustained samples move guard health from target to warning, warning to degraded, or degraded toward target
- **THEN** an AV sync invalidation event is published so playback surfaces and future diagnostics consumers can refresh derived state without direct cross-module mutation

### Requirement: Advanced caption mutations SHALL publish invalidation events
The system SHALL publish explicit invalidation events when advanced caption feature state, capability evaluation, renderer state, dual-subtitle selection, or degradation state changes.

#### Scenario: Dual subtitle selection changes
- **WHEN** primary or secondary subtitle selection changes for an advanced caption profile
- **THEN** an advanced caption invalidation event is published so derived playback state can refresh without direct cross-module mutation

### Requirement: Fallback adapter mutations SHALL publish invalidation events
The system SHALL publish explicit invalidation events when fallback adapters register or deregister, fallback capabilities are reevaluated, fallback selection changes, or fallback strategy state changes.

#### Scenario: Fallback selection changes
- **WHEN** a fallback adapter is selected for a playback scope
- **THEN** a fallback invalidation event is published so derived playback capability state can refresh without direct cross-module mutation

### Requirement: Video enhancement mutations SHALL publish invalidation events
The system SHALL publish explicit invalidation events when video enhancement profiles change, capability evaluation changes, or pipeline state transitions occur.

#### Scenario: Enhancement capability is reevaluated
- **WHEN** adapter capabilities or active profile selection cause enhancement support to change
- **THEN** a video enhancement invalidation event is published so playback surfaces and future diagnostics consumers can refresh derived state without direct cross-module mutation

### Requirement: RSS auto-download mutations SHALL publish invalidation events
The system SHALL publish explicit invalidation events when RSS auto-download policies change, feed items are evaluated, candidates are accepted or rejected, deduplication state changes, or BT enqueue handoff outcomes are recorded.

#### Scenario: Candidate is accepted
- **WHEN** RSS auto-download accepts a feed item as a download candidate
- **THEN** an automation invalidation event is published so derived views and diagnostics snapshots can refresh without direct cross-module mutation

### Requirement: Online rule runtime mutations SHALL publish invalidation events
The system SHALL publish explicit invalidation events when online rule manifests change, validation state changes, target evaluations run, unsupported operations are recorded, page retrieval outcomes are recorded, or source capability state changes.

#### Scenario: Manifest validation changes
- **WHEN** online rule validation records new issues or clears existing issues for a source manifest
- **THEN** an online rule invalidation event is published so derived views and diagnostics snapshots can refresh without direct cross-module mutation

### Requirement: WebView session backfill mutations SHALL publish invalidation events
The system SHALL publish explicit invalidation events when WebView challenge requests are created, challenge state changes, session artifacts are captured, backfill attempts complete, artifacts expire or are revoked, or platform capability state changes.

#### Scenario: Session artifact is captured
- **WHEN** a manual WebView challenge flow captures an approved same-origin session artifact
- **THEN** a WebView session backfill invalidation event is published so provider state, derived views, and future diagnostics snapshots can refresh without direct cross-module mutation

#### Scenario: Backfill capability changes
- **WHEN** isolated WebView capture or session artifact support becomes available or unavailable for a platform/provider scope
- **THEN** a capability invalidation event is published through CacheInvalidationBus rather than directly mutating provider or UI caches

### Requirement: Network policy mutations SHALL publish invalidation events
The system SHALL publish explicit invalidation events when network policy profiles change, provider assignments change, policy rules change, evaluation outcomes are recorded, block decisions occur, or network policy capability state changes.

#### Scenario: Provider policy assignment changes
- **WHEN** a provider scope is assigned to a different network policy profile
- **THEN** a network policy invalidation event is published so Gateway, Network, and future diagnostics consumers can refresh derived state without direct cross-module mutation

#### Scenario: Network policy blocks traffic
- **WHEN** a provider-scoped request is blocked by network policy
- **THEN** a network policy evaluation event is published with provider scope, target URI metadata, and normalized failure kind

### Requirement: Diagnostics mutations SHALL publish invalidation events
The system SHALL publish explicit invalidation events when diagnostics schemas are registered, diagnostics events are recorded, snapshots are created, retention is enforced, export requests or outcomes are recorded, or diagnostics capability state changes.

#### Scenario: Diagnostics event is recorded
- **WHEN** diagnostics records a redacted local event
- **THEN** a diagnostics invalidation event is published with event type, category, severity, source module, and correlation identity metadata

#### Scenario: Diagnostics retention runs
- **WHEN** diagnostics retention enforcement purges or bounds local events
- **THEN** a diagnostics retention invalidation event is published so derived diagnostics views can refresh without direct storage mutation

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

### Requirement: Cache invalidation bus SHALL publish correlated BT runtime invalidations
The cache invalidation bus SHALL carry correlated invalidation events for Step 18 BT task runtime mutations that affect task list projections, task detail projections, runtime snapshots, capability/status views, and repository-derived selectors.

#### Scenario: BT task mutation is persisted
- **WHEN** BT task creation, metadata fetch, file selection, lifecycle command, status observation, or event observation is persisted successfully
- **THEN** the runtime publishes or requests invalidation with enough task identity, mutation kind, and correlation metadata for consumers to refresh affected BT task read models without direct cross-module mutation

### Requirement: Cache invalidation bus SHALL preserve post-mutation read ordering
The cache invalidation bus SHALL define BT task invalidation semantics so consumers observe invalidations only after the related durable task-state transition is available through storage or runtime projection contracts.

#### Scenario: Consumer refreshes after invalidation
- **WHEN** a subscriber receives a BT task invalidation event for a completed mutation
- **THEN** a subsequent read through the approved task projection path can observe the persisted state associated with that invalidation

### Requirement: Cache invalidation bus SHALL separate invalidation from UI refresh
The cache invalidation bus SHALL provide BT task invalidation event semantics without directly refreshing UI, polling adapters, replaying torrent-engine commands, mutating storage, or invoking virtual stream, piece scheduler, timeline overlay, diagnostics, network, or native-player behavior.

#### Scenario: Task detail cache is stale
- **WHEN** BT task metadata, lifecycle, file selection, transfer snapshot, or latest event state changes
- **THEN** the bus publishes invalidation payloads for interested consumers while each consumer owns its own refresh or cache update behavior

### Requirement: Cache invalidation bus SHALL remain extensible for later BT slices
The cache invalidation bus SHALL allow later virtual media stream, piece priority scheduler, and timeline overlay slices to subscribe to or extend BT task invalidation payloads without requiring Step 18 runtime to implement range serving, priority planning, or overlay rendering.

#### Scenario: Later Phase 4 consumer depends on task state
- **WHEN** a later virtual stream, scheduler, or timeline component needs to react to BT task metadata or file-selection changes
- **THEN** it can consume Step 18 BT task invalidation payloads or define additional events without adding point-to-point calls back into the BT task runtime

