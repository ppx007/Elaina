## 1. Flutter Shell Setup

- [x] 1.1 Add the minimal Flutter SDK dependency and test dependency needed to compile the shell. Layers: UI, package manifest.
- [x] 1.2 Add a minimal UI playback shell directory and file structure without app-wide routing or platform packaging. Layers: UI.

## 2. Mock-Driven Playback Shell

- [x] 2.1 Implement a minimal Flutter playback page that renders `PlaybackStateSnapshot` and `PlaybackPageSurfaceDescriptor`. Layers: UI.
- [x] 2.2 Add a mock shell driver that dispatches `PlaybackPageIntent` values and produces deterministic state changes. Layers: UI.
- [x] 2.3 Keep shell code free of MPV, VLC, native player bindings, providers, streaming, gateway, storage, network, diagnostics, danmaku, Anime4K, and production state-management packages. Layers: UI, Tooling.

## 3. Shell Validation

- [x] 3.1 Add widget or closest available shell tests for rendered state, visible controls, panel entry points, and intent dispatch. Layers: UI, Tooling.
- [x] 3.2 Extend checker automation to verify non-UI layers do not import Flutter shell files or Flutter packages. Layers: Tooling.
- [x] 3.3 Run Flutter validation when the Flutter SDK is available, plus `dart analyze`, `powershell -ExecutionPolicy Bypass -File "tools\check_automation_extension_core.ps1"`, and `openspec validate --all`. Layers: Tooling.
