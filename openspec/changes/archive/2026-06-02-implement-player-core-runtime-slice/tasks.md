## 1. Playback Adapter Runtime Slice

- [x] 1.1 Add a Dart-only in-memory `MpvAdapterBinding` test/support implementation for Player core verification. Layers: Playback.
- [x] 1.2 Add source-category support checks so adapter load behavior respects `localFilePlayback`, `httpPlayback`, and `hlsPlayback` capability states. Layers: Playback.
- [x] 1.3 Verify unsupported `MpvPlayerAdapterFacade` commands return normalized failures or unsupported track results without throwing native-player exceptions. Layers: Playback.
- [x] 1.4 Verify bound `MpvPlayerAdapterFacade` commands delegate through `MpvAdapterBinding` without exposing MPV/libmpv/media-kit types. Layers: Playback.

## 2. Capability-Driven Surface State

- [x] 2.1 Add runtime checks for `PlaybackController.resolveSurfaceState()` when only transport/progress capabilities are supported. Layers: Domain, Playback.
- [x] 2.2 Add runtime checks for audio/subtitle track controls and tracks panel exposure when track and secondary panel capabilities are supported. Layers: Domain, Playback.
- [x] 2.3 Verify undeclared capabilities remain explicitly unsupported with a reason. Layers: Playback.

## 3. Track Management Runtime Checks

- [x] 3.1 Add normalized audio and subtitle track discovery checks using stable `MediaTrackId`, labels, and track kinds. Layers: Playback.
- [x] 3.2 Add successful track switching checks through `PlaybackController.switchTrack()` or equivalent Playback contract routing. Layers: Domain, Playback.
- [x] 3.3 Add unsupported track switching checks that return `TrackSwitchResult.unsupported` and remain hidden by capability-driven surface state. Layers: Domain, Playback.

## 4. Validation Integration

- [x] 4.1 Extend the relevant project checker script so the Player core runtime slice is validated by automation. Layers: Tooling.
- [x] 4.2 Run `dart analyze` and `powershell -ExecutionPolicy Bypass -File "tools\check_player_core.ps1"`. Layers: Tooling.
- [x] 4.3 Run `openspec validate implement-player-core-runtime-slice --strict` and `openspec validate --all`. Layers: Tooling.
