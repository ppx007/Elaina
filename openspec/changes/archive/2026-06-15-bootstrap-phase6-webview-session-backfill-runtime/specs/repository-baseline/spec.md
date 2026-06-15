## ADDED Requirements

### Requirement: Repository baseline SHALL record Step 28 WebView session backfill runtime boundary
The repository baseline SHALL record that Step 28 adds a WebView session backfill runtime acceptance layer with bootstrap composition, typed outcomes, store-backed projections, restart replay, manual-only gates, and same-origin artifact replay.

#### Scenario: Step 28 runtime boundary is documented
- **WHEN** future work references Phase 6 WebView verification backfill
- **THEN** the repository baseline identifies `WebViewSessionBackfillRuntimeBootstrap`, `WebViewSessionBackfillRuntime`, runtime action results, projections, and boundary checkers as the Step 28 scope

### Requirement: Repository baseline SHALL validate Step 28 no-automation scope
The repository baseline SHALL require validation that Step 28 runtime files reject automatic captcha solving, challenge bypass, credential guessing, bot completion, headless automation, hidden browser interaction, shared profile cookie access, cross-origin reuse, concrete WebView plugins, Flutter UI, diagnostics behavior, network policy execution, RSS, BT, online-rule, native, FFI, and platform channel dependencies.

#### Scenario: Step 28 checker rejects automation leakage
- **WHEN** Step 28 validation scans runtime files
- **THEN** forbidden automation, UI, diagnostics, network, and unrelated runtime terms fail validation before archive
