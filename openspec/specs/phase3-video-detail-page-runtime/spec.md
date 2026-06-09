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
The video detail runtime SHALL execute continue playback, episode selection, follow, unfollow, open-binding, and refresh-metadata actions through existing Domain contracts and explicit results instead of direct UI, provider, storage, or native-player shortcuts.

#### Scenario: Continue playback is requested
- **WHEN** continue playback is requested for a detail with a local media identity and continue-watching state
- **THEN** the runtime resolves playback through the playback source handoff contract and reports success or a normalized action failure

### Requirement: Video detail runtime SHALL publish lifecycle-safe state and invalidation events
The video detail runtime SHALL expose lifecycle-safe repository/action behavior, reject or normalize operations after disposal, and publish cache invalidation events when detail metadata, binding, follow state, or continue-watching inputs change.

#### Scenario: Runtime is disposed
- **WHEN** load, watch, or action execution is requested after disposal
- **THEN** the runtime reports a disposed or unavailable state without mutating existing snapshots or bypassing Domain contracts

