## 1. Scanner Contract

- [x] 1.1 Refine existing `MediaLibraryScanner` contracts with scope normalization, typed scan failure semantics, and cancellation/watch terminal behavior. Layers: Domain, Media.
- [x] 1.2 Implement deterministic scanner contract fakes that exercise file roots, extension filters, recursion, exclude patterns, unsupported roots, unreadable entries, cancellation, and completed scans. Layers: Domain, Media.
- [x] 1.3 Ensure scanner output reuses existing media library identity/candidate/result/event contracts instead of creating scanner-local, UI-local, storage-local, playback-local, or provider-local media models. Layers: Domain, Media.

## 2. Handoff And Boundary Validation

- [x] 2.1 Add contract tests proving handoff-safe scanner candidates preserve non-empty file URI, non-empty basename, non-negative size, and can be prepared by the existing playback source handoff without provider, storage, gateway, network, streaming, UI, or native player dependencies. Layers: Domain, Playback, Tooling.
- [x] 2.2 Add runtime validation proving local scanner candidates stay Domain-owned until the playback source handoff prepares an existing `LocalFilePlaybackSource`, and proving invalid scanner candidates use existing explicit handoff failures. Layers: Domain, Playback, Tooling.
- [x] 2.3 Extend checker automation if needed to prevent local scanner code from importing Provider, Gateway, Storage implementation, Streaming, Network, Flutter widgets, MPV/native bindings, diagnostics, danmaku, Anime4K, RSS, Bangumi, Dandanplay, BT, VLC, or online rule runtime implementations. Layers: Tooling.

## 3. Final Validation

- [x] 3.1 Run `flutter analyze`, `flutter test`, `dart analyze`, `powershell -ExecutionPolicy Bypass -File "tools\check_automation_extension_core.ps1"`, and `openspec validate --all`. Layers: Tooling.
