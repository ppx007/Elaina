## ADDED Requirements

### Requirement: AV sync guard mutations SHALL publish invalidation events
The system SHALL publish explicit invalidation events when AV sync samples are ingested, guard health transitions, degradation decisions are recorded, or guard state recovers.

#### Scenario: AV sync health transitions
- **WHEN** sustained samples move guard health from target to warning, warning to degraded, or degraded toward target
- **THEN** an AV sync invalidation event is published so playback surfaces and future diagnostics consumers can refresh derived state without direct cross-module mutation
