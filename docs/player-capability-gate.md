# Player Capability Gate

Step 33 fixes the UI-facing rule for real local file playback: UI-owned code
must render controls and dispatch intents from Domain/Playback capability
contracts, not from knowledge of the concrete player backend.

## Concrete Local File Capabilities

`mediaKitLocalFilePlayerRuntimeComposition(...)` declares only these verified
capabilities:

- `localFilePlayback`
- `playPause`
- `seek`
- `stop`

The following capabilities remain unsupported until later changes implement
and validate them:

- `httpPlayback`
- `hlsPlayback`
- `progressReporting`
- `audioTrackDiscovery`
- `audioTrackSwitching`
- `subtitleTrackDiscovery`
- `subtitleTrackSwitching`
- `danmakuRendering`
- `secondaryPanels`
- `videoEnhancement`
- `hdrToneMapping`
- `debandFiltering`
- `anime4kPreset`
- `avSyncGuard`
- `matrixDanmaku`
- `dualSubtitles`
- `pgsSubtitleRendering`
- `assSubtitleEnhancement`
- `fallbackAdapter`

## UI Consumption Rule

External UI/app-shell code should construct player runtime through the Step 32
composition contract, then bind controls to `PlaybackPageContract` or the
controller surface state:

```dart
final PlayerRuntimeCompositionContract composition =
    mediaKitLocalFilePlayerRuntimeComposition(libmpvPath: optionalLibMpvPath);

final PlayerCoreBootstrap playerCore = PlayerCoreBootstrap.withComposition(
  composition: composition,
  foundationDependency: foundation,
);

final PlaybackPageContract playbackPage = PlaybackPageContract(
  controller: playerCore.controller,
);

final PlaybackPageSurfaceDescriptor surface = playbackPage.resolveSurface();
```

For the concrete local-file composition, `surface` may expose active
play/pause, seek, and stop controls. It must not expose progress, track
switching, secondary panels, advanced playback, danmaku, subtitle enhancement,
fallback, provider, streaming, or network controls unless the active capability
matrix declares those capabilities in a later change.

## Intent Rule

UI code must dispatch user actions through `PlaybackPageContract.dispatch(...)`
or equivalent Domain-facing controller methods after checking the active
surface descriptor. Unsupported intents are expected results, not exceptional
states. UI code must not call a concrete media_kit/libmpv backend directly to
bypass a missing capability.
