## ADDED Requirements

### Requirement: Video detail contract SHALL support deterministic runtime-backed repositories
The video detail page contract SHALL support a deterministic runtime-backed repository and action handler that assemble detail data through Domain contracts while preserving the existing UI-facing `VideoDetailController` and `VideoDetailPageContract` boundaries.

#### Scenario: Contract resolves runtime-backed detail data
- **WHEN** a page contract calls `load` or `watch` for a runtime-backed detail id
- **THEN** it receives Domain detail data without direct UI access to providers, storage, RSS, playback adapters, or native player internals

### Requirement: Video detail actions SHALL return explicit runtime outcomes
The video detail page contract SHALL allow runtime action handlers to expose explicit success, ignored, unsupported, unavailable, and failed outcomes for continue playback, episode selection, follow, unfollow, open-binding, and refresh-metadata operations.

#### Scenario: Action cannot be executed
- **WHEN** a requested detail action cannot be executed because metadata, binding, local media, playback handoff, or runtime lifecycle state is unavailable
- **THEN** the action handler returns a normalized outcome instead of throwing provider, storage, network, UI, or native-player exceptions

### Requirement: Video detail action derivation SHALL preserve primary action limits
Runtime-derived detail actions SHALL preserve the existing limit of at most two primary actions and SHALL expose additional operations as secondary actions.

#### Scenario: Runtime derives multiple actions
- **WHEN** detail data has continue playback, episode selection, follow state, refresh, and binding operations available
- **THEN** no more than two actions are marked primary and all remaining actions are marked secondary
