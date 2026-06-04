## 1. Domain and Storage contracts

- [x] 1.1 Extend the Domain media catalog surface with persistence contracts for media items, batch imports, playback history, and provider binding state. Layers: Domain
- [x] 1.2 Extend the Storage foundation with first-class media library, playback history, and provider binding accessors. Layers: Storage
- [x] 1.3 Define import result and deduplication value objects for scan-to-library persistence. Layers: Domain

## 2. Catalog persistence behavior

- [x] 2.1 Add repository contracts for storing, querying, updating, listing, and removing `MediaLibraryItem` values. Layers: Domain, Storage
- [x] 2.2 Add a batch import contract that converts `MediaScanCandidate` values into persistent catalog items with deterministic duplicate handling. Layers: Domain
- [x] 2.3 Add verification tests for catalog CRUD, listing, and import deduplication rules. Layers: Domain, Test

## 3. History, binding, and invalidation

- [x] 3.1 Add storage-backed playback history contracts that record progress and derive continue-watching state from persisted entries. Layers: Domain, Storage
- [x] 3.2 Add storage-backed provider binding contracts that preserve user-confirmed authority and support persisted lookup. Layers: Domain, Storage
- [x] 3.3 Extend cache invalidation events for library item and history mutations, and wire repository mutations to publish them. Layers: Foundation, Storage
- [x] 3.4 Add verification tests for playback history persistence, binding persistence, and cache invalidation events. Layers: Domain, Foundation, Test
