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

### Requirement: Phase 4 piece priority scheduler runtime SHALL remain Step 20 scoped
The system MUST keep timeline overlay composition, UI task screens, concrete
torrent engines, concrete range servers, filesystem byte reads, native
playback bindings, RSS automation, online-rule runtime, diagnostics center,
network implementation, storage migrations, and Phase 5 playback features
outside the neutral scheduler runtime. Step 54 MAY add a concrete
Streaming-layer applier, but neutral scheduler runtime files MUST remain free
of concrete engine imports.

#### Scenario: Boundary validation runs
- **WHEN** Step 54 scheduler validation scans scheduler runtime files
- **THEN** forbidden downstream, concrete IO, UI, diagnostics, network,
  storage migration, native-player, and concrete torrent-engine dependencies
  fail validation outside the approved concrete Streaming adapter surface
