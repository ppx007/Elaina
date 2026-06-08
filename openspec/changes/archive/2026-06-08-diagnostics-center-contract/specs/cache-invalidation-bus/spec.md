## ADDED Requirements

### Requirement: Diagnostics mutations SHALL publish invalidation events
The system SHALL publish explicit invalidation events when diagnostics schemas are registered, diagnostics events are recorded, snapshots are created, retention is enforced, export requests or outcomes are recorded, or diagnostics capability state changes.

#### Scenario: Diagnostics event is recorded
- **WHEN** diagnostics records a redacted local event
- **THEN** a diagnostics invalidation event is published with event type, category, severity, source module, and correlation identity metadata

#### Scenario: Diagnostics retention runs
- **WHEN** diagnostics retention enforcement purges or bounds local events
- **THEN** a diagnostics retention invalidation event is published so derived diagnostics views can refresh without direct storage mutation
