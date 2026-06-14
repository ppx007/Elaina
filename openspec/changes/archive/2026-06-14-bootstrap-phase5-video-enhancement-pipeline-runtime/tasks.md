## 1. Runtime Test Lock-In

- [x] 1.1 Add focused RED tests for Step 22 runtime bootstrap, supported profile evaluation/application, active profile replay, latest pipeline state replay, budget pressure, and degradation target projection in `test/playback/video_enhancement_pipeline_runtime_test.dart`.
- [x] 1.2 Add focused RED tests for unsupported capabilities, missing profile, rejected profile, unavailable runtime, and disposed runtime typed outcomes.
- [x] 1.3 Add focused RED tests proving profile, capability, and pipeline invalidations are observed only after storage-visible state.
- [x] 1.4 Run the new runtime test before implementation and capture expected RED evidence for missing runtime/bootstrap symbols or behavior.

## 2. Runtime and Projection Implementation

- [x] 2.1 Add `lib/src/playback/video_enhancement_pipeline_runtime.dart` with `VideoEnhancementPipelineBootstrap`, `VideoEnhancementPipelineRuntime`, typed runtime action results, failure kinds, immutable projections, and restart projection types.
- [x] 2.2 Implement runtime evaluate/apply/disable/degradation/snapshot/dispose behavior around existing deterministic pipeline, capability matrix, enhancement profile store, cache invalidation bus, and injected clock.
- [x] 2.3 Implement unavailable and disposed runtime gates that return typed outcomes without mutating storage or invoking native renderer behavior.
- [x] 2.4 Reconstruct active profile, latest pipeline state, support status, failure reason, render budget pressure, and degradation target from storage-safe contracts.
- [x] 2.5 Publish enhancement invalidations only after corresponding profile or pipeline state is readable through storage or runtime projection contracts.
- [x] 2.6 Export the Step 22 runtime/bootstrap surface from `lib/celesteria.dart`.

## 3. Contract Preservation and Storage Boundaries

- [x] 3.1 Preserve existing `VideoEnhancementPipeline` and `EnhancementProfileStore` contract behavior without speculative storage widening.
- [x] 3.2 Keep runtime storage access through `EnhancementProfileStore` only, with no concrete database, shader file, renderer, native plugin, or platform storage dependency.
- [x] 3.3 Keep render-budget pressure and degradation target as data handoff only, without implementing AVSyncGuard drift thresholds, guard health transitions, or ordered degradation policy.
- [x] 3.4 Run existing video enhancement and AVSyncGuard contract tests with the new runtime tests.

## 4. Runtime Validation Tooling

- [x] 4.1 Add `tools/video_enhancement_pipeline_runtime_check.dart` covering bootstrap, supported apply, unsupported evaluation, restart replay, budget pressure, degradation target, invalidation ordering, unavailable runtime, and disposed runtime behavior.
- [x] 4.2 Add `tools/check_video_enhancement_pipeline_runtime.ps1` that runs the Dart smoke checker, verifies required runtime/export terms, and rejects concrete renderer, shader, platform, UI, diagnostics, network/RSS, captions, fallback, and AVSyncGuard policy leakage.
- [x] 4.3 Run `dart run tools/video_enhancement_pipeline_runtime_check.dart` successfully.
- [x] 4.4 Run `powershell -ExecutionPolicy Bypass -File tools/check_video_enhancement_pipeline_runtime.ps1` successfully.

## 5. Quality Gates

- [x] 5.1 Run `flutter test test/playback/video_enhancement_pipeline_contract_test.dart test/playback/av_sync_guard_contract_test.dart test/playback/video_enhancement_pipeline_runtime_test.dart` successfully.
- [x] 5.2 Run `dart analyze` successfully.
- [x] 5.3 Run `openspec validate "bootstrap-phase5-video-enhancement-pipeline-runtime" --strict` successfully.
- [x] 5.4 Run `openspec validate --all` successfully.

## 6. Scope Guard

- [x] 6.1 Verify Step 22 runtime, tests, and checker do not introduce concrete MPV/VLC/media-kit bindings, shader bundle execution, FFI, platform channels, or native renderer integrations.
- [x] 6.2 Verify Step 22 runtime does not implement AVSyncGuard drift policy, health transitions, ordered degradation execution, diagnostics behavior, network/RSS automation, WebView handling, captions, fallback adapter behavior, or Flutter rendering.
- [x] 6.3 Confirm OpenSpec apply progress is complete and all tasks are checked only after matching evidence exists.
