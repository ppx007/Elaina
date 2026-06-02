## ADDED Requirements

### Requirement: AVSyncGuard SHALL monitor playback sync metrics
The system SHALL define `AVSyncGuard` contracts for A/V drift, dropped frames, render delay, and current enhancement pressure.

#### Scenario: Sync metrics are sampled
- **WHEN** playback emits sync and frame timing data
- **THEN** `AVSyncGuard` receives normalized metrics independent of a concrete player adapter

### Requirement: AVSyncGuard MUST trigger degradation above sync red line
The system MUST define degradation decisions when A/V drift exceeds 120ms, while preserving under 40ms as the target operating range.

#### Scenario: Drift exceeds red line
- **WHEN** measured A/V drift is greater than 120ms
- **THEN** `AVSyncGuard` emits a degradation decision such as lowering enhancement intensity or disabling advanced rendering

### Requirement: AVSyncGuard SHALL keep degradation deterministic
The system SHALL define an ordered degradation path so adapters do not apply conflicting fallback behavior independently.

#### Scenario: Multiple degradation options exist
- **WHEN** both enhancement reduction and feature disablement are possible
- **THEN** `AVSyncGuard` selects a deterministic degradation step from the active policy
