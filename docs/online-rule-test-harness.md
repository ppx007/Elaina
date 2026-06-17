# Step 49 Online Rule Test Harness

Step 49 adds a small Provider-layer harness for testing online rule manifests
against caller-supplied documents.

The harness is intentionally not a crawler, WebView bridge, page fetcher, or UI
state manager. It only coordinates existing online rule validation, evaluation,
and normalization contracts into one report.

## Contract

- `OnlineRuleTestDocument`: target, page URI, and supplied document content.
- `OnlineRuleTestPlan`: manifest plus documents to test.
- `OnlineRuleTestTargetReport`: per-target evaluation outcome and normalized
  output when evaluation succeeds.
- `OnlineRuleTestReport`: validation result and ordered target reports.
- `OnlineRuleTestHarness`: validates once, short-circuits invalid manifests,
  then evaluates supplied documents in order.

## UI Integration Note

UI-owned rule-source test pages should:

1. Build or load an `OnlineRuleManifest`.
2. Collect sample documents from user input, fixture files, or a future
   ProviderGateway-owned page retrieval flow.
3. Run `OnlineRuleTestHarness.run(...)`.
4. Render validation issues, target failures, and normalized output from the
   typed report.

UI code should not import parser internals, crawler implementations, WebView
handles, concrete network clients, source-specific scrapers, or storage
implementations.

## Boundary

This slice does not fetch pages or persist test reports. Future page retrieval
must stay behind ProviderGateway and network-policy contracts. This slice also
does not add Flutter pages, WebView challenge handling, captcha automation,
JavaScript/WASM/scriptlet execution, RSS auto-download, BT integration, or
diagnostics actions.
