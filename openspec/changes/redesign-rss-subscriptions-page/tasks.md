## 1. Specification

- [x] 1.1 Create change `redesign-rss-subscriptions-page`.
- [x] 1.2 Add spec deltas for RSS page behavior and persisted item projection.

## 2. Runtime Projection

- [x] 2.1 Load persisted accepted feed items into `RssEngineRuntimeSnapshot`
  when registry snapshots are refreshed.
- [x] 2.2 Keep source removal and refresh snapshots consistent after persisted
  item projection is added.

## 3. UI Redesign

- [x] 3.1 Replace the current RSS page layout with toolbar, summary metrics,
  source list, source detail, and filtered item stream.
- [x] 3.2 Add remove-source confirmation, per-source refresh, refresh-all, and
  auto-download controls.
- [x] 3.3 Fix RSS page and add-dialog Chinese text to valid UTF-8.

## 4. Validation

- [x] 4.1 Add runtime regression coverage for persisted accepted items in
  snapshots.
- [x] 4.2 Update RSS widget tests for add, validation, refresh/filter/list, and
  removal flows.
- [x] 4.3 Run Dart analysis, focused Flutter tests, OpenSpec validation, and
  fast changed-test gate.
