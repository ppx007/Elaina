## ADDED Requirements

### Requirement: Timeline overlay mutations SHALL publish invalidation events
The system SHALL publish explicit invalidation events when timeline overlay snapshots refresh, layer configuration changes, or overlay composition is rejected because required read-model inputs are unavailable.

#### Scenario: Timeline layer configuration changes
- **WHEN** timeline overlay layer visibility, ordering, or active overlay profile changes
- **THEN** a timeline overlay invalidation event is published so playback surfaces and later diagnostics consumers can refresh derived state without direct cross-module mutation
