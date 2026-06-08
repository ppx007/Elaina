## ADDED Requirements

### Requirement: Diagnostics center contract SHALL define capability-gated local diagnostics
The system SHALL define diagnostics capability contracts for local event recording, schema registration, snapshot creation, filtering, export, retention enforcement, and redaction.

#### Scenario: Local recording unsupported
- **WHEN** a platform or build cannot support local diagnostics event recording
- **THEN** diagnostics reports an unsupported capability without blocking playback, ProviderGateway, RSS, online rule, WebView backfill, BT, cache, storage, network policy, or A/V sync flows

### Requirement: Diagnostics center contract SHALL persist redacted local event observations
The system SHALL provide deterministic diagnostics scaffolding that redacts sensitive payload keys before local persistence and before export.

#### Scenario: Event contains sensitive payload keys
- **WHEN** a diagnostics event payload contains cookie, authorization, token, session, or local secret metadata
- **THEN** diagnostics persists and exports only redacted or omitted values according to the redaction policy

### Requirement: Diagnostics center contract SHALL support deterministic query and snapshot scaffolding
The system SHALL expose deterministic diagnostics query and snapshot contracts for category, severity, time range, correlation identity, source module, event type, and capability area filters.

#### Scenario: Snapshot filters by correlation identity
- **WHEN** diagnostics creates a snapshot for a ProviderGateway failure correlation identity
- **THEN** the snapshot contains only matching redacted local events in deterministic chronological order

### Requirement: Diagnostics center contract SHALL define retention enforcement contracts
The system SHALL define bounded retention contracts using max event count, max age, latest enforcement time, purged event count, and retention outcome metadata.

#### Scenario: Retention limit is enforced
- **WHEN** stored diagnostics events exceed the configured retention policy
- **THEN** diagnostics records a retention outcome and exposes the remaining bounded local event set without requiring a background scheduler

### Requirement: Diagnostics center contract SHALL define local export descriptors
The system SHALL define export request and export outcome contracts that describe local filtered diagnostics exports with redaction metadata and without transmitting data remotely.

#### Scenario: User requests local diagnostics export
- **WHEN** a filtered diagnostics export is requested
- **THEN** the export outcome records the local export descriptor, redaction policy version, event count, and completion state without cloud upload or telemetry transmission

### Requirement: Diagnostics center contract MUST remain read-only
The system MUST NOT define diagnostics operations that start playback, pause playback, resume playback, mutate provider state, retry feeds, modify network policy, control WebView challenges, or enqueue BT tasks.

#### Scenario: Diagnostics observes BT failure
- **WHEN** diagnostics records a BT task failure event
- **THEN** diagnostics exposes the failure for inspection without creating, pausing, resuming, selecting files, or removing BT tasks
