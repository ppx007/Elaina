## ADDED Requirements

### Requirement: Online rule source runtime SHALL remain separate from the test harness
The online rule source runtime SHALL remain the storage-backed runtime
acceptance layer, while the Step 49 test harness remains a non-persistent
caller-supplied-document helper.

#### Scenario: Harness test run executes
- **WHEN** a rule-source test plan is run
- **THEN** it does not mutate `OnlineRuleRuntimeStore`, publish cache
  invalidation events, disable or reenable manifests, or replace
  `OnlineRuleSourceRuntime` projections

### Requirement: Online rule test harness SHALL preserve source runtime boundaries
The Step 49 harness SHALL NOT add gateway page retrieval, network fetch,
WebView challenge handling, captcha solving, DNS/proxy behavior, diagnostics
actions, Flutter UI, yuc.wiki special-casing, libtorrent bindings, RSS
auto-download, or app-shell dependencies.

#### Scenario: Boundary checker scans Step 49 files
- **WHEN** Step 49 runtime, tests, tools, and docs are scanned
- **THEN** concrete UI, WebView, network fetch, captcha, BT, RSS auto-download,
  diagnostics actions, and source-specific scraper dependencies are absent
