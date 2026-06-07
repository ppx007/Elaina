## 1. Storage and State Contracts

- [x] 1.1 Add Storage-layer records for fallback adapter candidates, active fallback configuration, fallback selection history, and latest fallback strategy state metadata.
- [x] 1.2 Add a `FallbackAdapterStore` interface and deterministic in-memory store following existing Storage contract patterns.
- [x] 1.3 Expose fallback adapter persistence through `StorageDomain`, `StorageFoundation`, and public barrel exports.

## 2. Fallback Strategy Contract Deepening

- [x] 2.1 Extend fallback adapter contracts with typed registration, evaluation, selection, disable, and capability-reevaluation outcomes/failures.
- [x] 2.2 Implement a deterministic fallback strategy that evaluates normalized playback failures, source compatibility, candidate priority, fallback enablement, and candidate capability reports without concrete VLC, native plugin, FFI, media-kit, or libmpv dependencies.
- [x] 2.3 Add read models for hidden fallback capabilities and explicit unsupported reasons after fallback selection.

## 3. Invalidation and Capability Gating

- [x] 3.1 Add fallback adapter invalidation events for registration, deregistration, capability reevaluation, selection changes, disablement, rejection, and state transitions.
- [x] 3.2 Refine capability matrix handling so fallback adapter support and hidden capability reasons remain explicit.
- [x] 3.3 Update advanced playback checker rules and Phase 5 documentation to enforce Step 25 boundaries and forbidden implementation dependencies.

## 4. Verification

- [x] 4.1 Add focused tests for fallback storage, typed registration, deterministic selection, no-candidate rejection, disabled fallback rejection, hidden capability reporting, and invalidation publication.
- [x] 4.2 Update runtime validation to exercise the fallback adapter contract and guard against forbidden dependencies.
- [x] 4.3 Run `openspec validate "vlc-fallback-adapter-contract" --strict`, `openspec validate --all`, `dart analyze`, focused Flutter tests, `dart tools/player_core_runtime_check.dart`, and Phase 5 checker scripts.
