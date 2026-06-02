## ADDED Requirements

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
