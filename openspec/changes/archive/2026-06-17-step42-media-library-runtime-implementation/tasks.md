## 1. OpenSpec

- [x] 1.1 Create change `step42-media-library-runtime-implementation`.
- [x] 1.2 Add spec deltas for concrete media-library runtime implementation and layer boundaries.
- [x] 1.3 Run `openspec.cmd instructions apply --change "step42-media-library-runtime-implementation" --json`.

## 2. Concrete Media Library Runtime

- [x] 2.1 Add a `dart:io` local-file scanner that emits existing `MediaScanCandidate` and `MediaScanEvent` contracts.
- [x] 2.2 Add storage-backed catalog, playback-history, and provider-binding adapters over `StorageFoundation` contracts.
- [x] 2.3 Add a storage-backed media-library bootstrap/factory for app composition roots.
- [x] 2.4 Keep existing deterministic media-library runtime/contracts available for acceptance tests.
- [x] 2.5 Keep SQLite imports, SQL, and database handles out of Domain media runtime code.

## 3. Tests, Tools, Docs

- [x] 3.1 Add focused tests for local file scanning.
- [x] 3.2 Add focused SQLite restart tests for storage-backed media-library runtime.
- [x] 3.3 Extend media-library runtime checker for concrete scanner/composition boundaries.
- [x] 3.4 Add non-UI smoke checker coverage for Step 42.
- [x] 3.5 Add Step 42 integration docs.

## 4. Validation And Archive

- [x] 4.1 Run focused media-library tests and checker.
- [x] 4.2 Run `openspec.cmd validate "step42-media-library-runtime-implementation" --strict`.
- [x] 4.3 Run baseline validation gates.
- [x] 4.4 Archive the OpenSpec change.
- [x] 4.5 Re-run `openspec.cmd validate --all` and report git status.
