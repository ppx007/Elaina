## 1. Contract Models

- [x] 1.1 Add WebView challenge/session backfill contract types in the Provider layer for provider id, origin scope, lifecycle state, artifact metadata, expiry, revocation, failures, and capability status.
- [x] 1.2 Add normalized cookie and optional provider-token artifact records without exposing global browser state or concrete WebView APIs.
- [x] 1.3 Add declarative retry/session descriptors that can be consumed by ProviderGateway without provider-owned transport bypass.

## 2. Storage and Events

- [x] 2.1 Add Storage-layer contracts and deterministic store scaffolding for challenge requests, artifacts, backfill attempts, retry outcomes, expiry/revocation state, and capability state.
- [x] 2.2 Export the new storage domain through the storage foundation contracts and public Dart contract barrel as appropriate.
- [x] 2.3 Add CacheInvalidationBus events for challenge lifecycle, artifact capture, backfill outcome, artifact expiry/revocation, and capability changes.

## 3. Gateway and Network Boundaries

- [x] 3.1 Add ProviderGateway-facing descriptors for backfilled retries that preserve provider registration, rate policy, retry policy, cache behavior, and normalized failures.
- [x] 3.2 Add Network-layer handoff descriptors for challenge navigation and backfilled retries with SSRF/security failure classification.
- [x] 3.3 Ensure contracts explicitly reject captcha solving, challenge bypass, headless automation, cross-origin artifact reuse, and direct global browser cookie access.

## 4. Validation

- [x] 4.1 Add focused tests for manual lifecycle, same-origin scoping, expiry/revocation, capability limits, storage persistence, invalidation events, gateway descriptors, and network-policy handoffs.
- [x] 4.2 Update Phase 6 automation boundary documentation and checker scripts to include WebView session backfill constraints.
- [x] 4.3 Run `openspec validate "webview-session-backfill-contract" --strict`, `openspec validate --all`, `dart analyze`, focused tests, and automation boundary checkers.
