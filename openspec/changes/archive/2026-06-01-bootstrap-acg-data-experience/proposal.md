## Why

The player core is archived, so Celesteria can now add the first ACG-specific experience layer without destabilizing playback foundations. This change defines basic subtitles, Bangumi and Dandanplay provider boundaries, and basic danmaku rendering contracts while keeping provider traffic behind `ProviderGateway` and UI behind Domain/Playback contracts.

## What Changes

- Establish **Phase 2 / Step 9-12** as the next implementation boundary.
- Define basic subtitle parsing for SRT, VTT, and ASS, local external subtitle scanning, and external subtitle offset contracts.
- Define the Bangumi provider boundary for subject lookup, episode lookup, OAuth/session state, and progress sync.
- Define the Dandanplay provider boundary for matching, search, comment retrieval, and comment posting.
- Define basic danmaku rendering contracts for scrolling, top, bottom, filtering, and density controls.

## Capabilities

### New Capabilities
- `basic-subtitle-core`: Defines basic subtitle parsing, external subtitle references, and offset behavior.
- `bangumi-provider-boundary`: Defines Bangumi metadata, OAuth/session, episode, and progress-sync provider contracts.
- `dandanplay-provider-boundary`: Defines Dandanplay matching, search, comment retrieval, and posting provider contracts.
- `basic-danmaku-rendering`: Defines basic danmaku rendering modes, filtering, density, and playback-clock alignment.

### Modified Capabilities

None.

## Impact

- Adds ACG-facing Domain, Provider, Playback, and UI contracts after player-core foundations are stable.
- Requires Bangumi and Dandanplay traffic to use `ProviderGateway`, including rate policy registration and normalized failures.
- Requires playback UI to remain capability-driven and not import provider SDKs directly.
- Keeps Phase 3+ detail page, media library, subtitle provider integrations, RSS engine, yuc.wiki seasonal indexing, BT streaming, advanced rendering, and diagnostics out of scope.
