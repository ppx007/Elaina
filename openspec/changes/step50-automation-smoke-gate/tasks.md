## 1. OpenSpec

- [x] 1.1 Create change `step50-automation-smoke-gate`.
- [x] 1.2 Add spec deltas for the automation smoke gate and boundaries.
- [x] 1.3 Run `openspec.cmd instructions apply --change "step50-automation-smoke-gate" --json`.

## 2. Smoke Gate

- [x] 2.1 Add a non-UI automation smoke gate tool.
- [x] 2.2 Compose concrete RSS fetch/parse through the seasonal feed flow.
- [x] 2.3 Compose `OnlineRuleTestHarness` with supplied target documents.
- [x] 2.4 Keep the gate deterministic and avoid RSS auto-download, BT, WebView, live network, or UI work.

## 3. Boundaries

- [x] 3.1 Keep UI, app shell, WebView, captcha, crawler, source-specific scraper, native player, RSS auto-download handoff, BT, and diagnostics actions outside the change.
- [x] 3.2 Reuse existing runtime/test-harness contracts instead of adding duplicate lifecycle or failure semantics.
- [x] 3.3 Keep sample constants local and named rather than scattering magic values.

## 4. Tests And Checkers

- [x] 4.1 Add focused test coverage for the smoke gate result.
- [x] 4.2 Add a PowerShell checker that runs the focused test and tool.
- [x] 4.3 Wire the smoke gate checker into the automation extension core checker.
- [x] 4.4 Add integration notes for UI-owned automation pages without editing UI files.

## 5. Validation And Archive

- [x] 5.1 Run focused automation smoke gate tests and checker.
- [x] 5.2 Run `openspec.cmd validate "step50-automation-smoke-gate" --strict`.
- [x] 5.3 Run baseline validation gates.
- [ ] 5.4 Archive the OpenSpec change.
- [ ] 5.5 Re-run `openspec.cmd validate --all` and report git status.
