## 1. Storage and State Contracts

- [x] 1.1 Add Storage-layer records for advanced caption profiles, active feature selection, dual-subtitle preferences, and latest renderer state metadata.
- [x] 1.2 Add an `AdvancedCaptionStore` interface and deterministic in-memory store following existing Storage contract patterns.
- [x] 1.3 Expose advanced caption persistence through `StorageDomain`, `StorageFoundation`, and public barrel exports.

## 2. Advanced Caption Contract Deepening

- [x] 2.1 Extend `AdvancedCaptionRenderer` contracts with typed feature evaluation, render, disable, and degradation outcomes/failures.
- [x] 2.2 Implement a deterministic advanced caption evaluator that checks Matrix4 danmaku, dual subtitles, PGS rendering intent, and ASS enhancement intent against feature flags and capability reports without concrete Flutter, GPU, decoder, FFI, or native renderer dependencies.
- [x] 2.3 Add read models that consume AVSyncGuard `disableAdvancedCaptions` degradation decisions as declarative input without making AVSyncGuard own renderer mutation.

## 3. Invalidation and Capability Gating

- [x] 3.1 Add advanced caption invalidation events for feature changes, capability reevaluation, renderer state transitions, dual-subtitle selection, and degradation state changes.
- [x] 3.2 Refine capability matrix handling so `matrixDanmaku`, `dualSubtitles`, `pgsSubtitleRendering`, and `assSubtitleEnhancement` support and unsupported reasons remain explicit.
- [x] 3.3 Update advanced playback checker rules and Phase 5 documentation to enforce Step 24 boundaries and forbidden implementation dependencies.

## 4. Verification

- [x] 4.1 Add focused tests for advanced caption storage, feature evaluation, unsupported capability rejection, render/disable outcomes, dual-subtitle ordering, AVSyncGuard degradation acceptance, and invalidation publication.
- [x] 4.2 Update runtime validation to exercise the advanced caption rendering contract and guard against forbidden dependencies.
- [x] 4.3 Run `openspec validate "advanced-caption-rendering-contract" --strict`, `openspec validate --all`, `dart analyze`, `flutter test`, `dart tools/player_core_runtime_check.dart`, and Phase 5 checker scripts.
