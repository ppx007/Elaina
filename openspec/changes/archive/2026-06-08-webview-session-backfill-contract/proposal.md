## Why

Phase 6 Step 28 needs a contract slice for providers that require manual challenge completion before online rule or provider traffic can resume. The existing baseline names WebView session backfill, but it does not yet define the typed storage, gateway, network, invalidation, and capability boundaries needed to implement it safely.

## What Changes

- Define WebView session backfill as a manual-only provider/origin-scoped session capture and retry contract.
- Add durable contracts for challenge requests, normalized session artifacts, backfill attempts, capability state, and expiry/revocation metadata.
- Route challenge retries through ProviderGateway and network policy boundaries instead of allowing providers to read global browser state or bypass gateway governance.
- Publish explicit invalidation events for challenge lifecycle, artifact capture, backfill outcome, and capability changes.
- Keep this as contract scaffolding only: no captcha auto-solving, no challenge bypass, no WebView UI implementation, no crawler automation, and no global browser cookie access.

## Capabilities

### New Capabilities

### Modified Capabilities

- `webview-session-backfill`: Deepen the manual challenge/session backfill contract with typed lifecycle, artifact normalization, expiry, revocation, and capability behavior.
- `local-storage-foundation`: Add Storage-layer responsibilities for WebView challenge requests, session artifacts, backfill attempts, and capability state.
- `provider-gateway`: Require backfilled provider retries to remain governed by ProviderGateway registration, rate limits, retries, cache policy, and normalized failure semantics.
- `network-policy-boundary`: Require WebView challenge origins and backfill retries to be checked by provider-scoped network policy and SSRF protections.
- `cache-invalidation-bus`: Add explicit invalidation events for WebView challenge/backfill state changes.

## Impact

- Affected layers: Provider, Gateway, Storage, Network, and cache invalidation contracts.
- Expected code impact: Dart contract types for WebView challenge/session backfill, deterministic storage/read-model scaffolding, gateway/network descriptors, invalidation event types, focused tests, and boundary checker updates.
- No new runtime dependency is required in this proposal; concrete platform WebView adapters remain future work.
