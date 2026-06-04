## 1. Storage feed persistence

- [x] 1.1 Add RSS feed storage domain, source records, item records, cursor records, and dedupe key records. Layers: Storage
- [x] 1.2 Expose feed source/item/cursor/dedupe responsibilities through `StorageFoundation` without adding UI, concrete network, or provider-owned persistence dependencies. Layers: Storage

## 2. Domain RSS engine orchestration

- [x] 2.1 Add Domain-facing RSS refresh request/result types that preserve source id, new items, warnings, and gateway-normalized failures. Layers: Domain, Provider
- [x] 2.2 Add RSS engine orchestration contracts that compose scheduler, fetcher, parser, deduplicator, Storage persistence, and update emission. Layers: Domain, Provider, Storage
- [x] 2.3 Preserve ETag and last-modified cursor metadata across refreshes and replay it into future `FeedFetchRequest` values. Layers: Domain, Provider, Storage
- [x] 2.4 Keep YucWiki seasonal normalization and RSS auto-download policy behavior outside the core RSS engine contract. Layers: Provider, Domain

## 3. Verification and guardrails

- [x] 3.1 Add deterministic feed storage and RSS engine test doubles for contract tests. Layers: Storage, Domain
- [x] 3.2 Add tests for feed registration, cursor reuse, parser handoff, deduplication, persistence, update emission, and provider failure propagation. Layers: Test
- [x] 3.3 Update checker/runtime validation for RSS engine contracts and layer boundaries. Layers: Tools
