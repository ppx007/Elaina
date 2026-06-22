## 1. Contracts

- [x] 1.1 Add desktop-media-library spec deltas for folder configuration,
  catalog projection, search/filter behavior, selection details, and actions.
- [x] 1.2 Keep `MediaLibraryPage` constructor compatibility and reuse existing
  `MediaLibraryRuntime` methods for scan, import, playback, matching, and
  removal.

## 2. UI

- [x] 2.1 Replace the card-only page with a toolbar, summary metrics,
  folder pane, dense media list, and detail panel.
- [x] 2.2 Add search and filters for all, continue-watching, bound, and
  unbound media.
- [x] 2.3 Route single-file playback through `MediaLibraryRuntime.playCandidate`
  and show scan/import/match/remove failures clearly.
- [x] 2.4 Confirm index removal and preserve local files.

## 3. Validation

- [x] 3.1 Update media-library widget tests and helper tests.
- [x] 3.2 Run `dart analyze`, targeted Flutter tests, changed-test gate, and
  `openspec.cmd validate --all`.
