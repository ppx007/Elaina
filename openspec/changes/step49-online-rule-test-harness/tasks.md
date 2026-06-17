## 1. OpenSpec

- [x] 1.1 Create change `step49-online-rule-test-harness`.
- [x] 1.2 Add spec deltas for rule-source test harness behavior and boundaries.
- [x] 1.3 Run `openspec.cmd instructions apply --change "step49-online-rule-test-harness" --json`.

## 2. Core Harness

- [x] 2.1 Add Provider-layer rule-source test plan, supplied document, target report, and run report models.
- [x] 2.2 Add `OnlineRuleTestHarness` that validates a manifest once and evaluates supplied target documents.
- [x] 2.3 Reuse existing `DeterministicOnlineRuleRuntime`, `OnlineRuleEvaluationOutcome`, and normalized output contracts.
- [x] 2.4 Keep the harness non-persistent and caller-supplied-document only.

## 3. Boundaries

- [x] 3.1 Keep UI, app shell, WebView, captcha, network fetch, ProviderGateway dispatch, RSS auto-download, BT, diagnostics, and source-specific scrapers outside the change.
- [x] 3.2 Keep JavaScript, WASM, scriptlet, and arbitrary code operations rejected through existing validation.
- [x] 3.3 Avoid new lifecycle state machines, duplicate runtime contracts, or magic thresholds.

## 4. Tests And Checkers

- [x] 4.1 Add focused tests for successful multi-target harness reports.
- [x] 4.2 Add focused tests for invalid manifest short-circuiting.
- [x] 4.3 Add focused tests for target evaluation failures surfacing typed outcomes.
- [x] 4.4 Add a non-UI smoke checker and PowerShell boundary checker.
- [x] 4.5 Add integration notes for UI-owned rule-source test pages without editing UI files.

## 5. Validation And Archive

- [x] 5.1 Run focused online rule harness tests and checker.
- [x] 5.2 Run `openspec.cmd validate "step49-online-rule-test-harness" --strict`.
- [x] 5.3 Run baseline validation gates.
- [ ] 5.4 Archive the OpenSpec change.
- [ ] 5.5 Re-run `openspec.cmd validate --all` and report git status.
