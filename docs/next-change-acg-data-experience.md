# Next Change Boundary: Phase 2 ACG Data Experience

Start this change only after `bootstrap-player-core` is implemented and archived.

## Scope

- Step 9: Basic subtitle parsing, local external subtitle scanning, and external subtitle offset contracts.
- Step 10: Bangumi provider boundary for subject, episode, OAuth, and progress sync.
- Step 11: Dandanplay provider boundary for matching, search, comments, and posting.
- Step 12: Basic danmaku rendering contract with scrolling, top, bottom, filtering, and density controls.

## Carry-Forward Checks

- Provider traffic must route through `ProviderGateway`.
- UI must continue to depend on Domain and Playback contracts, not provider SDKs.
- Player capability decisions remain capability-matrix driven.
