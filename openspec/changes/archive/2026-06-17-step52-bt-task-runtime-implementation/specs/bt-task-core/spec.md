## ADDED Requirements

### Requirement: BT task core SHALL expose a runtime composition contract
The BT task core SHALL expose a neutral runtime composition contract that app
composition can use to inject a download-engine adapter, BT task storage,
optional cache invalidation, and optional clock into `BtTaskCoreRuntime`
without importing concrete engine packages or UI surfaces.

#### Scenario: Composition creates a runtime
- **WHEN** app composition provides a `DownloadEngineAdapter` and `BtTaskStore`
  through the runtime composition contract
- **THEN** `BtTaskCoreBootstrap.withComposition(...)` creates a
  `BtTaskCoreRuntime` whose snapshots, action results, storage records, and
  invalidation events remain engine-neutral

### Requirement: Concrete libtorrent runtime composition SHALL stay adapter-owned
The concrete libtorrent runtime composition factory SHALL live in the approved
libtorrent adapter surface and SHALL return only the neutral BT task runtime
composition contract.

#### Scenario: Concrete composition is used
- **WHEN** the concrete libtorrent composition factory is built with a BT task
  store and cache invalidation bus
- **THEN** task creation, metadata fetching, file selection, lifecycle
  commands, status observation, and event observation execute through
  `BtTaskCoreRuntime` without exposing libtorrent plugin values to callers
