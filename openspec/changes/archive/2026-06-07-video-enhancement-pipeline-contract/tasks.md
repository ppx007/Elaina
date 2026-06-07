## 1. Storage and State Contracts

- [x] 1.1 Add Storage-layer records for video enhancement profiles, active profile selection, and latest pipeline state metadata.
- [x] 1.2 Add an `EnhancementProfileStore` interface and deterministic in-memory store following existing Storage contract patterns.
- [x] 1.3 Expose video enhancement persistence through `StorageDomain`, `StorageFoundation`, and public barrel exports.

## 2. Pipeline Contract Deepening

- [x] 2.1 Extend `VideoEnhancementPipeline` contracts with typed evaluation, apply, disable, and degradation-request outcomes/failures.
- [x] 2.2 Implement a deterministic pipeline evaluator that checks declarative profile intent against adapter/platform capability reports without concrete MPV, shader, FFI, or native renderer dependencies.
- [x] 2.3 Add render-budget pressure and degradation target read models for future AVSyncGuard consumption without implementing AVSyncGuard policy.

## 3. Invalidation and Capability Gating

- [x] 3.1 Add video enhancement invalidation events for profile changes, capability reevaluation, and pipeline state transitions.
- [x] 3.2 Refine capability matrix handling so scaler, HDR tone mapping, deband filtering, and Anime4K-style preset support remain explicit and reasoned.
- [x] 3.3 Update advanced playback checker rules and Phase 5 documentation to enforce Step 22 boundaries and forbidden implementation dependencies.

## 4. Verification

- [x] 4.1 Add focused tests for profile storage, deterministic profile evaluation, unsupported capability rejection, apply/disable outcomes, budget pressure reporting, and invalidation publication.
- [x] 4.2 Update runtime validation to exercise the video enhancement pipeline contract and guard against forbidden dependencies.
- [x] 4.3 Run `openspec validate "video-enhancement-pipeline-contract" --strict`, `openspec validate --all`, `dart analyze`, `flutter test`, `dart tools/player_core_runtime_check.dart`, and Phase 5 checker scripts.
