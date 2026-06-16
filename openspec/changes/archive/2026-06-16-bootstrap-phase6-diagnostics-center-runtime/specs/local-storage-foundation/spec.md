## ADDED Requirements

### Requirement: Local storage foundation SHALL replay diagnostics runtime state
The local storage foundation SHALL support diagnostics runtime restart replay through existing diagnostics storage records for schemas, events, snapshots, export outcomes, retention state, and capability states.

#### Scenario: Diagnostics runtime projection reads stored state
- **WHEN** diagnostics runtime starts after previous diagnostics records were stored
- **THEN** its restart projection reads those records from `DiagnosticsStore` without requiring module re-execution
