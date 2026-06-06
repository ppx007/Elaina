## 1. Storage and State Contracts

- [x] 1.1 Add Storage-layer records for AV sync policy configuration, latest health state, sample history metadata, and degradation decision history.
- [x] 1.2 Add an `AVSyncGuardStore` interface and deterministic in-memory store following existing Storage contract patterns.
- [x] 1.3 Expose AV sync guard persistence through `StorageDomain`, `StorageFoundation`, and public barrel exports.

## 2. Guard Contract Deepening

- [x] 2.1 Extend `AVSyncGuard` contracts with typed sample evaluation, health transition, degradation-request, and recovery outcomes/failures.
- [x] 2.2 Implement a deterministic AV sync guard that evaluates normalized samples against target, warning, red-line, recovery, and sample-window policy without concrete MPV, FFI, native renderer, or diagnostics dependencies.
- [x] 2.3 Add read models that consume `RenderBudgetInput` and enhancement pressure data from `VideoEnhancementPipeline` while keeping AVSyncGuard as the drift/degradation policy owner.

## 3. Invalidation and Capability Gating

- [x] 3.1 Add AV sync invalidation events for sample ingestion, health transitions, degradation decisions, and recovery updates.
- [x] 3.2 Refine capability matrix handling so `avSyncGuard` support and unsupported reasons remain explicit before automatic degradation appears executable.
- [x] 3.3 Update advanced playback checker rules and Phase 5 documentation to enforce Step 23 boundaries and forbidden implementation dependencies.

## 4. Verification

- [x] 4.1 Add focused tests for guard storage, sustained sample-window evaluation, warning/degraded/recovery transitions, deterministic degradation ordering, enhancement pressure handoff, unsupported capability rejection, and invalidation publication.
- [x] 4.2 Update runtime validation to exercise the AV sync guard contract and guard against forbidden dependencies.
- [x] 4.3 Run `openspec validate "av-sync-guard-contract" --strict`, `openspec validate --all`, `dart analyze`, `flutter test`, `dart tools/player_core_runtime_check.dart`, and Phase 5 checker scripts.
