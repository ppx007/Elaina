## 1. Handoff Contract

- [x] 1.1 Add playback source handoff input and result value types for local media identity and scan candidate selections. Layers: Domain, Playback contract.
- [x] 1.2 Implement deterministic local file URI preparation that returns existing `LocalFilePlaybackSource` values and explicit failures for unsupported inputs. Layers: Domain, Playback contract.
- [x] 1.3 Ensure the handoff reuses existing `PlaybackSource`, `PlaybackController`, and media library contracts instead of creating parallel source or selection models. Layers: Domain, Playback.

## 2. Controller And Validation Wiring

- [x] 2.1 Add contract tests proving local media identities and scan candidates can be prepared into playback sources without provider, storage, streaming, gateway, network, or native dependencies. Layers: Domain, Tooling.
- [x] 2.2 Add runtime validation proving a controller can open a source produced by the handoff through the existing player adapter path. Layers: Domain, Playback, Tooling.
- [x] 2.3 Extend checker automation if needed to prevent handoff code from importing Provider, Gateway, Storage, Streaming, Network, Flutter widgets, MPV/native bindings, diagnostics, danmaku, Anime4K, RSS, Bangumi, Dandanplay, or online rule runtime implementations. Layers: Tooling.

## 3. Final Validation

- [x] 3.1 Run `flutter analyze`, `flutter test`, `dart analyze`, `powershell -ExecutionPolicy Bypass -File "tools\check_automation_extension_core.ps1"`, and `openspec validate --all`. Layers: Tooling.
