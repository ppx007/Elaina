## ADDED Requirements

### Requirement: Cache invalidation bus SHALL publish virtual stream invalidations
The cache invalidation bus SHALL carry correlated invalidation events for Step 19 virtual stream mutations that affect stream list projections, stream detail projections, buffered range projections, playback handoff readiness, and downstream scheduler/timeline read models.

#### Scenario: Virtual stream is created
- **WHEN** a selected BT file is persisted as a virtual stream descriptor
- **THEN** the runtime publishes or requests invalidation with stream id, task id, file index, mutation kind, and occurred-at metadata for consumers to refresh affected virtual stream read models

### Requirement: Cache invalidation bus SHALL preserve virtual stream post-mutation ordering
The cache invalidation bus SHALL define virtual stream invalidation semantics so consumers observe invalidations only after related stream lifecycle, buffered range, or failure state is durable through storage/runtime projections.

#### Scenario: Consumer refreshes buffered ranges
- **WHEN** a subscriber receives a range-buffered invalidation
- **THEN** a subsequent read through approved stream projection paths can observe the persisted range associated with that invalidation

### Requirement: Cache invalidation bus SHALL keep virtual stream invalidation payload-only
The cache invalidation bus SHALL provide virtual stream invalidation payloads without directly opening streams, serving bytes, refreshing UI, polling torrent engines, applying piece priorities, composing timeline overlays, mutating storage, or invoking native playback.

#### Scenario: Range failure is published
- **WHEN** virtual stream runtime records a range failure
- **THEN** the bus publishes a typed payload while each consumer owns its own refresh or cache update behavior
