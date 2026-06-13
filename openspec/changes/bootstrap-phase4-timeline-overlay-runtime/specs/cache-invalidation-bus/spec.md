## ADDED Requirements

### Requirement: Timeline overlay runtime invalidations
Cache invalidation bus SHALL support timeline overlay runtime events for profile selection, layer configuration changes, snapshot refreshes, and rejected composition.

#### Scenario: Snapshot refresh publishes invalidation
- **WHEN** timeline overlay runtime successfully composes and persists snapshot metadata
- **THEN** it SHALL publish a timeline overlay snapshot invalidation event.

### Requirement: Timeline overlay post-mutation ordering
Timeline overlay runtime invalidations SHALL be published only after related profile, layer, snapshot, or rejection state is storage-visible.

#### Scenario: Profile selection is visible before invalidation
- **WHEN** an active timeline overlay profile changes
- **THEN** consumers SHALL be able to read the new active profile after observing the invalidation.

### Requirement: Timeline overlay payload-only events
Timeline overlay invalidation payloads SHALL carry identifiers and projection metadata only, not UI refresh logic, rendering commands, playback commands, or concrete transport implementation details.

#### Scenario: Layer change event remains presentation-neutral
- **WHEN** a layer configuration invalidation is published
- **THEN** the event SHALL NOT include widget instructions, rendering commands, or playback actions.
