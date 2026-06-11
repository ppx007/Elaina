## ADDED Requirements

### Requirement: Playback source handoff SHALL consume virtual stream runtime projections
The playback source handoff contract SHALL prepare playback-compatible source values from Step 19 virtual stream runtime projections or descriptors without importing BT task runtime internals, concrete byte-serving implementations, schedulers, timeline overlays, or native player bindings.

#### Scenario: Runtime projection is handed to playback
- **WHEN** playback receives a virtual stream projection for a selected BT task file
- **THEN** handoff prepares an existing playback source representation that references the virtual stream abstraction only

### Requirement: Playback source handoff MUST reject virtual stream boundary violations
The playback source handoff contract MUST reject direct torrent engine values, task-internal storage records, piece maps, scheduler plans, timeline overlay objects, sockets, file handles, and native player values as playback source inputs.

#### Scenario: Engine handle is handed to playback
- **WHEN** a caller attempts to prepare playback from a concrete torrent or byte-serving object
- **THEN** handoff returns an explicit unsupported-source failure instead of leaking the object into Playback
