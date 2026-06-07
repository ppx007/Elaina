# av-sync-guard Specification

## Purpose
TBD - created by archiving change bootstrap-advanced-playback-core. Update Purpose after archive.
## Requirements
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

### Requirement: AVSyncGuard SHALL use durable policy and state contracts
AVSyncGuard SHALL back drift thresholds, sample windows, health transitions, and degradation decisions with durable policy and state contracts that can be evaluated and restored without concrete renderer dependencies.

#### Scenario: Bootstrap guard interface is refined
- **WHEN** the Step 23 AV sync guard contract is implemented
- **THEN** one-shot drift samples are evaluated through storage-safe policy/state records and typed outcomes rather than concrete MPV timing properties

### Requirement: AVSyncGuard SHALL separate degradation decisions from adapter execution
AVSyncGuard SHALL emit deterministic degradation decisions as contract data while leaving concrete enhancement, caption, fallback, or renderer mutations to future adapter implementations.

#### Scenario: Red-line drift requests degradation
- **WHEN** sustained A/V drift exceeds the active red-line policy
- **THEN** the guard selects the next ordered degradation action without directly invoking VideoEnhancementPipeline, caption rendering, VLC fallback, diagnostics center, or platform renderer code

### Requirement: AVSyncGuard SHALL expose advanced caption degradation as a declarative decision
The system SHALL keep `disableAdvancedCaptions` as an ordered AV sync degradation decision that advanced caption contracts can consume without AVSyncGuard directly mutating caption renderer state.

#### Scenario: AV sync requests caption degradation
- **WHEN** sustained drift policy selects `disableAdvancedCaptions`
- **THEN** AVSyncGuard emits a declarative degradation decision for advanced caption contracts to persist or evaluate without invoking a concrete renderer

