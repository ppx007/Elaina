## 1. UI Surface Contract Model

- [x] 1.1 Define framework-neutral playback page control and panel descriptor types under `lib/src/ui/playback/`. Layers: UI.
- [x] 1.2 Extend `PlaybackPageContract` so it resolves UI surface descriptors from `PlaybackController.resolveSurfaceState()`. Layers: UI, Domain-facing contract consumption.
- [x] 1.3 Export the surface contract descriptors through the public package barrel if needed for checker/runtime validation. Layers: UI, package API.

## 2. Capability-Driven Mapping Checks

- [x] 2.1 Add runtime checks proving transport/progress capabilities map to active UI control descriptors. Layers: UI, Tooling.
- [x] 2.2 Add runtime checks proving absent audio/subtitle track capabilities are not exposed as active controls. Layers: UI, Tooling.
- [x] 2.3 Add runtime checks proving absent secondary panel capabilities are not exposed as active panel descriptors. Layers: UI, Tooling.

## 3. Layer Boundary Automation

- [x] 3.1 Extend checker automation to verify Domain and Playback Dart files do not import `lib/src/ui`. Layers: Tooling.
- [x] 3.2 Extend checker automation to verify UI playback files do not import MPV, VLC, libmpv, media-kit, provider internals, streaming internals, gateway internals, storage internals, or native player bindings. Layers: Tooling.
- [x] 3.3 Keep validation independent of Flutter widgets, BuildContext, layout, styling, animation, and native rendering surfaces. Layers: UI, Tooling.

## 4. Validation

- [x] 4.1 Run `dart analyze`. Layers: Tooling.
- [x] 4.2 Run `powershell -ExecutionPolicy Bypass -File "tools\check_player_core.ps1"` and the full checker chain. Layers: Tooling.
- [x] 4.3 Run `openspec validate implement-playback-page-surface-contract --strict` and `openspec validate --all`. Layers: Tooling.
