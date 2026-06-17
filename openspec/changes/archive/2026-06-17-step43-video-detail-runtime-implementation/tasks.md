## 1. OpenSpec

- [x] 1.1 Create change `step43-video-detail-runtime-implementation`.
- [x] 1.2 Add spec deltas for concrete video-detail runtime implementation and layer boundaries.
- [x] 1.3 Run `openspec.cmd instructions apply --change "step43-video-detail-runtime-implementation" --json`.

## 2. Concrete Video Detail Runtime

- [x] 2.1 Add a storage/media-library backed video-detail repository or composition adapter.
- [x] 2.2 Add a concrete bootstrap/factory that adapts `StorageFoundation` media catalog, playback history, and provider bindings into video-detail contracts.
- [x] 2.3 Preserve deterministic seed-based detail runtime behavior for existing tests.
- [x] 2.4 Route actions through existing detail action handler, playback handoff, and cache invalidation contracts.
- [x] 2.5 Keep SQLite, SQL, HTTP transport, UI, native player, RSS, BT, and network details out of Domain detail runtime surfaces.

## 3. Tests, Tools, Docs

- [x] 3.1 Add focused tests for storage-backed detail loading.
- [x] 3.2 Add focused restart/replay tests using SQLite-backed storage.
- [x] 3.3 Extend video-detail runtime checker for storage-backed composition boundaries.
- [x] 3.4 Add non-UI smoke checker coverage for Step 43.
- [x] 3.5 Add Step 43 integration docs.

## 4. Validation And Archive

- [x] 4.1 Run focused video-detail tests and checker.
- [x] 4.2 Run `openspec.cmd validate "step43-video-detail-runtime-implementation" --strict`.
- [x] 4.3 Run baseline validation gates.
- [x] 4.4 Archive the OpenSpec change.
- [x] 4.5 Re-run `openspec.cmd validate --all` and report git status.
