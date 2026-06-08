## Why

Phase 0 now has an executable foundation bootstrap, but Phase 1 player core surfaces still live as separate contracts and checker slices rather than a lifecycle-managed runtime. The next architecture-plan slice is Phase 1 / Step 5-8, so Celesteria needs a composed player-core bootstrap before moving into ACG data, BT streaming, advanced playback, or application shell work.

## What Changes

- Add a Phase 1 player core runtime bootstrap that composes MPV adapter facade, playback capability matrix, playback controller, track management, player clock, and playback state observation behind a single contract-safe entry point.
- Add deterministic player-core runtime scaffolding for tests and early app-shell wiring without native MPV/libmpv/media-kit bindings.
- Wire Phase 1 runtime construction on top of the Phase 0 foundation runtime without letting UI, Provider, Storage internals, Network, or Streaming own playback lifecycle decisions.
- Add player-core boundary validation terms and focused runtime tests proving lifecycle cleanup, capability-gated operations, track switching, and state observation.
- Keep native playback binding, actual video rendering, Flutter app shell, provider data integration, BT streaming, and advanced rendering out of this change.

## Capabilities

### New Capabilities
- `phase1-player-core-runtime`: Composed runtime/bootstrap capability for Phase 1 Step 5-8 player core surfaces.

### Modified Capabilities
- `mpv-adapter-boundary`: Add requirements for MPV facade participation in a composed player-core runtime without concrete native binding leakage.
- `playback-capability-matrix`: Add requirements for runtime-derived capability declarations from the active player adapter.
- `playback-controller-contract`: Add requirements for bootstrap-wired playback controller lifecycle and capability-gated command handling.
- `playback-state-contract`: Add requirements for runtime-owned playback state observation.
- `track-management`: Add requirements for runtime-wired audio/subtitle track discovery and switching.
- `playback-page-foundation`: Add requirements that playback page foundation consumes player-core runtime surfaces rather than direct adapter implementations.
- `layered-architecture`: Add Phase 1 runtime boundary requirements that preserve UI/Domain/Playback isolation.

## Impact

- New player-core runtime/bootstrap files under `lib/src/domain/playback/` plus deterministic binding scaffolding under `lib/src/playback/`.
- Public barrel exports in `lib/celesteria.dart` for contract-safe player-core runtime surfaces.
- Focused tests under `test/playback/` and checker updates in `tools/`.
- OpenSpec deltas for the new runtime capability and the existing Phase 1 playback/layering capabilities listed above.
