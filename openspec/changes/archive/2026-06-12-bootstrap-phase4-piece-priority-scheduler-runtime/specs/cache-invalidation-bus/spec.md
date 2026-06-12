## ADDED Requirements

### Requirement: Cache invalidation bus SHALL publish scheduler runtime invalidations
The cache invalidation bus SHALL carry correlated invalidation events for Step 20 scheduler profile changes, plan generation, plan application, plan rejection, and unavailable application outcomes that affect scheduler projections and later timeline read models.

#### Scenario: Scheduler plan is generated
- **WHEN** scheduler runtime persists a generated plan and ordered rules
- **THEN** it publishes or requests invalidation with task id, stream id, plan id, profile id, mutation kind, and occurred-at metadata

### Requirement: Cache invalidation bus SHALL preserve scheduler post-mutation ordering
The cache invalidation bus SHALL define scheduler invalidation semantics so consumers observe invalidations only after related profile, plan, rule, or application state is durable through storage or runtime projection contracts.

#### Scenario: Consumer refreshes scheduler projection
- **WHEN** a subscriber receives a scheduler plan-generated invalidation
- **THEN** a subsequent read through approved scheduler projection paths can observe the persisted plan and rules associated with that invalidation

### Requirement: Cache invalidation bus SHALL keep scheduler invalidation payload-only
The cache invalidation bus SHALL provide scheduler invalidation payloads without directly applying priorities, opening streams, serving bytes, refreshing UI, polling torrent engines, composing timeline overlays, mutating storage, invoking diagnostics, or controlling native playback.

#### Scenario: Plan application fails
- **WHEN** scheduler runtime records a rejected or unavailable application outcome
- **THEN** the bus publishes a typed payload while each consumer owns its own refresh or cache update behavior
