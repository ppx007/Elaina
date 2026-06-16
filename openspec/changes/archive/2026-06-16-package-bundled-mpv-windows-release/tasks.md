## 1. OpenSpec

- [x] 1.1 Create change `package-bundled-mpv-windows-release`.
- [x] 1.2 Add spec deltas for bundled libmpv resolution and Windows release packaging.
- [x] 1.3 Run `openspec.cmd instructions apply --change "package-bundled-mpv-windows-release" --json`.

## 2. Runtime Resolution

- [x] 2.1 Add a Playback-owned bundled libmpv resolver for Windows.
- [x] 2.2 Let `MediaKitMpvBackendAdapter` call `MediaKit.ensureInitialized(libmpv: ...)` with an explicit or bundled DLL path when available.
- [x] 2.3 Preserve normalized failure behavior when no bundled DLL is present.
- [x] 2.4 Keep concrete media_kit/libmpv behavior out of Domain, UI, Provider, Storage, Streaming, and Network layers.

## 3. Packaging Tooling

- [x] 3.1 Add a Windows release packaging/check script that stages `libmpv-2.dll` beside the app executable.
- [x] 3.2 Produce a zip artifact from a release directory without relying on global PATH.
- [x] 3.3 Fail fast when no Windows release directory, app executable, or libmpv DLL source is available.
- [x] 3.4 Do not commit third-party binary DLLs.

## 4. Tests And Checkers

- [x] 4.1 Add unit tests for bundled libmpv path resolution.
- [x] 4.2 Add tooling tests/checks for release directory verification.
- [x] 4.3 Update player-core checker to include bundled resolver and packaging tool constraints.
- [x] 4.4 Verify no changes are made under `lib/src/ui/**` or `lib/main.dart`.

## 5. Validation And Archive

- [x] 5.1 Run focused playback tests and player-core checker.
- [x] 5.2 Run `openspec.cmd validate "package-bundled-mpv-windows-release" --strict`.
- [x] 5.3 Run baseline validation gates.
- [x] 5.4 Archive the OpenSpec change.
- [x] 5.5 Re-run `openspec.cmd validate --all` and report git status.
