## 1. Basic subtitle core

- [x] 1.1 Define subtitle source contracts for embedded and external subtitle references in the Playback layer.
- [x] 1.2 Define parser contracts for SRT, VTT, and ASS cues without adding provider-backed subtitle discovery.
- [x] 1.3 Define subtitle offset behavior using player-clock timing rather than wall-clock timing.
- [x] 1.4 Define local external subtitle scanning contracts for media-adjacent SRT, VTT, and ASS files without adding provider-backed subtitle discovery.

## 2. Bangumi provider boundary

- [x] 2.1 Define Bangumi subject and episode lookup contracts in the Provider/Domain boundary.
- [x] 2.2 Define Bangumi OAuth/session and progress-sync contracts without making provider auth a playback prerequisite.
- [x] 2.3 Register Bangumi provider traffic through `ProviderGateway` with rate policy and normalized failure semantics.

## 3. Dandanplay provider boundary

- [x] 3.1 Define Dandanplay match and search contracts in the Provider/Domain boundary.
- [x] 3.2 Define Dandanplay comment retrieval and posting contracts without coupling UI to provider SDKs.
- [x] 3.3 Register Dandanplay provider traffic through `ProviderGateway` with rate policy and normalized failure semantics.

## 4. Basic danmaku rendering

- [x] 4.1 Define danmaku comment event contracts with player-clock timestamps.
- [x] 4.2 Define basic scrolling, top, and bottom rendering mode contracts.
- [x] 4.3 Define filtering and density controls while excluding advanced matrix effects and diagnostics integration.

## 5. Verification and next boundary

- [x] 5.1 Verify playback remains usable without Bangumi, Dandanplay, subtitle providers, RSS, BT, or online rule sources.
- [x] 5.2 Verify provider traffic does not bypass `ProviderGateway` and UI does not import provider SDKs directly.
- [x] 5.3 Prepare the next change boundary for Phase 3 / Step 13-17 only after Phase 2 contracts are stable.
