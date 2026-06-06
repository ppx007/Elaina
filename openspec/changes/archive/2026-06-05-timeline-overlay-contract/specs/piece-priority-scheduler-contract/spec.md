## ADDED Requirements

### Requirement: Piece priority scheduler contract SHALL provide timeline-safe priority projections
The system SHALL expose generated plan summaries, priority rule ranges, active profile metadata, and latest application outcomes in a form that timeline overlay contracts can project onto playback timelines without controlling scheduler planning or application.

#### Scenario: Timeline consumes scheduler plan state
- **WHEN** a timeline overlay snapshot includes current playback and seek priority windows
- **THEN** it reads scheduler plan/application state through contract-safe snapshots without regenerating plans, applying priorities, or importing concrete download-engine objects
