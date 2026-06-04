## 1. Storage cache contracts

- [x] 1.1 Add subtitle cache storage domain, search-result cache records, content cache records, and TTL invariants. Layers: Storage
- [x] 1.2 Expose subtitle cache responsibilities through `StorageFoundation` without adding UI, native, or network dependencies. Layers: Storage

## 2. Domain subtitle discovery

- [x] 2.1 Add Domain-facing subtitle discovery result types for local scanner candidates and provider candidates. Layers: Domain, Playback, Provider
- [x] 2.2 Add subtitle discovery orchestration contracts that compose local subtitle scanner results, provider search, cache lookup, retrieval, and parser handoff. Layers: Domain, Provider, Storage, Playback
- [x] 2.3 Preserve provider retrieval metadata and encoding hints through parser handoff. Layers: Domain, Playback

## 3. Verification and guardrails

- [x] 3.1 Add deterministic subtitle cache and discovery test doubles for contract tests. Layers: Storage, Domain
- [x] 3.2 Add tests for cache hit/miss behavior, TTL expiry, local/provider discovery result composition, and retrieval-to-parser handoff. Layers: Test
- [x] 3.3 Update checker/runtime validation for subtitle cache and discovery contracts. Layers: Tools
