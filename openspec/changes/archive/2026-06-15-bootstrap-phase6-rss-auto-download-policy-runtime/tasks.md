## Step 26: RSS Auto-Download Policy Runtime Bootstrap

### 1. RED — Failing Tests
- [x] 1.1 Create `test/provider/rss/rss_auto_download_runtime_test.dart` with initial snapshot test
- [x] 1.2 Add evaluate success test
- [x] 1.3 Add handoff success test
- [x] 1.4 Add disable/reenable tests
- [x] 1.5 Add unsupported capability test (policyEvaluation + btTaskHandoff)
- [x] 1.6 Add unavailable runtime rejects all ops test
- [x] 1.7 Add disposed runtime rejects snapshot test
- [x] 1.8 Add invalidation events ordering test
- [x] 1.9 Add restart projection replay test
- [x] 1.10 Add domain failure mapping test (automationDisabled, policyDisabled, deduplicated)
- [x] 1.11 Verify tests fail on missing runtime symbols

### 2. GREEN — Implementation
- [x] 2.1 Add `DeterministicRssAutomationHistoryStore` to `lib/src/foundation/storage/rss_auto_download_policy_storage_contracts.dart`
- [x] 2.2 Create `lib/src/provider/rss/rss_auto_download_runtime.dart` with full runtime/bootstrap/projection/ActionResult implementation
- [x] 2.3 Add barrel export `export 'src/provider/rss/rss_auto_download_runtime.dart';` in `lib/elaina.dart`

### 3. Contract Verification
- [x] 3.1 Run focused Flutter tests — expect all pass
- [x] 3.2 Run `dart analyze` on runtime file — expect clean
- [x] 3.3 Verify LSP diagnostics clean on runtime, test, and barrel files
- [x] 3.4 Verify `DeterministicRssAutomationHistoryStore` import does not create circular dependency

### 4. Validation Checkers
- [x] 4.1 Add `tools/rss_auto_download_runtime_check.dart` Dart smoke checker
- [x] 4.2 Add `tools/check_rss_auto_download_runtime.ps1` PowerShell boundary checker
- [x] 4.3 Run Dart smoke checker — expect exit 0
- [x] 4.4 Run PowerShell boundary checker — expect 'RSS auto-download policy runtime checks passed.'

### 5. Validation Gates
- [x] 5.1 Run focused Flutter tests (contract + runtime)
- [x] 5.2 Run `dart analyze` — expect no issues
- [x] 5.3 Run `openspec validate "bootstrap-phase6-rss-auto-download-policy-runtime" --strict` — expect valid
- [x] 5.4 Run `openspec validate --all` — expect all pass

### 6. Scope Guard & Completion
- [x] 6.1 Scope guard: scan runtime/test/checker for forbidden boundary terms (FeedFetcher, FeedParser, libtorrent, WebView, captcha, DNS, proxy, diagnostics, online_rule, Flutter widgets) — expect no hits
- [x] 6.2 Mark all tasks complete in this file
- [x] 6.3 Verify `openspec instructions apply` reports `state: all_done`
