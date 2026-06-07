## ADDED Requirements

### Requirement: Fallback adapter mutations SHALL publish invalidation events
The system SHALL publish explicit invalidation events when fallback adapters register or deregister, fallback capabilities are reevaluated, fallback selection changes, or fallback strategy state changes.

#### Scenario: Fallback selection changes
- **WHEN** a fallback adapter is selected for a playback scope
- **THEN** a fallback invalidation event is published so derived playback capability state can refresh without direct cross-module mutation
