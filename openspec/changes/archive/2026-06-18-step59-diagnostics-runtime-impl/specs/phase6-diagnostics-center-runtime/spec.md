## ADDED Requirements

### Requirement: Diagnostics runtime SHALL support local collector implementation
The diagnostics center runtime SHALL support a local collector that registers a
diagnostics schema, records cache-invalidation observations, and reports typed
collector outcomes without bypassing existing runtime capability gates.

#### Scenario: Collector starts and records an observation
- **WHEN** the local collector starts and observes a cache invalidation event
- **THEN** it registers the collector schema if needed and records the
  observation through `DiagnosticsCenterRuntime.recordEvent()`

### Requirement: Diagnostics runtime SHALL support local export payload construction
The diagnostics runtime implementation SHALL support deterministic local export
bundle construction from `DiagnosticsStore` records without using remote
transport, filesystem writes, or UI surfaces.

#### Scenario: Export bundle uses stored events
- **WHEN** an export bundle is requested for a snapshot ID
- **THEN** the builder reads the stored snapshot and matching event records from
  diagnostics storage and returns redacted local payload data
