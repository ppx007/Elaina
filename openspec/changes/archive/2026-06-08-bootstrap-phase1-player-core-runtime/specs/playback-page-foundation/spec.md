## ADDED Requirements

### Requirement: Playback page foundation SHALL consume player core runtime surfaces indirectly
The playback page foundation SHALL consume controller surface state, playback state snapshots, capability matrix data, and intent results produced by player core runtime through Domain/UI contracts rather than importing concrete adapter or binding implementations.

#### Scenario: Playback page asks for visible controls
- **WHEN** playback page foundation resolves visible controls and panels
- **THEN** the result is derived from player core runtime capabilities and controller surface state without importing MPV, libmpv, media-kit, native player, Provider, Streaming, Storage, Network, or playback binding implementation details

### Requirement: Playback page foundation MUST remain render-surface optional in Phase 1 runtime
The Phase 1 player core runtime bootstrap MUST NOT require Flutter video rendering, `MaterialApp`, navigation, platform views, or native video surfaces to validate playback page foundation contracts.

#### Scenario: Runtime tests execute without UI shell
- **WHEN** Phase 1 player core runtime tests run
- **THEN** playback page foundation behavior is verified through descriptors and intent results rather than mounted Flutter widgets or native video surfaces
