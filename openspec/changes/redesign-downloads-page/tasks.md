## 1. Contracts

- [x] 1.1 Extend download domain projections with task source, upload speed,
  messages, timestamps, info hash, piece length, files, and capabilities.
- [x] 1.2 Add quick/advanced creation, file selection, and batch pause/resume
  commands to `DownloadRuntime`.
- [x] 1.3 Reject unsupported HTTP(S) torrent sources with an explicit failure.

## 2. UI

- [x] 2.1 Replace the task-card page with a dense BT management layout:
  toolbar, summary metrics, filters/search, task list, and detail panel.
- [x] 2.2 Support quick add and advanced add with metadata-driven file
  selection.
- [x] 2.3 Confirm task deletion and keep controls capability-aware.

## 3. Validation

- [x] 3.1 Update download domain/runtime and widget tests.
- [x] 3.2 Run `dart analyze`, targeted Flutter tests, changed-test gate, and
  `openspec.cmd validate --all`.
