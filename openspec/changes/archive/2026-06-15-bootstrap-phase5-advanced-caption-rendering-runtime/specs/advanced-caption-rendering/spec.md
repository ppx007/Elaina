## ADDED Requirements

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
