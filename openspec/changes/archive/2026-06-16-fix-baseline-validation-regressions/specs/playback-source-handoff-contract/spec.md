## MODIFIED Requirements

### Requirement: Playback source handoff SHALL prepare virtual stream playback sources
The playback source handoff contract SHALL accept playback-owned virtual stream
descriptors or equivalent virtual stream source values and prepare playback
sources without importing Streaming runtime, BT task core, download engine,
piece scheduler, timeline overlay, or concrete byte-serving implementation
dependencies.

#### Scenario: Virtual stream descriptor is prepared
- **WHEN** playback is handed a playback-owned virtual stream descriptor for a selected virtual stream
- **THEN** the handoff returns a playback-compatible source that references the virtual stream abstraction without requiring provider metadata, storage implementation details, network clients, concrete streaming engines, UI widgets, or native player bindings

### Requirement: Playback source handoff SHALL consume virtual stream runtime projections
The playback source handoff contract SHALL prepare playback-compatible source
values from playback-owned virtual stream descriptors derived at caller
boundaries from runtime projections, without importing Step 19 runtime snapshot
types, BT task runtime internals, concrete byte-serving implementations,
schedulers, timeline overlays, or native player bindings.

#### Scenario: Runtime projection is handed to playback
- **WHEN** a caller receives a virtual stream runtime projection for a selected BT task file
- **THEN** the caller maps it to a playback-owned descriptor before invoking handoff, and handoff prepares an existing playback source representation that references only the virtual stream abstraction
