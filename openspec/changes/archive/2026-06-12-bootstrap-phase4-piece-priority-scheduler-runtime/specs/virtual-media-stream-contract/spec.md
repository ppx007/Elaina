## ADDED Requirements

### Requirement: Virtual media stream contract SHALL provide scheduler input snapshots
The virtual media stream contract SHALL expose descriptor, lifecycle, length, file binding, and buffered range snapshots that Step 20 scheduler planning can consume without owning byte serving or stream lifecycle mutation.

#### Scenario: Scheduler requests stream range state
- **WHEN** a scheduler plan request references a virtual stream id
- **THEN** the contract can provide stream identity, task/file binding, length, lifecycle, and buffered ranges through approved storage-backed projections

### Requirement: Virtual media stream contract SHALL protect stream boundaries from scheduler mutation
The virtual media stream contract MUST prevent scheduler runtime code from closing streams, failing streams, recording range availability, opening byte streams, or invoking concrete byte-serving implementations.

#### Scenario: Scheduler generates a plan
- **WHEN** Step 20 runtime generates priority rules
- **THEN** it reads stream state only and does not mutate stream lifecycle or range availability
