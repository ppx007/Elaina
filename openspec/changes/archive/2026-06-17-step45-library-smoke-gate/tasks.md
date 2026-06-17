## 1. OpenSpec

- [x] 1.1 Create change `step45-library-smoke-gate`.
- [x] 1.2 Add spec deltas for the library smoke gate and ownership boundaries.
- [x] 1.3 Run `openspec.cmd instructions apply --change "step45-library-smoke-gate" --json`.

## 2. Smoke Gate

- [x] 2.1 Add a dedicated non-UI Dart smoke gate for scan -> import -> detail -> playback handoff -> playback history -> continue-watching replay.
- [x] 2.2 Use existing storage-backed media-library and video-detail composition paths instead of adding new runtime abstractions.
- [x] 2.3 Keep provider metadata deterministic and local to the smoke gate; do not require live network.
- [x] 2.4 Keep UI, native player, streaming, RSS, BT, diagnostics, and provider transport code outside this change.

## 3. Tests And Checkers

- [x] 3.1 Add focused tests for the full library smoke flow.
- [x] 3.2 Add a PowerShell smoke checker and wire it into the media-library runtime checker.
- [x] 3.3 Add integration notes for UI/app-shell handoff without editing UI files.
- [x] 3.4 Enforce Step 45 boundary terms in checker scripts.

## 4. Validation And Archive

- [x] 4.1 Run focused media-library/detail/history tests and smoke checker.
- [x] 4.2 Run `openspec.cmd validate "step45-library-smoke-gate" --strict`.
- [x] 4.3 Run baseline validation gates.
- [x] 4.4 Archive the OpenSpec change.
- [x] 4.5 Re-run `openspec.cmd validate --all` and report git status.
