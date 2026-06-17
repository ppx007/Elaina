# Automation Smoke Gate

Step 50 closes the non-UI Phase D automation path:

```text
RSS fetch/parse -> seasonal catalog -> Bangumi match queue
supplied online rule documents -> rule-source test report
```

The gate is intentionally small. It verifies that the Step 46 concrete RSS
fetcher/parser, Step 47 seasonal feed flow, and Step 49 online rule test
harness can be composed without adding UI code, live network crawling, WebView
behavior, RSS auto-download handoff, BT enqueueing, diagnostics actions, or
native playback.

## Runtime Composition

`tools/automation_smoke_gate.dart` builds the same pieces an app composition
root will eventually create:

- `HttpFeedFetcher` with a deterministic transport;
- `RssXmlFeedParser`;
- `SeasonalFeedFlowBootstrap`;
- `FeedItemSeasonalAnimeConsumer`;
- `OnlineRuleTestHarness`.

The RSS refresh is deterministic and supplied by the smoke tool. It still uses
the concrete fetcher/parser contracts, so accepted feed items, request headers,
seasonal catalog projection, and pending Bangumi match queue projection are
validated together.

The online rule portion uses caller-supplied search and detail documents. It
validates one manifest, evaluates both targets through the existing harness,
and checks normalized search/detail outputs.

## UI Boundary

UI-owned RSS, seasonal, and rule-source management pages should call existing
Domain/Provider runtime contracts. They should not import the smoke tool or
duplicate its setup as UI state.

The smoke gate does not implement:

- Flutter app shell, routing, pages, widgets, or visual state;
- WebView challenge screens or captcha automation;
- live source fetching, crawler behavior, or source-specific scraper behavior;
- RSS auto-download handoff or BT task creation;
- diagnostics controls or native player integration.

Run the focused gate with:

```powershell
powershell -ExecutionPolicy Bypass -File "tools\check_automation_smoke_gate.ps1"
```
