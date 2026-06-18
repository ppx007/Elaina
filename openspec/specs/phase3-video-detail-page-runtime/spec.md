# phase3-video-detail-page-runtime Specification

## Purpose
TBD - created by archiving change bootstrap-phase3-video-detail-page-runtime. Update Purpose after archive.
## Requirements
### Requirement: Video detail runtime SHALL assemble deterministic detail view data
The Phase 3 video detail page runtime SHALL assemble `VideoDetailViewData` for cover, summary, episodes, continue-watching state, follow state, binding state, and action sets using approved Domain/provider contracts without concrete Flutter widgets, storage migrations, RSS, subtitle provider, seasonal indexer, BT, online-rule, network policy, diagnostics, MPV/VLC, or native-player dependencies.

#### Scenario: Runtime loads detail data
- **WHEN** the runtime loads a detail id with available metadata, bindings, history, and local media state
- **THEN** it returns deterministic detail view data containing title, optional cover/summary data, episodes, continue-watching state, follow state, binding state, and at most two primary actions

### Requirement: Video detail runtime SHALL project metadata provider values through Domain contracts
The video detail runtime SHALL normalize metadata provider subject and episode values into `VideoDetailViewData` and `VideoDetailEpisode` values without exposing provider runtime internals, gateway request keys, HTTP transport, auth sessions, or provider cache policy details to UI callers.

#### Scenario: Metadata subject is projected
- **WHEN** a metadata provider returns a subject and episode list for a detail id
- **THEN** the runtime projects those values into Domain detail values while preserving provider implementation isolation

### Requirement: Video detail runtime SHALL execute detail actions through existing Domain contracts
The video detail runtime SHALL execute continue playback, episode selection,
follow, unfollow, open-binding, and refresh-metadata actions through existing
Domain contracts and explicit results instead of direct UI, provider, storage,
native-player shortcuts, or raw repository load exceptions.

#### Scenario: Continue playback is requested
- **WHEN** continue playback is requested for a detail with a local media identity and continue-watching state
- **THEN** the runtime resolves playback through the playback source handoff contract and reports success or a normalized action failure

#### Scenario: Detail action cannot load view data
- **WHEN** any detail action needs repository data and the repository cannot load
  the requested detail
- **THEN** the action returns a typed `VideoDetailActionResult.failed` result and
  does not leak the repository exception to the caller

### Requirement: Video detail runtime SHALL publish lifecycle-safe state and invalidation events
The video detail runtime SHALL expose lifecycle-safe repository/action behavior, reject or normalize operations after disposal, and publish cache invalidation events when detail metadata, binding, follow state, or continue-watching inputs change.

#### Scenario: Runtime is disposed
- **WHEN** load, watch, or action execution is requested after disposal
- **THEN** the runtime reports a disposed or unavailable state without mutating existing snapshots or bypassing Domain contracts

### Requirement: Video detail runtime SHALL provide storage-backed composition
The video-detail runtime implementation SHALL provide a concrete non-UI
composition path that adapts storage-backed media catalog, playback history,
and provider binding contracts into existing `VideoDetailRepository` and
`VideoDetailActionHandler` surfaces.

#### Scenario: Detail runtime is composed with storage
- **WHEN** an app composition root provides `StorageFoundation`, a metadata
  provider, `PlaybackSourceHandoffContract`, and `CacheInvalidationBus`
- **THEN** the runtime can load detail data, project bound local media,
  continue-watching state, binding/follow state, and action sets without
  importing Flutter UI, SQLite packages, SQL statements, provider transports,
  network policy, BT streaming, RSS automation, diagnostics, or native player
  bindings

### Requirement: Storage-backed video detail SHALL project local catalog entries
Storage-backed video-detail loading SHALL use provider bindings to find local
media catalog items associated with the requested detail id and SHALL expose
them as playable detail episodes when provider episode metadata is not supplied
by the current contracts.

#### Scenario: Bound local media is loaded without provider episode list
- **WHEN** local media items are persisted with provider bindings whose subject
  id matches the requested detail id
- **THEN** the runtime returns detail view data with a provider subject title,
  summary, local-media backed episodes ordered deterministically, latest
  continue-watching state, strongest binding, and valid primary action count

### Requirement: Storage-backed video detail SHALL preserve provider episode projection
Storage-backed video-detail loading SHALL preserve existing provider episode
projection behavior when explicit episode metadata is supplied through the
current detail seed contract.

#### Scenario: Provider episode seed is supplied
- **WHEN** detail composition includes a `BangumiVideoDetailSeed` for the
  requested subject
- **THEN** provider episode ids, titles, indexes, cover URI, and local-media
  mapping are used while storage-backed history and binding state still supply
  continue-watching and follow state

### Requirement: Video detail actions SHALL remain contract-routed
Concrete video-detail runtime implementation SHALL execute continue playback,
episode selection, follow, unfollow, and refresh metadata through existing
Domain detail action, playback source handoff, provider binding, and cache
invalidation contracts.

#### Scenario: Detail action is performed on storage-backed data
- **WHEN** a storage-backed detail action is performed
- **THEN** it returns a typed `VideoDetailActionResult`, emits existing
  invalidation events when state changes, and does not call UI navigation,
  concrete player bindings, provider HTTP transports, SQLite SQL, RSS, BT,
  network, or diagnostics implementation details directly

### Requirement: Video detail runtime SHALL participate in the library smoke gate
The storage-backed video-detail runtime SHALL be consumable by the non-UI
library smoke gate using persisted media-library catalog, playback-history, and
provider-binding state.

#### Scenario: Smoke gate loads storage-backed detail
- **WHEN** the library smoke gate binds imported local media to a deterministic
  metadata subject and loads detail data for that subject
- **THEN** the video-detail runtime returns local-media backed episodes,
  strongest binding state, latest continue-watching state, and contract-routed
  playback actions without importing UI widgets, concrete provider transports,
  native player bindings, RSS, BT, streaming, network, or diagnostics
  implementations

