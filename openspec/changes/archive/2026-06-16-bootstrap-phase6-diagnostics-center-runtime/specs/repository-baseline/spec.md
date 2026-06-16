## ADDED Requirements

### Requirement: Repository baseline SHALL include Step 30 diagnostics center runtime
The repository baseline SHALL record Step 30 as the diagnostics center runtime acceptance layer that closes Phase 6 by exposing local read-only diagnostics runtime projections, typed outcomes, retention/export descriptors, redaction, and capability gates.

#### Scenario: Step 30 remains scoped
- **WHEN** Step 30 diagnostics runtime is implemented
- **THEN** it remains local and read-only, with no UI, playback control, provider mutation, network policy mutation, BT enqueue, native, FFI, platform channel, remote telemetry, or cloud upload behavior
