## 1. OpenSpec

- [x] 1.1 Create change `step37-dandanplay-api-client`.
- [x] 1.2 Add spec deltas for the concrete Dandanplay client boundary.
- [x] 1.3 Run `openspec.cmd instructions apply --change "step37-dandanplay-api-client" --json`.

## 2. Concrete Dandanplay Client

- [x] 2.1 Add a Provider-layer Dandanplay HTTP API client with injectable transport.
- [x] 2.2 Map local media match, search, and comment responses into existing provider values.
- [x] 2.3 Map comment posting and optional bearer/app credential behavior without adding UI or token persistence.
- [x] 2.4 Preserve deterministic Dandanplay runtime fixtures and allow runtime/bootstrap injection of concrete providers.

## 3. Tests And Checkers

- [x] 3.1 Add fake-transport tests for request paths, JSON mapping, headers, and normalized failures.
- [x] 3.2 Extend Dandanplay runtime checks to require the concrete client and forbid boundary leaks.
- [x] 3.3 Confirm UI, app shell, Windows runner, playback runtime, streaming, storage, and network runtime files remain outside the change.

## 4. Validation And Archive

- [x] 4.1 Run focused Dandanplay tests and ACG/danmaku checkers.
- [x] 4.2 Run `openspec.cmd validate "step37-dandanplay-api-client" --strict`.
- [x] 4.3 Run baseline validation gates.
- [x] 4.4 Archive the OpenSpec change.
- [x] 4.5 Re-run `openspec.cmd validate --all` and report git status.
