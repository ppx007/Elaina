## ADDED Requirements

### Requirement: Playback source handoff SHALL prepare virtual stream playback sources
The playback source handoff contract SHALL accept engine-neutral virtual media stream descriptors or equivalent virtual stream source values and prepare playback sources without importing BT task core, download engine, piece scheduler, timeline overlay, or concrete byte-serving implementation dependencies.

#### Scenario: Virtual stream descriptor is prepared
- **WHEN** playback is handed a virtual stream descriptor for a selected BT task file
- **THEN** the handoff returns a playback-compatible source that references the virtual stream abstraction without requiring provider metadata, storage implementation details, network clients, concrete streaming engines, UI widgets, or native player bindings

### Requirement: Playback source handoff MUST reject direct BT engine handoff
The playback source handoff contract MUST NOT accept concrete BT task, torrent engine, piece map, scheduler, or timeline objects as playback source inputs.

#### Scenario: Concrete engine value is prepared
- **WHEN** a caller attempts to hand off a concrete BT engine value or task-internal object
- **THEN** the handoff returns an explicit unsupported-source failure instead of leaking engine details into Playback
