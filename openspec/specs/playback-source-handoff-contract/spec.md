# playback-source-handoff-contract Specification

## Purpose
Define the deterministic local-media handoff that prepares selected media values into playback sources without introducing provider, storage, streaming, network, or native player dependencies.
## Requirements
### Requirement: Playback source handoff SHALL prepare local media into playback sources
The playback source handoff contract SHALL convert selected local media identities or scan candidates into `PlaybackSource` values that can be opened by the playback controller.

#### Scenario: Local media identity is prepared
- **WHEN** a selected local media identity has a file URI
- **THEN** the handoff returns a local file playback source without requiring provider metadata, storage-backed library state, gateway traffic, streaming engines, network clients, or native player bindings

### Requirement: Playback source handoff SHALL report unsupported inputs explicitly
The playback source handoff contract SHALL return an explicit failure result for unsupported URI schemes, missing source data, or selections that cannot be represented as a playback source.

#### Scenario: Unsupported source scheme is prepared
- **WHEN** a selected media identity uses a URI scheme outside the handoff's supported source categories
- **THEN** the handoff returns a normalized failure result instead of throwing a concrete platform, provider, storage, streaming, gateway, network, or native player exception

### Requirement: Playback source handoff SHALL reuse existing PlaybackSource contracts
The playback source handoff contract SHALL produce existing `PlaybackSource` values rather than defining parallel UI-local, media-library-local, provider-local, or adapter-local playback source models.

#### Scenario: Controller opens prepared source
- **WHEN** the playback controller receives a source produced by the handoff contract
- **THEN** it opens the source through the existing controller and player adapter contracts

### Requirement: Playback source handoff MUST preserve layer isolation
The handoff contract MUST NOT require Provider, Gateway, Storage, Streaming, Network, MPV, VLC, libmpv, media-kit, platform channel, diagnostics, danmaku, Anime4K, RSS, Bangumi, Dandanplay, or online rule runtime dependencies.

#### Scenario: Handoff imports are checked
- **WHEN** automation scans the handoff contract and playback runtime checks
- **THEN** no dependency on provider implementations, gateway implementations, storage implementations, streaming implementations, network implementations, native player bindings, Flutter widgets, or later-phase ACG integrations is required

### Requirement: Playback source handoff SHALL remain deterministic
The first playback source handoff SHALL be deterministic and synchronous with respect to already-selected local media values, and MUST NOT perform filesystem scans, database lookups, provider lookups, network requests, or media probing.

#### Scenario: Handoff test runs offline
- **WHEN** handoff tests prepare a local media identity or scan candidate
- **THEN** validation completes without filesystem traversal, database access, provider calls, gateway calls, network calls, or native playback startup

### Requirement: Scanner-produced file candidates SHALL preserve playback handoff invariants
The playback source handoff contract SHALL accept scanner-produced `MediaScanCandidate` values only when they preserve the handoff invariants required for local file playback preparation: non-empty file URI, non-empty basename, non-negative size, and no scanner-owned `PlaybackSource` construction.

#### Scenario: Scanner candidate is prepared for playback
- **WHEN** a local media scanner produces a candidate whose identity has a non-empty file URI and valid local media fields
- **THEN** the playback source handoff can prepare that candidate into an existing local file playback source without provider metadata, storage-backed library state, gateway traffic, network clients, streaming engines, UI widgets, or native player bindings

#### Scenario: Scanner candidate is not handoff-safe
- **WHEN** a local media scanner produces or receives a candidate with missing source data or an unsupported URI scheme
- **THEN** the playback source handoff returns its existing explicit failure result rather than accepting scanner-local source assumptions or constructing a parallel playback source model

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

### Requirement: Video detail playback actions SHALL use playback source handoff
Video detail continue-playback and episode-selection actions SHALL prepare playable local media through the existing playback source handoff contract rather than constructing playback sources in UI, provider, media-library, storage, gateway, network, or native-player code.

#### Scenario: Detail action prepares playback
- **WHEN** a video detail action selects an episode with an associated local media identity
- **THEN** the action handler uses playback source handoff to prepare an existing playback source value and reports normalized success or handoff failure

### Requirement: Video detail playback actions MUST preserve handoff isolation
Video detail playback actions MUST NOT require Bangumi, Dandanplay, RSS, subtitle provider, media scanner, storage implementation, network client, MPV, VLC, libmpv, media-kit, platform channel, diagnostics, BT engine, or online-rule runtime dependencies inside the playback source handoff path.

#### Scenario: Detail handoff imports are checked
- **WHEN** validation scans the detail runtime and playback handoff path
- **THEN** no forbidden provider implementation, UI widget, storage implementation, network, native player, BT engine, RSS, subtitle provider, or online-rule dependency is required to prepare local media playback

### Requirement: Media-library playback actions SHALL use playback source handoff
Media-library runtime playback actions SHALL pass selected `LocalMediaIdentity` or `MediaScanCandidate` values to `PlaybackSourceHandoffContract` rather than constructing playback sources directly.

#### Scenario: Runtime plays catalog item
- **WHEN** a user or test selects a catalog item for playback through the media-library runtime
- **THEN** the runtime calls `PlaybackSourceHandoffContract.prepare` with an existing local media handoff input and returns a normalized action outcome based on the handoff result

### Requirement: Media-library handoff failures SHALL remain normalized
Media-library runtime playback actions SHALL map missing source data, unsupported URI schemes, unsupported source values, and other handoff failures into explicit runtime outcomes.

#### Scenario: Runtime selects unsupported media URI
- **WHEN** a catalog item or scan candidate cannot be prepared by the handoff contract
- **THEN** the media-library runtime reports an unsupported or unavailable outcome without throwing native-player, UI, provider, storage, network, streaming, MPV, VLC, or platform exceptions

### Requirement: Media-library playback handoff MUST NOT bypass layer boundaries
Media-library runtime playback handoff MUST NOT import concrete player adapters, MPV/VLC bindings, media-kit/libmpv, streaming engines, ProviderGateway internals, storage implementations, network clients, or Flutter UI widgets.

#### Scenario: Runtime handoff boundary is checked
- **WHEN** validation scans media-library runtime and playback handoff usage
- **THEN** only Domain media values and playback source handoff contracts are required for local playback preparation

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

