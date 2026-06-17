## ADDED Requirements

### Requirement: Online rule source runtime SHALL use Step 48 evaluator behavior through existing projections
The online rule source runtime SHALL continue to expose validation,
evaluation, normalized output, and restart projections through
`OnlineRuleSourceRuntime` while the underlying evaluator performs concrete
supplied-document extraction.

#### Scenario: Source runtime evaluates a supplied document
- **WHEN** `OnlineRuleSourceRuntime.evaluate()` receives a manifest with
  supported Step 48 CSS, XPath, or regex operations
- **THEN** the resulting projection stores the evaluation snapshot and exposes
  the normalized output through existing typed projection fields

### Requirement: Online rule source runtime SHALL preserve Step 48 boundaries
The Step 48 source runtime integration SHALL NOT add gateway page retrieval,
network fetch, WebView challenge handling, captcha solving, DNS/proxy behavior,
diagnostics actions, Flutter UI, yuc.wiki special-casing, libtorrent bindings,
RSS auto-download, or concrete app-shell dependencies.

#### Scenario: Boundary checker scans Step 48 files
- **WHEN** Step 48 runtime, tests, tools, and docs are scanned
- **THEN** concrete UI, WebView, network fetch, captcha, BT, RSS auto-download,
  and source-specific scraper dependencies are absent
