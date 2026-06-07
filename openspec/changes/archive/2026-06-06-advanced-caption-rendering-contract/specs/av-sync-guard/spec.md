## ADDED Requirements

### Requirement: AVSyncGuard SHALL expose advanced caption degradation as a declarative decision
The system SHALL keep `disableAdvancedCaptions` as an ordered AV sync degradation decision that advanced caption contracts can consume without AVSyncGuard directly mutating caption renderer state.

#### Scenario: AV sync requests caption degradation
- **WHEN** sustained drift policy selects `disableAdvancedCaptions`
- **THEN** AVSyncGuard emits a declarative degradation decision for advanced caption contracts to persist or evaluate without invoking a concrete renderer
