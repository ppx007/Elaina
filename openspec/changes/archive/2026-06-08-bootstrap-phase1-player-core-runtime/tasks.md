## 1. Playback Runtime Composition

- [x] 1.1 Add `PlayerCoreRuntime` in the Domain playback composition layer that composes active adapter facade, playback controller, capability matrix, player clock, playback state observation, and track-management surfaces.
- [x] 1.2 Add `PlayerCoreBootstrap` with default deterministic construction plus explicit dependency construction, mirroring the Phase 0 bootstrap lifecycle pattern.
- [x] 1.3 Ensure player core bootstrap can receive a Phase 0 foundation runtime or bootstrap dependency without moving storage, ProviderGateway, cache invalidation, or layer-boundary ownership into the player-core runtime.
- [x] 1.4 Export only contract-safe player-core runtime surfaces through the public Dart barrel.

## 2. Deterministic Adapter and Capability Wiring

- [x] 2.1 Add deterministic MPV binding/runtime scaffolding that supports both unsupported and bound adapter paths without native MPV, libmpv, media-kit, VLC, or platform channels.
- [x] 2.2 Derive the runtime playback capability matrix from the active adapter or deterministic binding declaration.
- [x] 2.3 Gate load, play, pause, seek, stop, progress, and source operations through runtime capabilities before adapter delegation.
- [x] 2.4 Preserve normalized playback failures for unsupported or disposed runtime operations.

## 3. Controller, State, and Track Runtime

- [x] 3.1 Wire playback controller commands through `PlayerCoreRuntime` so command results are capability-gated and lifecycle-safe.
- [x] 3.2 Wire playback state observation through existing immutable `PlaybackStateSnapshot` contracts without Flutter state managers or native callback types.
- [x] 3.3 Wire audio and subtitle track discovery through active adapter normalized descriptors.
- [x] 3.4 Gate audio and subtitle track switching by runtime capability matrix and return normalized `TrackSwitchResult` outcomes.
- [x] 3.5 Keep playback page foundation consumption descriptor-based, with no mounted Flutter widgets, `MaterialApp`, platform views, or native video surfaces required for validation.

## 4. Boundary Checks, Tests, and Validation

- [x] 4.1 Add or extend a Phase 1 player-core checker script that rejects Flutter UI, Provider implementation, Storage internals, Streaming implementation, Network, concrete native player binding, VLC, BT, online-rule, and diagnostics UI dependencies in player-core runtime files.
- [x] 4.2 Add focused playback tests for bootstrap construction, default unsupported runtime, bound deterministic runtime, capability-derived surface state, controller commands, state observation, track discovery/switching, and disposal.
- [x] 4.3 Extend runtime smoke validation to cover the composed Phase 1 player core runtime without reducing existing player core contract coverage.
- [x] 4.4 Run `openspec validate "bootstrap-phase1-player-core-runtime" --strict`, `openspec validate --all`, `dart analyze`, focused playback tests, player-core runtime checks, and Phase 1 boundary checker scripts.
