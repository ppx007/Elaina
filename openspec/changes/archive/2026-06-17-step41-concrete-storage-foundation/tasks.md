## 1. OpenSpec

- [x] 1.1 Create change `step41-concrete-storage-foundation`.
- [x] 1.2 Add spec deltas for concrete SQLite storage and layer boundaries.
- [x] 1.3 Run `openspec.cmd instructions apply --change "step41-concrete-storage-foundation" --json`.

## 2. Concrete Storage Implementation

- [x] 2.1 Add SQLite-backed metadata/settings/blob/media-cache stores.
- [x] 2.2 Add SQLite-backed media library, playback history, and provider binding stores.
- [x] 2.3 Add SQLite-backed subtitle search/content cache stores.
- [x] 2.4 Add a `SqliteStorageFoundation` composition that keeps deterministic fallback stores injectable for out-of-scope feature domains.
- [x] 2.5 Keep `DeterministicStorageFoundation` adapter-free and unchanged for bootstrap tests.

## 3. Tests And Checkers

- [x] 3.1 Add focused restart-persistence tests for the Step 41 concrete stores.
- [x] 3.2 Add a non-UI SQLite storage smoke checker.
- [x] 3.3 Extend boundary checks to keep SQLite details inside Foundation/Storage implementation and tests/tools.
- [x] 3.4 Add docs for Step 41 usage and non-goals.

## 4. Validation And Archive

- [x] 4.1 Run focused SQLite storage tests and checker.
- [x] 4.2 Run `openspec.cmd validate "step41-concrete-storage-foundation" --strict`.
- [x] 4.3 Run baseline validation gates.
- [x] 4.4 Archive the OpenSpec change.
- [x] 4.5 Re-run `openspec.cmd validate --all` and report git status.
