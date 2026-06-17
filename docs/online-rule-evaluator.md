# Step 48 Online Rule Evaluator

Step 48 turns the online rule runtime's supplied-document evaluation from
contract scaffolding into bounded real behavior.

The evaluator lives inside `lib/src/provider/online/online_rule_runtime.dart`
and is consumed through existing `DeterministicOnlineRuleRuntime` and
`OnlineRuleSourceRuntime` APIs. UI-owned rule-source screens should call those
typed validation/evaluation surfaces and render the resulting projections.

## Supported Extraction

- Regex: Dart `RegExp`, returning the first capture group when present or the
  full match otherwise.
- CSS selector subset: tag, `.class`, `#id`, attribute presence/equality, and
  descendant combinators.
- XPath subset: `//tag`, `//*[@id="..."]`, `//tag[@attr="..."]`, and simple
  child paths such as `//section[@id="detail"]/a`.
- Output: declared `attribute` value when present, otherwise normalized element
  text.

Unsupported selector syntax is reported as
`UnsupportedOnlineOperationKind.unsupportedSelector`.

## Boundary

This slice does not fetch pages. Callers supply the document string. Future page
retrieval must stay behind ProviderGateway and network-policy contracts.

This slice also does not implement UI, WebView challenge handling, captcha
automation, source-specific scrapers, JavaScript/WASM/scriptlet execution, RSS
auto-download, BT integration, or diagnostics actions.

## UI Integration Note

UI-owned rule-source management can preview rules by:

1. Building or loading an `OnlineRuleManifest`.
2. Calling `OnlineRuleSourceRuntime.validate(scopeId, manifest)`.
3. Supplying a document string to
   `OnlineRuleSourceRuntime.evaluate(scopeId, request)`.
4. Rendering `OnlineRuleSourceRuntimeProjection.latestNormalizedOutput`,
   `latestFailure`, and validation issues.

UI code should not import parser internals, crawler implementations, browser
handles, concrete network clients, or source-specific rule code.
