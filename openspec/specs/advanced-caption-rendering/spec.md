# advanced-caption-rendering Specification

## Purpose
TBD - created by archiving change bootstrap-advanced-playback-core. Update Purpose after archive.
## Requirements
### Requirement: Advanced caption rendering SHALL be feature gated
The system SHALL define capability-gated contracts for Matrix4 danmaku, dual subtitles, PGS, and ASS enhancement without replacing basic subtitle or danmaku foundations.

#### Scenario: Advanced caption feature is unavailable
- **WHEN** the active adapter or platform cannot support an advanced caption feature
- **THEN** UI does not present the feature as executable

### Requirement: Advanced caption rendering SHALL preserve basic parser boundaries
The system SHALL keep advanced rendering contracts separate from basic subtitle parsing and danmaku event contracts.

#### Scenario: ASS enhancement is enabled
- **WHEN** ASS enhancement rendering is requested
- **THEN** the request is represented as a rendering capability rather than a mutation of basic subtitle parser contracts

### Requirement: Dual subtitle contracts SHALL expose ordered tracks
The system SHALL define dual subtitle contracts that preserve primary and secondary subtitle order and capability state.

#### Scenario: Two subtitle tracks are selected
- **WHEN** primary and secondary subtitle tracks are active
- **THEN** advanced caption rendering receives an ordered dual-subtitle request

### Requirement: Advanced caption rendering SHALL use durable feature state
The system SHALL back Matrix4 danmaku, dual subtitles, PGS subtitle rendering, and ASS subtitle enhancement with durable feature state and typed evaluation outcomes.

#### Scenario: Advanced caption feature is evaluated
- **WHEN** an advanced caption render request is created
- **THEN** the renderer contract evaluates active feature state and capability status before exposing the request as executable

### Requirement: Advanced caption rendering SHALL separate advanced requests from basic foundations
The system SHALL represent Matrix4 danmaku transforms, ordered dual subtitles, PGS rendering intent, and ASS enhancement intent as advanced rendering requests without mutating basic subtitle parser or danmaku event contracts.

#### Scenario: ASS enhancement request is prepared
- **WHEN** ASS enhancement rendering is requested
- **THEN** the request is represented as an advanced rendering intent while basic ASS parser output remains unchanged

### Requirement: Advanced caption rendering runtime SHALL project evaluation and rendering state
The system SHALL expose runtime projection combining in-memory latest evaluation report, stored active profile, latest renderer state, and dual subtitle selection for snapshot visibility.

#### Scenario: Runtime projects latest evaluation report
- **WHEN** `evaluate()` completes successfully on a supported scope
- **THEN** `snapshot()` projection includes the latest evaluation report with profile and capability results

### Requirement: Advanced caption rendering runtime SHALL replay active profile and state on restart
The system SHALL provide restart projection reading active profile ID, latest renderer state kind, and degradation reason exclusively from the caption store.

#### Scenario: Restart projection after degradation
- **WHEN** a scope has stored renderer state `degraded` with degradation reason `AV sync drift exceeded threshold`
- **THEN** restart projection reports `latestRendererState: degraded` and `latestDegradationReason: AV sync drift exceeded threshold`

### Requirement: Advanced subtitle intent SHALL be mappable to concrete MPV plans
Advanced caption rendering SHALL remain declarative while allowing a
Playback-owned concrete MPV bridge to translate ordered dual subtitles, ASS
enhancement, and PGS subtitle intent into MPV command plans at the adapter
boundary.

#### Scenario: Advanced subtitle request crosses into Playback binding
- **WHEN** an advanced subtitle request reaches the concrete MPV bridge
- **THEN** subtitle source identity and ordered role are mapped by
  Playback-owned code into MPV command data without changing UI-facing profile
  contracts, basic subtitle parser contracts, or deterministic runtime storage

#### Scenario: Matrix4 danmaku is requested
- **WHEN** Matrix4 danmaku rendering reaches the Step 57 concrete subtitle
  bridge
- **THEN** the bridge returns typed unsupported behavior rather than pretending
  to implement a Flutter/GPU danmaku renderer

