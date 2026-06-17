# Step50 Automation Smoke Gate

## Why

Steps 46-49 made RSS fetch/parse, seasonal feed projection, online rule
evaluation, and online rule test reporting executable. The missing Phase D
closure is a small non-UI smoke gate proving these slices compose as an
automation path without asking UI code to stitch concrete fetchers, seasonal
queues, and rule-source harness calls together.

Without this gate, regressions can leave individual focused tests passing while
the RSS refresh -> seasonal index -> Bangumi match queue and supplied-document
online rule validation path drifts.

## What Changes

- Add a deterministic non-UI automation smoke gate tool.
- Compose the existing concrete RSS fetcher/parser with
  `SeasonalFeedFlowBootstrap`.
- Compose the existing `OnlineRuleTestHarness` with valid supplied search and
  detail documents.
- Assert the smoke path reaches accepted RSS items, seasonal catalog entries,
  pending Bangumi match work, and normalized online rule outputs.
- Add focused test coverage, a boundary checker, docs, OpenSpec validation,
  archive, and grouped commits.

## Non-Goals

- No `lib/src/ui/**`, `lib/main.dart`, or `windows/**` edits.
- No Flutter app shell, pages, widgets, RSS/source management screens, WebView
  screens, diagnostics screens, or UI state composition.
- No live network fetch, source-specific scraper, WebView, captcha automation,
  JavaScript, WASM, RSS auto-download handoff, BT enqueue, download engine,
  native player, or packaged app behavior.
- No replacement runtime/state machine for RSS, seasonal, or online-rule
  behavior.
