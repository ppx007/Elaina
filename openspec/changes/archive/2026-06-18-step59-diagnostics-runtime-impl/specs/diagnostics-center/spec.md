## ADDED Requirements

### Requirement: Diagnostics center SHALL collect local invalidation observations
The diagnostics center SHALL provide a local collector that observes
`CacheInvalidationEvent` values and records them as redacted diagnostics events
through `DiagnosticsCenterRuntime` without importing concrete module APIs or
executing module commands.

#### Scenario: Cache invalidation is observed
- **WHEN** a local cache invalidation event is received by the diagnostics
  collector
- **THEN** the collector records a diagnostics event containing event type,
  source module, occurred-at metadata, and correlation identity through the
  runtime, while preserving read-only diagnostics behavior

#### Scenario: Collector is disposed
- **WHEN** the diagnostics collector is disposed
- **THEN** later observations are rejected through a typed collector outcome
  without recording additional diagnostics events

### Requirement: Diagnostics center SHALL build local export bundles from stored snapshots
The diagnostics center SHALL provide a local export bundle builder that resolves
a stored diagnostics snapshot into redacted stored event records and a
deterministic local payload without writing files or uploading data.

#### Scenario: Snapshot export bundle is built
- **WHEN** a stored snapshot references redacted diagnostics event records
- **THEN** the export builder returns a local bundle containing snapshot
  metadata and JSON-line event payloads derived only from diagnostics storage

### Requirement: Diagnostics runtime implementation MUST remain local and read-only
The concrete diagnostics runtime implementation MUST NOT render UI, upload
telemetry, write files, call native plugins, invoke platform channels, control
playback, mutate provider state, retry feeds, execute online rules, modify
network policy, control WebView challenges, or enqueue BT tasks.

#### Scenario: Boundary checker scans diagnostics implementation
- **WHEN** diagnostics runtime validation scans the collector and export builder
- **THEN** it finds only Foundation diagnostics, storage, and cache-invalidation
  dependencies, with no UI, native, remote telemetry, or module-control
  dependency
