## ADDED Requirements

### Requirement: Video enhancement mutations SHALL publish invalidation events
The system SHALL publish explicit invalidation events when video enhancement profiles change, capability evaluation changes, or pipeline state transitions occur.

#### Scenario: Enhancement capability is reevaluated
- **WHEN** adapter capabilities or active profile selection cause enhancement support to change
- **THEN** a video enhancement invalidation event is published so playback surfaces and future diagnostics consumers can refresh derived state without direct cross-module mutation
