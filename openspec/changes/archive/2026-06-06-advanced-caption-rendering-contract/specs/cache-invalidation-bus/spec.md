## ADDED Requirements

### Requirement: Advanced caption mutations SHALL publish invalidation events
The system SHALL publish explicit invalidation events when advanced caption feature state, capability evaluation, renderer state, dual-subtitle selection, or degradation state changes.

#### Scenario: Dual subtitle selection changes
- **WHEN** primary or secondary subtitle selection changes for an advanced caption profile
- **THEN** an advanced caption invalidation event is published so derived playback state can refresh without direct cross-module mutation
