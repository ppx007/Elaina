# Step49 Online Rule Test Harness

## Why

Step 48 made supplied-document CSS, XPath, and regex evaluation real. The next
missing implementation layer is a small rule-source test harness that can
validate a manifest and run one or more supplied target documents as a single
report for rule-source management and preview flows.

Without this harness, consumers have to manually call validation, evaluation,
and normalization target-by-target, which encourages duplicated test glue and
UI-side special cases.

## What Changes

- Add a Provider-layer `OnlineRuleTestHarness`.
- Add simple test plan/document/report models around existing online rule
  manifests, targets, evaluation outcomes, and normalized outputs.
- Validate the manifest once, then evaluate supplied target documents only when
  validation succeeds.
- Preserve existing online rule runtime and source runtime contracts.
- Add focused tests, a non-UI smoke checker, docs, OpenSpec validation, archive,
  and grouped commits.

## Non-Goals

- No `lib/src/ui/**`, `lib/main.dart`, or `windows/**` edits.
- No UI rule test page, widgets, routing, or visual state composition.
- No page fetching, ProviderGateway dispatch, WebView, captcha, crawler,
  source-specific scraper, RSS auto-download, BT enqueue, diagnostics action,
  JavaScript, WASM, or arbitrary code execution.
