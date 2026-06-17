## 1. OpenSpec

- [x] 1.1 Create change `step44-playback-history-integration`.
- [x] 1.2 Add spec deltas for playback history integration and layer boundaries.
- [x] 1.3 Run `openspec.cmd instructions apply --change "step44-playback-history-integration" --json`.

## 2. Playback History Integration

- [x] 2.1 Add a non-UI playback history recorder that consumes playback state snapshots.
- [x] 2.2 Resolve `PlaybackStateSnapshot.sourceUri` to a media-library catalog item before writing history.
- [x] 2.3 Persist history through `PlaybackHistoryStore` and publish `HistoryRecorded` events.
- [x] 2.4 Add an observer wrapper for `PlaybackControllerContract` / `PlaybackStateObservable` composition.
- [x] 2.5 Keep UI, concrete player, SQLite, SQL, provider, RSS, BT, network, and diagnostics details out of the Domain media integration surface.

## 3. Tests, Tools, Docs

- [x] 3.1 Add focused tests for snapshot-to-history recording.
- [x] 3.2 Add SQLite-backed restart/replay tests proving persisted continue-watching state.
- [x] 3.3 Extend media-library runtime checker for Step 44 integration boundaries.
- [x] 3.4 Add non-UI smoke checker coverage for playback history integration.
- [x] 3.5 Add Step 44 integration docs.

## 4. Validation And Archive

- [x] 4.1 Run focused playback-history tests and checker.
- [x] 4.2 Run `openspec.cmd validate "step44-playback-history-integration" --strict`.
- [x] 4.3 Run baseline validation gates.
- [x] 4.4 Archive the OpenSpec change.
- [x] 4.5 Re-run `openspec.cmd validate --all` and report git status.
