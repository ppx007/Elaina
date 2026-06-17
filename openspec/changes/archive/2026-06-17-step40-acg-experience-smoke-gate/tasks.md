## 1. OpenSpec

- [x] 1.1 Create change `step40-acg-experience-smoke-gate`.
- [x] 1.2 Add spec deltas for the ACG experience smoke gate and ownership boundaries.
- [x] 1.3 Run `openspec.cmd instructions apply --change "step40-acg-experience-smoke-gate" --json`.

## 2. Runtime Composition

- [x] 2.1 Add a Domain ACG experience runtime that composes existing ACG, subtitle, and playback metadata bridge contracts.
- [x] 2.2 Enrich a local media request with Bangumi metadata, Dandanplay match/comments, provider subtitle discovery, and playback metadata projection.
- [x] 2.3 Preserve provider gateway/cache behavior by reusing existing provider runtimes and subtitle cache paths.
- [x] 2.4 Normalize partial provider/runtime failures without throwing raw transport, gateway, or parser exceptions.
- [x] 2.5 Keep UI, native player, streaming, and storage implementation code outside this change.

## 3. Tests And Checkers

- [x] 3.1 Add focused tests for full ACG smoke success, cache reuse, typed failures, and disposal.
- [x] 3.2 Add a non-UI runtime smoke checker for the full ACG experience path.
- [x] 3.3 Extend PowerShell boundary checks to require the Step 40 smoke gate and forbid UI/provider-client/native-player leaks.
- [x] 3.4 Add integration notes for app composition without editing UI files.

## 4. Validation And Archive

- [x] 4.1 Run focused ACG smoke gate tests and related checkers.
- [x] 4.2 Run `openspec.cmd validate "step40-acg-experience-smoke-gate" --strict`.
- [x] 4.3 Run baseline validation gates.
- [x] 4.4 Archive the OpenSpec change.
- [x] 4.5 Re-run `openspec.cmd validate --all` and report git status.
