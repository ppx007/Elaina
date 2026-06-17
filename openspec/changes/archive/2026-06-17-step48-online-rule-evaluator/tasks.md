## 1. OpenSpec

- [x] 1.1 Create change `step48-online-rule-evaluator`.
- [x] 1.2 Add spec deltas for concrete supplied-document evaluation and boundaries.
- [x] 1.3 Run `openspec.cmd instructions apply --change "step48-online-rule-evaluator" --json`.

## 2. Core Evaluator

- [x] 2.1 Add a bounded document evaluator for regex, CSS selector subset, and XPath subset.
- [x] 2.2 Support text extraction and declared attribute extraction.
- [x] 2.3 Validate unsupported selector syntax as typed `unsupportedSelector` issues.
- [x] 2.4 Preserve existing online rule runtime contracts and normalized output models.

## 3. Boundaries

- [x] 3.1 Keep UI, app shell, WebView, captcha, network fetch, ProviderGateway page retrieval, RSS auto-download, BT, diagnostics, and source-specific scrapers outside the change.
- [x] 3.2 Keep JavaScript, WASM, scriptlet, and arbitrary code operations rejected.
- [x] 3.3 Avoid new inline magic values for selector grammar and output behavior.

## 4. Tests And Checkers

- [x] 4.1 Add focused tests for real CSS selector evaluation.
- [x] 4.2 Add focused tests for real XPath subset evaluation.
- [x] 4.3 Add focused tests for regex extraction and unsupported selector validation.
- [x] 4.4 Extend the online rule checker and smoke tool to cover Step48 evaluator behavior.
- [x] 4.5 Add integration notes for UI-owned rule-source screens without editing UI files.

## 5. Validation And Archive

- [x] 5.1 Run focused online rule tests and checker.
- [x] 5.2 Run `openspec.cmd validate "step48-online-rule-evaluator" --strict`.
- [x] 5.3 Run baseline validation gates.
- [x] 5.4 Archive the OpenSpec change.
- [x] 5.5 Re-run `openspec.cmd validate --all` and report git status.
