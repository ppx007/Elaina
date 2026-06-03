## 1. Controller Contract Loop

- [x] 1.1 Extend the playback controller contract to expose current playback state and observer registration without importing Flutter or UI shell code. Layers: Domain, Playback.
- [x] 1.2 Add deterministic mock controller behavior for play, pause, seek, stop, panel, and track-selection flows using existing playback state, surface, intent, and result contracts. Layers: Domain, Playback, UI contract.
- [x] 1.3 Ensure the controller-backed loop reuses `PlaybackPageContract`, `PlaybackPageIntent`, `PlaybackPageIntentResult`, and `PlaybackStateSnapshot` rather than introducing parallel UI-local or adapter-local models. Layers: Domain, UI.

## 2. Flutter Shell Integration

- [x] 2.1 Add or adapt a Flutter shell driver that delegates intent dispatch to the controller-backed boundary and renders observer-driven playback state. Layers: UI.
- [x] 2.2 Keep the Flutter shell free of direct `PlayerAdapter`, MPV, VLC, native binding, provider, gateway, storage, streaming, network, diagnostics, danmaku, Anime4K, and production state-management dependencies. Layers: UI, Tooling.

## 3. Validation

- [x] 3.1 Add contract or unit tests for controller-backed state observation and intent dispatch results. Layers: Domain, UI contract, Tooling.
- [x] 3.2 Add widget tests proving the Flutter shell renders controller-driven state and dispatches visible controls through the driver. Layers: UI, Tooling.
- [x] 3.3 Extend checker automation if needed to verify controller files remain framework-neutral and non-UI layers do not import Flutter shell files or Flutter packages. Layers: Tooling.
- [x] 3.4 Run `flutter analyze`, `flutter test`, `dart analyze`, `powershell -ExecutionPolicy Bypass -File "tools\check_automation_extension_core.ps1"`, and `openspec validate --all`. Layers: Tooling.
