## 1. Specification

- [x] 1.1 Create change `enhance-rss-auto-download-rules`.
- [x] 1.2 Add spec deltas for RSS rule editing and download handoff.

## 2. Runtime

- [x] 2.1 Add feed-scoped auto-download rule projections, drafts, CRUD, and
  preview methods to `RssEngineRuntime`.
- [x] 2.2 Execute enabled rules after successful refresh and record enqueue
  outcomes.
- [x] 2.3 Add RSS download enqueuer and torrent URL resolver boundaries.

## 3. UI

- [x] 3.1 Add rule creation to the RSS subscription dialog.
- [x] 3.2 Add selected-feed rule management and preview to the RSS page.
- [x] 3.3 Add auto-download match filtering and item badges.

## 4. Validation

- [x] 4.1 Add runtime tests for rule persistence, preview, execution, and
  dedupe.
- [x] 4.2 Add widget tests for rule creation, editing, preview, and filtering.
- [x] 4.3 Run Dart analysis, focused Flutter tests, OpenSpec validation, and
  fast changed-test gate.
