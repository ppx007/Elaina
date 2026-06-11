## ADDED Requirements

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
