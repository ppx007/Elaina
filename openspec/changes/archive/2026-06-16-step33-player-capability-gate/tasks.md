## 1. OpenSpec

- [x] 1.1 Create change `step33-player-capability-gate`.
- [x] 1.2 Add spec deltas for UI-facing capability gate behavior.
- [x] 1.3 Run `openspec.cmd instructions apply --change "step33-player-capability-gate" --json`.

## 2. Capability Gate Notes

- [x] 2.1 Document the concrete local-file capability set for UI/app-shell consumers.
- [x] 2.2 Document that UI must render controls and dispatch intents from `PlaybackPageContract`/surface descriptors.
- [x] 2.3 Document unsupported capabilities that must remain hidden or disabled until implemented.
- [x] 2.4 Confirm no UI, app shell, Windows runner, file picker, route, page, or video surface files are changed.

## 3. Tests And Checkers

- [x] 3.1 Add focused tests that media_kit local-file composition exposes play/pause, seek, and stop controls only.
- [x] 3.2 Extend player-core checker to keep the UI-facing capability gate docs and unverified-capability exclusions in place.
- [x] 3.3 Run focused player-core tests and checker.

## 4. Validation And Archive

- [x] 4.1 Run `openspec.cmd validate "step33-player-capability-gate" --strict`.
- [x] 4.2 Run baseline validation gates.
- [x] 4.3 Archive the OpenSpec change.
- [x] 4.4 Re-run `openspec.cmd validate --all` and report git status.
