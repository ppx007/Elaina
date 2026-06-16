## 1. OpenSpec

- [x] 1.1 Create change `step34-player-ui-integration-contract`.
- [x] 1.2 Add spec deltas for playback source, lifecycle, dispose, and error integration.
- [x] 1.3 Run `openspec.cmd instructions apply --change "step34-player-ui-integration-contract" --json`.

## 2. Integration Contract

- [x] 2.1 Document app composition root wiring for the external UI model.
- [x] 2.2 Document playback source handoff for local file and future virtual stream inputs.
- [x] 2.3 Document lifecycle observation and command dispatch through Domain contracts.
- [x] 2.4 Document disposal ownership and normalized error presentation rules.
- [x] 2.5 Confirm no UI, app shell, Windows runner, file picker, route, page, or video surface files are changed.

## 3. Tests And Checkers

- [x] 3.1 Add focused tests for source handoff into player runtime open/play lifecycle.
- [x] 3.2 Add focused tests for normalized source failure and disposed runtime behavior.
- [x] 3.3 Extend player-core checker to keep the UI integration contract docs and regression coverage in place.
- [x] 3.4 Run focused player-core tests and checker.

## 4. Validation And Archive

- [x] 4.1 Run `openspec.cmd validate "step34-player-ui-integration-contract" --strict`.
- [x] 4.2 Run baseline validation gates.
- [x] 4.3 Archive the OpenSpec change.
- [x] 4.4 Re-run `openspec.cmd validate --all` and report git status.
