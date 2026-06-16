## 1. OpenSpec

- [x] 1.1 Create change `step35-player-smoke-gate`.
- [x] 1.2 Add spec deltas for non-UI playback smoke and packaged release checks.
- [x] 1.3 Run `openspec.cmd instructions apply --change "step35-player-smoke-gate" --json`.

## 2. Smoke Gate

- [x] 2.1 Add a PowerShell smoke gate that validates release packaging with `libmpv-2.dll`.
- [x] 2.2 Reuse `tools/media_kit_mpv_binding_smoke.dart` for non-UI playback smoke.
- [x] 2.3 Support strict native mode and explicit skip behavior for machines without libmpv/sample media.
- [x] 2.4 Keep temporary files outside the repository and do not commit native binaries.

## 3. Docs And Checkers

- [x] 3.1 Document the Step 35 smoke checklist for core-only and external UI joined validation.
- [x] 3.2 Extend player-core checker to require the smoke gate script and checklist terms.
- [x] 3.3 Confirm no UI, app shell, Windows runner, file picker, route, page, or video surface files are changed.

## 4. Validation And Archive

- [x] 4.1 Run focused player-core tests and checkers.
- [x] 4.2 Run smoke gate in strict native mode when local libmpv is available.
- [x] 4.3 Run `openspec.cmd validate "step35-player-smoke-gate" --strict`.
- [x] 4.4 Run baseline validation gates.
- [x] 4.5 Archive the OpenSpec change.
- [x] 4.6 Re-run `openspec.cmd validate --all` and report git status.
