## Why

Elaina has frozen the BT playback boundary through Step 21, so the next roadmap slice can define advanced playback capabilities without coupling UI to a specific renderer or fallback engine. Phase 5 establishes the contracts for enhancement profiles, A/V sync protection, advanced caption/danmaku rendering, and VLC fallback capability hiding.

## What Changes

- Establish **Phase 5 / Step 22-25** as the next implementation boundary.
- Define `VideoEnhancementPipeline` contracts for scaler, HDR, deband, and Anime4K-style preset profiles without adding concrete renderer implementation.
- Define `AVSyncGuard` contracts for A/V drift, dropped frames, render delay, and automatic degradation decisions.
- Define advanced danmaku/subtitle contracts for Matrix4 danmaku, dual subtitles, PGS, and ASS enhancement feature gating.
- Define VLC fallback adapter contracts for failure switching and capability hiding.
- Extend playback capability matrix requirements so advanced playback and fallback features remain adapter/platform scoped.

## Capabilities

### New Capabilities
- `video-enhancement-pipeline`: Defines enhancement profiles, render budget inputs, and advanced scaler/HDR/deband/Anime4K preset contracts.
- `av-sync-guard`: Defines A/V drift monitoring, degradation thresholds, and automatic fallback decision contracts.
- `advanced-caption-rendering`: Defines advanced danmaku/subtitle capability contracts for Matrix4 danmaku, dual subtitles, PGS, and ASS enhancement.
- `vlc-fallback-adapter`: Defines fallback adapter switching and capability hiding contracts for VLC or future secondary player adapters.

### Modified Capabilities
- `playback-capability-matrix`: Add explicit advanced playback and fallback capability gating requirements.

## Impact

- Adds Playback-layer and Domain-facing contracts for advanced playback scaffolding.
- Requires advanced rendering and fallback behavior to remain capability-gated by adapter and platform.
- Keeps concrete MPV shader implementation, concrete VLC binding, diagnostics center, DNS/network policy, online rules, and RSS auto-download out of scope.
- Preserves the A/V sync red line: drift under 40ms as target, drift over 120ms as a degradation trigger.
