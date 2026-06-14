## ADDED Requirements

### Requirement: Video enhancement pipeline SHALL expose runtime bootstrap projections
The video enhancement pipeline SHALL support a runtime-facing projection that reports active profile selection, latest pipeline state, support status, render budget pressure, and degradation target without requiring concrete renderer or shader implementation details.

#### Scenario: Runtime reads enhancement projection
- **WHEN** the Step 22 runtime asks for current enhancement state for a playback scope
- **THEN** the pipeline projection exposes declarative profile and budget-pressure data while leaving concrete rendering and AV sync policy outside the pipeline

### Requirement: Video enhancement pipeline SHALL normalize runtime action outcomes
The video enhancement pipeline SHALL allow runtime callers to distinguish successful, unsupported, rejected, unavailable, and disposed action results for evaluation, application, disable, and degradation requests.

#### Scenario: Runtime applies unsupported profile
- **WHEN** runtime application receives a profile whose requested enhancement components exceed active capabilities
- **THEN** the pipeline reports a typed unsupported or rejected outcome instead of throwing native adapter exceptions or applying concrete renderer state

### Requirement: Video enhancement pipeline SHALL hand off budget pressure without owning AV sync policy
The video enhancement pipeline SHALL expose render budget pressure and candidate degradation target as data that future AVSyncGuard policy can consume, but it MUST NOT decide drift thresholds, guard health transitions, or ordered degradation actions.

#### Scenario: Degradation target is projected
- **WHEN** a degradation request records that the current profile exceeds frame budget
- **THEN** the pipeline projection includes the candidate lower profile or disabled target without selecting AVSyncGuard health state or drift policy
