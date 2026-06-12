## ADDED Requirements

### Requirement: Storage foundation SHALL persist scheduler runtime state atomically
The storage foundation SHALL provide piece priority scheduler storage contracts that persist active profile selection, generated priority plans, ordered plan rules, latest application outcomes, failure metadata, and timestamps as coherent Step 20 runtime transitions.

#### Scenario: Priority plan is generated
- **WHEN** scheduler runtime generates a plan and its ordered rules
- **THEN** storage persists the profile, plan, and rules before the runtime reports the plan as replayable or publishes invalidation

### Requirement: Storage foundation SHALL support scheduler restart reconstruction
The storage foundation SHALL expose enough persisted scheduler state for runtime bootstrap code to reconstruct active profile state, latest plan projections, rule projections, latest application outcome, unavailable-input state, and rejected application state after restart.

#### Scenario: Runtime boots after process restart
- **WHEN** persisted scheduler records exist
- **THEN** the runtime can rebuild scheduler projections without querying a concrete torrent engine or native priority adapter

### Requirement: Storage foundation MUST enforce scheduler storage boundaries
The storage foundation MUST prevent UI, Playback, Provider, concrete torrent engines, virtual stream byte servers, timeline overlays, diagnostics consumers, and native player adapters from bypassing approved scheduler storage or runtime projection contracts.

#### Scenario: Derived consumer needs scheduler state
- **WHEN** a derived consumer needs profile, plan, rule, or application state
- **THEN** it reads through scheduler storage or runtime projection contracts rather than direct database, filesystem, engine session, or module-owned cache access
