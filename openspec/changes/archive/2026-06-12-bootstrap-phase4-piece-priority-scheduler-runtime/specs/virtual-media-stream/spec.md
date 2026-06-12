## ADDED Requirements

### Requirement: Virtual media stream SHALL provide scheduler-safe stream projections
The virtual media stream capability SHALL provide scheduler-safe stream descriptors, lifecycle state, file binding, media length, and buffered range snapshots as immutable data inputs for Step 20 planning.

#### Scenario: Scheduler evaluates a virtual stream
- **WHEN** the scheduler plans for a virtual stream
- **THEN** it reads descriptor and buffered range projections without mutating stream lifecycle or serving bytes

### Requirement: Virtual media stream SHALL separate scheduler planning from range availability
The virtual media stream capability SHALL allow scheduler planning to consume buffered ranges while keeping range availability, range failures, and byte delivery owned by virtual stream contracts and adapter boundaries.

#### Scenario: Scheduler sees buffered ranges
- **WHEN** buffered ranges already cover a piece fully
- **THEN** scheduler planning can avoid that piece without modifying buffered range records
