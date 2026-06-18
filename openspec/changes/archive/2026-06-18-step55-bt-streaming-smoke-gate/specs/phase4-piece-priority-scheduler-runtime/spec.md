## MODIFIED Requirements

### Requirement: Phase 4 piece priority scheduler runtime SHALL keep plan application adapter-neutral
The system SHALL treat plan application as an adapter boundary that records
accepted, rejected, or unavailable outcomes and MUST NOT directly depend on
libtorrent, FFI, sockets, HTTP servers, file handles, MPV, VLC, media-kit,
platform channels, native players, or UI controls. Concrete Streaming adapters
MAY supply a `PiecePriorityPlanApplier` implementation to the runtime.

#### Scenario: Plan applier is unavailable
- **WHEN** a generated priority plan is applied without a configured adapter
  boundary
- **THEN** the runtime records an unavailable application outcome and publishes
  scheduler invalidation without invoking concrete engine APIs

#### Scenario: Configured applier applies a plan
- **WHEN** a generated priority plan is applied with a configured concrete
  Streaming applier
- **THEN** the runtime invokes only the `PiecePriorityPlanApplier` boundary and
  persists the normalized accepted or rejected outcome for restart projection

#### Scenario: Smoke gate applies a BT streaming priority plan
- **WHEN** Step 55 generates a priority plan for the virtual stream and applies
  it through the concrete libtorrent Streaming applier
- **THEN** the scheduler persists an accepted application outcome and the
  concrete backend receives only the supported file-priority application call
