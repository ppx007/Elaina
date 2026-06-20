## Why

WebView session backfill is already defined as a manual-only contract layer, but there is no runtime acceptance layer that ties challenge detection, isolated completion, artifact capture, and retry replay together with store-backed projections. Step 28 adds that runtime boundary so provider flows can restore state after restart without introducing automatic captcha handling.

## What Changes

- Add a WebView session backfill runtime acceptance layer that wraps the existing contract and storage types.
- Add scoped runtime projections and restart projections for manual challenge state, captured artifacts, and backfill attempts.
- Add typed runtime outcomes for disposed, unavailable, unsupported-capability, and manual-flow failures.
- Add a runtime bootstrap that accepts per-scope backfill contracts, capability matrices, storage, and cache invalidation events.
- Add runtime tests and boundary checkers for manual-only challenge handling and same-origin artifact replay.
- Keep WebView challenge handling manual-only and same-origin scoped; do not add automatic captcha solving or headless automation.

## Capabilities

### New Capabilities
- `phase6-webview-session-backfill-runtime`: Runtime acceptance layer for manual WebView session backfill, challenge lifecycle replay, scoped artifact capture, and same-origin retry descriptor creation.
- `webview-session-backfill-contract`: Contract-level action result and boundary requirements for WebView session backfill runtime consumers.

### Modified Capabilities
- `webview-session-backfill`: Add runtime acceptance requirements for projections, replay, typed outcomes, and manual-only runtime gates.
- `cache-invalidation-bus`: Add WebView runtime invalidation events for challenge, artifact, backfill, and capability transitions.
- `local-storage-foundation`: Add runtime replay and persistence requirements for WebView session backfill store state.
- `repository-baseline`: Record the Step 28 runtime boundary and no-automation constraint.

## Impact

Affected code will include a new `lib/src/network/webview_session_backfill_runtime.dart` runtime, its barrel export in `lib/elaina.dart`, a focused runtime test, a Dart smoke checker, a PowerShell boundary checker, and the archived OpenSpec change artifacts after completion.
