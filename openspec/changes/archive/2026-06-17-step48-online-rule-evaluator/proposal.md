# Step48 Online Rule Evaluator

## Summary

Implement a concrete supplied-document evaluator for online rule manifests so
CSS selector, XPath 1.0 subset, and regex extraction operations evaluate real
document content instead of marker-style placeholder data.

This remains a Provider-layer runtime implementation slice. It does not add UI,
network fetching, WebView challenge handling, captcha automation, source-specific
scrapers, RSS automation, BT download, or arbitrary script execution.

## Why

The Step 27 online rule runtime acceptance layer defines typed manifests,
capabilities, storage projections, and unsupported-operation outcomes, but the
deterministic evaluator still treats CSS/XPath operations as output-key markers.
That is useful for contract scaffolding, not for real rule source validation.

Step 48 moves the implementation toward real feature behavior by evaluating
declarative extraction operations against supplied HTML/XML-like documents while
preserving optionality and layer boundaries.

## What Changes

- Add a bounded concrete document evaluator for:
  - regex extraction through Dart `RegExp`
  - CSS selector subset: tag, class, id, attribute presence/equality, and
    descendant combinators
  - XPath subset: `//tag`, `//*[@id="..."]`, `//tag[@attr="..."]`, and simple
    child paths
- Support text extraction and declared attribute extraction.
- Reject unsupported selector syntax through typed validation issues using
  `UnsupportedOnlineOperationKind.unsupportedSelector`.
- Keep JavaScript, WASM, scriptlets, arbitrary code, browser execution,
  concrete HTTP fetching, WebView, network policy, diagnostics, UI, BT, and
  RSS auto-download outside the change.
- Add tests, checker coverage, docs, OpenSpec validation, and archive.

## Non-Goals

- No `lib/src/ui/**`, `lib/main.dart`, or `windows/**` edits.
- No crawler, WebView, browser DOM, JavaScript, WASM, or captcha support.
- No ProviderGateway page retrieval implementation.
- No source-specific yuc.wiki behavior.
- No RSS auto-download or BT enqueue integration.
