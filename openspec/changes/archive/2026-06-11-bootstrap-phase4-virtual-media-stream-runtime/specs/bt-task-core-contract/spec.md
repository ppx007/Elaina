## ADDED Requirements

### Requirement: BT task core contract SHALL preserve selected file metadata for virtual stream bootstrap
The BT task core contract SHALL persist selected file identity, length, offset, selection state, and optional media metadata in a form that virtual media stream contracts can consume deterministically.

#### Scenario: File selection is replayed after restart
- **WHEN** the virtual media stream runtime starts after file selection was persisted
- **THEN** it can determine which files are streamable from BT task storage contracts without querying the download engine

### Requirement: BT task core contract MUST NOT expose engine internals to virtual stream runtime
The BT task core contract MUST keep torrent handles, piece managers, engine sessions, FFI objects, socket servers, and native player values out of virtual stream runtime inputs.

#### Scenario: Stream bootstrap reads task metadata
- **WHEN** Step 19 runtime bootstraps a virtual stream from Step 18 task state
- **THEN** it receives engine-neutral task and file records only
