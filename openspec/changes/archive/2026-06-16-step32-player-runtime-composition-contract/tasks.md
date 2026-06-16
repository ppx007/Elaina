## 1. OpenSpec

- [x] 1.1 Create change `step32-player-runtime-composition-contract`.
- [x] 1.2 Add spec deltas for player runtime composition, UI ownership, and checker coverage.
- [x] 1.3 Run `openspec.cmd instructions apply --change "step32-player-runtime-composition-contract" --json`.

## 2. Composition Contract

- [x] 2.1 Add a neutral playback runtime composition descriptor for binding plus capabilities.
- [x] 2.2 Add a media_kit/libmpv local-file composition factory with optional `libmpvPath`.
- [x] 2.3 Add Domain bootstrap wiring that consumes the neutral descriptor without importing concrete player code.
- [x] 2.4 Preserve unsupported and deterministic runtime construction paths.

## 3. Integration Notes And Boundary Checks

- [x] 3.1 Document external UI/app-shell composition root usage without adding UI code.
- [x] 3.2 Document packaged Windows release smoke flow using `tools/package_windows_release.ps1`.
- [x] 3.3 Extend player-core checks to reject direct concrete player imports in UI and `lib/main.dart`.
- [x] 3.4 Verify no files under `lib/src/ui/**`, `lib/main.dart`, or `windows/**` are changed.

## 4. Tests

- [x] 4.1 Add focused tests for the composition descriptor and media_kit composition factory.
- [x] 4.2 Update smoke tooling to use the same composition contract exposed to app composition roots.
- [x] 4.3 Run focused player-core tests and checker.

## 5. Validation And Archive

- [x] 5.1 Run `openspec.cmd validate "step32-player-runtime-composition-contract" --strict`.
- [x] 5.2 Run baseline validation gates.
- [x] 5.3 Archive the OpenSpec change.
- [x] 5.4 Re-run `openspec.cmd validate --all` and report git status.
