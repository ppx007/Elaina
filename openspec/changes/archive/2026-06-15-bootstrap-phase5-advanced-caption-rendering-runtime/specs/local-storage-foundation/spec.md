## ADDED Requirements

### Requirement: Runtime SHALL rebuild advanced caption projection from store after restart
The system SHALL ensure `AdvancedCaptionRuntimeRestartProjection` reads active profile ID, latest renderer state kind, and dual subtitle selection from the caption store without requiring in-memory evaluation state.

#### Scenario: Restart projection from seeded store
- **WHEN** a runtime is created for a scope with stored active profile and applied renderer state
- **THEN** the restart projection reports the stored active profile ID and renderer state kind

### Requirement: Runtime SHALL persist caption rendering state through deterministic renderer
The system SHALL ensure `DeterministicAdvancedCaptionRenderer` persists profile, active profile, dual subtitle selection, and renderer state records to the caption store on every operation, enabling the runtime to project stored state on restart.

#### Scenario: Rendered feature persists state
- **WHEN** the runtime delegates a successful matrix danmaku render to the deterministic renderer
- **THEN** the caption store contains the latest renderer state record with `state: applied` and the rendered feature name
