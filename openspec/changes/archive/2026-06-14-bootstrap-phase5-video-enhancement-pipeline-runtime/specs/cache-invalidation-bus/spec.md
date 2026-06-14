## ADDED Requirements

### Requirement: Cache invalidation bus SHALL preserve video enhancement runtime post-mutation ordering
Cache invalidation bus SHALL define Step 22 video enhancement invalidation semantics so consumers observe profile, capability, and pipeline state invalidations only after related state is storage-visible through enhancement profile storage or runtime projection contracts.

#### Scenario: Consumer refreshes enhancement state
- **WHEN** a subscriber receives an enhancement profile, capability, or pipeline state invalidation from the Step 22 runtime
- **THEN** a subsequent read through approved enhancement storage or runtime projection paths can observe the state associated with that invalidation

### Requirement: Cache invalidation bus SHALL keep video enhancement runtime events payload-only
Video enhancement invalidation payloads SHALL carry profile, scope, support, state, and failure identifiers only, not UI refresh logic, renderer commands, shader compilation commands, AVSyncGuard policy actions, diagnostics behavior, or native playback control.

#### Scenario: Pipeline state change event is published
- **WHEN** enhancement runtime records an applied, rejected, disabled, evaluated, or degraded state
- **THEN** the bus publishes typed payload data while each consumer owns its own refresh behavior
