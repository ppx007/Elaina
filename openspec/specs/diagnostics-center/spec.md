# diagnostics-center Specification

## Purpose
TBD - created by archiving change bootstrap-automation-extension-core. Update Purpose after archive.
## Requirements
### Requirement: Diagnostics center SHALL define a typed local event registry
The system SHALL define a diagnostics event registry with event identity, category, severity, version, schema, timestamp, correlation identity, source module, and structured payload metadata.

#### Scenario: Module registers diagnostic event type
- **WHEN** a module introduces a diagnostics event
- **THEN** it registers the event schema and category before emitting instances of that event

### Requirement: Diagnostics center SHALL collect local structured snapshots
The system SHALL collect local structured event snapshots for playback, BT, provider, RSS, online rule, network policy, cache, storage, and A/V sync flows without requiring cloud upload.

#### Scenario: Provider request fails
- **WHEN** ProviderGateway reports a normalized provider failure
- **THEN** diagnostics center can record a structured local snapshot with correlation identity and failure classification

### Requirement: Diagnostics center SHALL support filtering and export contracts
The system SHALL define contracts for filtering diagnostics by category, severity, time range, correlation identity, source module, and capability area, and SHALL define local export semantics.

#### Scenario: User exports diagnostics
- **WHEN** a diagnostics export is requested
- **THEN** the export contains filtered local structured events with sensitive session artifacts omitted or redacted

### Requirement: Diagnostics center MUST remain read-only
The diagnostics center MUST NOT own module lifecycle controls, mutate provider state, start or stop playback, change network policy, or enqueue BT tasks.

#### Scenario: Diagnostic event indicates RSS automation failure
- **WHEN** diagnostics records an RSS automation failure
- **THEN** diagnostics exposes the failure for inspection without retrying feeds or mutating automation policy

### Requirement: Diagnostics center SHALL define retention and redaction boundaries
The system SHALL define retention, truncation, and redaction contracts for diagnostics snapshots, including session artifact redaction and bounded local storage.

#### Scenario: Snapshot includes session-adjacent metadata
- **WHEN** a diagnostic payload contains cookie names, authorization headers, or provider tokens
- **THEN** diagnostics redacts or omits sensitive values before persistence or export

### Requirement: Diagnostics center SHALL expose capability status
The diagnostics center SHALL expose capability state for local event recording, schema registration, snapshot creation, query filtering, local export, retention enforcement, and redaction.

#### Scenario: Export capability unavailable
- **WHEN** local diagnostics export is unavailable on a platform or build
- **THEN** diagnostics reports the limitation through typed capability state rather than attempting remote telemetry, cloud upload, or fallback lifecycle actions

### Requirement: Diagnostics center SHALL thread correlation identity across extension flows
The diagnostics center SHALL preserve correlation identity across ProviderGateway failures, RSS automation evaluations, online rule evaluations, WebView session backfill attempts, network policy decisions, cache events, storage events, playback events, BT events, and A/V sync events.

#### Scenario: Provider request is blocked by network policy
- **WHEN** ProviderGateway reports a provider-scoped request blocked by network policy
- **THEN** diagnostics can record a local structured event with the provider failure classification, network policy failure kind, and shared correlation identity

### Requirement: Diagnostics center SHALL persist only redacted snapshots and exports
The diagnostics center SHALL apply redaction policy before persistence and export for sensitive session, authorization, cookie, token, filesystem, and provider-secret payload fields.

#### Scenario: Snapshot contains session-adjacent metadata
- **WHEN** a diagnostics snapshot includes WebView backfill artifact metadata or provider authorization context
- **THEN** the stored snapshot and local export omit or redact sensitive values while preserving safe identifiers and correlation metadata

### Requirement: Diagnostics center SHALL expose runtime acceptance projection
The diagnostics center SHALL expose a runtime acceptance projection that summarizes local schema, event, snapshot, export, retention, and capability state from deterministic storage while preserving read-only diagnostics semantics.

#### Scenario: Runtime projection summarizes local diagnostics
- **WHEN** diagnostics runtime snapshot is requested after local events have been recorded
- **THEN** the projection reports stored local diagnostics state without mutating playback, provider, RSS, online rule, WebView, BT, network policy, or UI state

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

