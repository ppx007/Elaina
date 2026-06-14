## ADDED Requirements

### Requirement: Storage foundation SHALL persist video enhancement runtime replay state
Local storage foundation SHALL provide enough video enhancement profile and pipeline state to distinguish disabled, evaluated, applied, rejected, degraded, active-profile, budget-pressure, and degradation-target runtime projections after restart.

#### Scenario: Enhancement runtime restarts after degradation
- **WHEN** video enhancement runtime starts with persisted active profile and latest degraded pipeline state
- **THEN** it can replay the active profile, state kind, budget pressure, and candidate degradation target without reading renderer, shader, native plugin, diagnostics, or UI state

### Requirement: Video enhancement runtime storage boundaries MUST remain contract-only
Video enhancement runtime SHALL access persisted enhancement profiles, active profile selection, and latest pipeline state through Storage contracts and SHALL NOT bypass repository/storage boundaries or depend on concrete database, shader file, renderer, native plugin, or platform storage APIs.

#### Scenario: Runtime persists applied profile
- **WHEN** the runtime accepts a supported enhancement profile application
- **THEN** it writes active profile and latest pipeline state through `EnhancementProfileStore` before exposing replayable state
