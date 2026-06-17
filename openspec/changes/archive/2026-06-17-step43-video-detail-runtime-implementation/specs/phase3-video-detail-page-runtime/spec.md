## ADDED Requirements

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
