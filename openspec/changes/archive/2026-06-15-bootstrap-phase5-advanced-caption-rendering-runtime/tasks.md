## 1. RED Tests

- [x] 1.1 Create `test/playback/advanced_caption_rendering_runtime_test.dart` with `_RuntimeHarness` seeding `DeterministicAdvancedCaptionStore` with profile, active profile, renderer state for `adapter-1`; supported and unsupported capability maps; fixed clock `DateTime.utc(2026, 6, 15, 12)`
- [x] 1.2 Write test: initial `snapshot('adapter-1')` succeeds and replays active profile ID and stored renderer state via `AdvancedCaptionRuntimeRestartProjection`
- [x] 1.3 Write tests: `evaluate()` returns typed `AdvancedCaptionRuntimeActionResult<CaptionEvaluationOutcome>` with success kind on supported scope
- [x] 1.4 Write tests: `renderMatrixDanmaku()` and `renderDualSubtitles()` return typed success action results on supported scope
- [x] 1.5 Write test: `disable()` returns typed success action result on supported scope
- [x] 1.6 Write test: `acceptDegradation()` returns typed success action result for `disableAdvancedCaptions` action on supported scope
- [x] 1.7 Write tests: unsupported scope returns `capabilityUnsupported`, unavailable runtime rejects all ops, disposed runtime rejects snapshot
- [x] 1.8 Write test: invalidation events arrive in store-visibility order (capability reevaluated, profile changed, renderer state changed, dual subtitle selection changed, degradation state changed)
- [x] 1.9 Run focused tests and confirm all fail on missing runtime symbols (RED)

## 2. GREEN Implementation

- [x] 2.1 Create `lib/src/playback/advanced_caption_rendering_runtime.dart` importing cache_invalidation_bus, advanced_caption_storage_contracts, advanced_caption_rendering, capability_matrix
- [x] 2.2 Implement `AdvancedCaptionRuntimeBootstrap` with `captionStore`, unmodifiable `rendererByScope`, `capabilitiesByScope`, optional `cacheInvalidationBus`, `createRuntime()` factory
- [x] 2.3 Implement `AdvancedCaptionRuntimeFailureKind` enum: capabilityUnsupported, unavailable, disposed, featureDisabled, profileNotFound, dualSubtitleOrderRejected, staleEvaluation, avSyncDegradation
- [x] 2.4 Implement `AdvancedCaptionRuntimeFailure` and `AdvancedCaptionRuntimeActionResultKind` (success/failed/unavailable/disposed) with generic `AdvancedCaptionRuntimeActionResult<T>`
- [x] 2.5 Implement `AdvancedCaptionRuntimeRestartProjection` with `scopeId`, `activeProfileId`, `latestRendererState` (StoredAdvancedCaptionRendererStateKind?), `latestDegradationReason` (String?), `dualSubtitlePrimaryId` (String?), `dualSubtitleSecondaryId` (String?)
- [x] 2.6 Implement `AdvancedCaptionRuntimeProjection` combining in-memory latest report/failure + stored active profile/renderer state/dual subtitle
- [x] 2.7 Implement `AdvancedCaptionRuntime` with `.unavailable()` constructor, `_gate(scopeId)` checking disposed/unavailable/missing scope/unsupported capability
- [x] 2.8 Implement `snapshot(scopeId)` returning projection from stored + in-memory state
- [x] 2.9 Implement `evaluate()`, `renderMatrixDanmaku()`, `renderDualSubtitles()`, `renderAdvancedSubtitle()`, `disable()`, `acceptDegradation()` delegating to per-scope deterministic renderer after gate
- [x] 2.10 Implement `dispose()` setting disposed flag
- [x] 2.11 Add barrel export `export 'src/playback/advanced_caption_rendering_runtime.dart';` in `lib/celesteria.dart`
- [x] 2.12 Run focused tests and confirm all pass (GREEN)

## 3. Validation Checkers

- [x] 3.1 Create `tools/advanced_caption_rendering_runtime_check.dart` importing `../lib/celesteria.dart`, standalone smoke checker with `_expect`/`_expectFailure`, covering: snapshot restart replay, evaluate, renderMatrixDanmaku, renderDualSubtitles, disable, acceptDegradation, unsupported scope, unavailable runtime, disposed runtime, fixed clock `DateTime.utc(2026, 6, 15, 12)`
- [x] 3.2 Create `tools/check_advanced_caption_rendering_runtime.ps1` with required file presence, Dart smoke run, required runtime terms, barrel export terms, checker terms, forbidden boundary terms, import guards
- [x] 3.3 Run `dart run tools/advanced_caption_rendering_runtime_check.dart` and confirm exit 0
- [x] 3.4 Run `powershell -ExecutionPolicy Bypass -File tools/check_advanced_caption_rendering_runtime.ps1` and confirm pass message

## 4. Validation Gates

- [x] 4.1 Run `flutter test test/playback/advanced_caption_rendering_contract_test.dart test/playback/advanced_caption_rendering_runtime_test.dart test/playback/av_sync_guard_contract_test.dart test/playback/av_sync_guard_runtime_test.dart test/playback/video_enhancement_pipeline_contract_test.dart test/playback/video_enhancement_pipeline_runtime_test.dart` and confirm all pass
- [x] 4.2 Run `dart analyze` and confirm no issues
- [x] 4.3 Run `dart run tools/advanced_caption_rendering_runtime_check.dart` and confirm exit 0
- [x] 4.4 Run `powershell -ExecutionPolicy Bypass -File tools/check_advanced_caption_rendering_runtime.ps1` and confirm pass

## 5. OpenSpec Validation

- [x] 5.1 Run `openspec validate "bootstrap-phase5-advanced-caption-rendering-runtime" --strict` and confirm valid
- [x] 5.2 Run `openspec validate --all` and confirm 0 failures
- [x] 5.3 Run scope guard: scan runtime/test/checker files for forbidden boundary terms (Mpv, Vlc, media-kit, MethodChannel, dart:ffi, DynamicLibrary, ShaderBundle, package:flutter/material, DiagnosticsCenter, RssAutoDownload, OnlineRule, WebView, CaptionRendering, NetworkPolicy, FallbackAdapter, FallbackOrchestrator) and confirm zero hits
- [x] 5.4 Run LSP diagnostics on `lib/src/playback/advanced_caption_rendering_runtime.dart`, `tools/advanced_caption_rendering_runtime_check.dart`, `lib/celesteria.dart` and confirm clean

## 6. Scope Guard and Task Completion

- [x] 6.1 Mark all tasks complete in `tasks.md` after matching evidence from steps 4-5
- [x] 6.2 Run `openspec instructions apply --change "bootstrap-phase5-advanced-caption-rendering-runtime" --json` and confirm `state: 'all_done'`
- [x] 6.3 Confirm `openspec validate --all` still passes 0 failures
