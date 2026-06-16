# phase6-diagnostics-center-runtime Specification

## Purpose
TBD - created by archiving change bootstrap-phase6-diagnostics-center-runtime. Update Purpose after archive.
## Requirements
### Requirement: Diagnostics center runtime SHALL provide bootstrap acceptance layer
The system SHALL expose `DiagnosticsCenterRuntimeBootstrap` that composes an existing `DiagnosticsStore`, `DiagnosticsEventRegistry`, `DiagnosticsRetentionPolicy`, `DiagnosticsRedactionPolicy`, `DiagnosticsCapabilityMatrix`, and optional `CacheInvalidationBus` without accepting a clock parameter or constructing UI, native, network, telemetry, or lifecycle-control dependencies.

#### Scenario: Bootstrap creates runtime from deterministic contracts
- **WHEN** the bootstrap is constructed with diagnostics store, registry, retention policy, redaction policy, capability matrix, and optional invalidation bus
- **THEN** `createRuntime()` returns a `DiagnosticsCenterRuntime` that records and projects diagnostics through those contracts only

### Requirement: Diagnostics center runtime SHALL return typed action outcomes
The runtime SHALL return typed `DiagnosticsCenterRuntimeActionResult<T>` values for schema registration, event recording, snapshot queries, retention enforcement, local export description, capability recording, and snapshot operations, including compact failure kinds for unsupported capability, unavailable runtime, disposed runtime, missing schema, record failure, snapshot failure, retention failure, and export failure.

#### Scenario: Unsupported recording capability blocks event recording
- **WHEN** redacted event recording capability is unsupported
- **THEN** `recordEvent()` returns a typed `capabilityUnsupported` failure without persisting or publishing a diagnostics event

### Requirement: Diagnostics center runtime SHALL persist before publishing invalidation events
The runtime SHALL write schema, event, snapshot, export request, export outcome, retention, and capability records to `DiagnosticsStore` before publishing the corresponding diagnostics invalidation event through the optional cache invalidation bus.

#### Scenario: Event is recorded
- **WHEN** `recordEvent()` succeeds
- **THEN** the redacted event record is visible through storage before `DiagnosticsEventRecorded` is published

### Requirement: Diagnostics center runtime SHALL rebuild projections from storage
The runtime SHALL expose projections and restart projections that read stored schema count, event count, latest snapshot, latest export outcome, latest retention state, and capability states from `DiagnosticsStore` so restart flows can inspect local diagnostics state without replaying module behavior.

#### Scenario: Runtime restarts with stored diagnostics state
- **WHEN** a runtime starts with existing schema, event, snapshot, export, retention, and capability records
- **THEN** `snapshot()` returns a projection reflecting stored diagnostics state without invoking remote telemetry, lifecycle controls, or module mutation

### Requirement: Diagnostics center runtime MUST remain read-only and local
The runtime MUST NOT start playback, pause playback, resume playback, mutate provider state, retry feeds, execute online rules, modify network policy, control WebView challenges, enqueue BT tasks, render Flutter UI, call native/FFI/platform channels, or upload diagnostics remotely.

#### Scenario: Local export is described
- **WHEN** `describeLocalExport()` succeeds
- **THEN** the runtime records a local export descriptor and invalidation event without transmitting data outside local diagnostics contracts

