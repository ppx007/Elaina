## Context

Phase 5 Step 22 deepened `VideoEnhancementPipeline` and Step 23 deepened `AVSyncGuard`. Step 24 is the remaining advanced playback caption slice: Matrix4 danmaku, ordered dual subtitles, PGS rendering intent, and ASS enhancement under feature-flag and capability control.

The bootstrap `advanced_caption_rendering.dart` already defines `AdvancedCaptionFeature`, `CaptionTransform4`, `MatrixDanmakuRequest`, `DualSubtitleRequest`, `AdvancedSubtitleRequest`, `AdvancedCaptionCapability`, and `AdvancedCaptionRenderer`, but its methods return `Future<void>` and it has no durable preferences, deterministic feature evaluation, typed outcomes, invalidation events, or tests. This change must make the contract durable and verifiable while keeping concrete rendering engines outside the slice.

## Goals / Non-Goals

**Goals:**
- Define storage-backed advanced caption profile records for feature toggles, active per-playback selection, dual-subtitle ordering, and latest renderer state metadata.
- Define typed evaluation, render, disable, and degradation outcomes/failures for Matrix4 danmaku, dual subtitles, PGS subtitle rendering intent, and ASS enhancement intent.
- Publish advanced caption invalidation events when feature state, capability evaluation, renderer state, dual-subtitle selection, or degradation state changes.
- Preserve basic danmaku and subtitle parser boundaries while exposing advanced rendering requests as separate playback-layer contracts.
- Accept `AVSyncDegradationAction.disableAdvancedCaptions` as declarative input without making AVSyncGuard directly mutate renderer state.
- Add focused tests and checker coverage that prove Step 24 remains feature-gated, adapter-neutral, and implementation-neutral.

**Non-Goals:**
- No concrete Flutter widget tree, canvas drawing, Matrix4 GPU implementation, PGS bitmap decoder, ASS layout engine, native plugin, platform renderer, or FFI implementation.
- No VLC fallback behavior, fallback selection, adapter failover, or hidden capability policy; that remains Step 25.
- No diagnostics center integration, DNS/network policy, online rule runtime, RSS automation, WebView challenge handling, or Phase 6 provider/network automation.
- No mutation of basic `DanmakuComment`, `BasicDanmakuRenderer`, `SubtitleParser`, `SubtitleCue`, subtitle scanner, or subtitle offset contracts.
- No ownership of AV sync policy; Step 24 only consumes caption degradation decisions emitted by AVSyncGuard.

## Decisions

1. **Keep advanced caption features declarative and feature-gated.**
   - Decision: advanced caption contracts store feature intent, capability status, unsupported reasons, and requested render state rather than concrete renderer handles or platform resources.
   - Rationale: UI and Domain code need a portable vocabulary for advanced captions before concrete Flutter/native rendering exists.
   - Alternative considered: wire Matrix4/PGS/ASS behavior directly into renderer implementations now. Rejected because it would bind the contract to a renderer backend and violate adapter replaceability.

2. **Use typed outcomes for rendering and degradation flows.**
   - Decision: evaluation, render, disable, and degradation flows should return typed outcomes/failures instead of `void` or native-renderer exceptions.
   - Rationale: previous durable contract slices use deterministic success/failure results that can be tested without native adapters.
   - Alternative considered: keep the bootstrap `Future<void>` interface only. Rejected because it cannot express unsupported feature rows, disabled feature flags, rejected dual-subtitle order, or AVSyncGuard degradation deterministically.

3. **Persist preferences and state metadata, not rendered frames.**
   - Decision: storage should cover advanced caption profiles, active feature selection, dual-subtitle selection, and latest renderer state metadata; it must not store image buffers, shader state, glyph atlases, or renderer internals.
   - Rationale: restart-safe preferences are required, but rendered output belongs to future concrete renderers.
   - Alternative considered: no storage in Step 24. Rejected because advanced caption settings are user-facing configuration comparable to enhancement profiles.

4. **Publish events through `CacheInvalidationBus`.**
   - Decision: define events for feature changes, capability reevaluation, renderer state transitions, dual-subtitle selection, and degradation state changes.
   - Rationale: existing slices refresh derived state through event-driven invalidation instead of direct cross-module callbacks.
   - Alternative considered: direct callbacks from Playback to UI or diagnostics. Rejected because UI and diagnostics are outside this slice and direct callbacks would couple layers.

5. **Treat AVSyncGuard degradation as declarative input.**
   - Decision: Step 24 should expose a typed path for accepting `disableAdvancedCaptions` decisions, but AVSyncGuard must not execute renderer mutations.
   - Rationale: Step 23 already emits ordered degradation decisions; Step 24 provides the caption-side state contract that future adapters can execute.
   - Alternative considered: make AVSyncGuard call `AdvancedCaptionRenderer` directly. Rejected because it would collapse policy and renderer ownership.

## Risks / Trade-offs

- **Risk: Advanced caption contracts become concrete renderer implementations too early.** → Mitigation: specs and checker rules forbid Flutter widget, native plugin, FFI, GPU renderer, PGS decoder, and ASS layout engine dependencies in this slice.
- **Risk: Step 24 mutates basic subtitle/danmaku foundations.** → Mitigation: basic-danmaku and basic-subtitle deltas explicitly preserve parser, cue, filter, density, scanner, and offset boundaries.
- **Risk: Feature gating becomes ambiguous across four advanced features.** → Mitigation: capability matrix requirements and typed evaluation outcomes must carry explicit support status and reason strings per feature.
- **Risk: AVSyncGuard and advanced captions overlap in degradation behavior.** → Mitigation: AVSyncGuard remains the policy owner; advanced captions only accept and persist declarative degradation state.
- **Risk: Storage creates migration obligations.** → Mitigation: records are small, schema-neutral, and implementation-independent, avoiding renderer buffers or native state.

## Migration Plan

1. Add `advanced-caption-rendering-contract` specs and deltas for existing affected specs.
2. Extend Dart contracts with advanced caption storage records, deterministic feature evaluator, typed outcomes/failures, degradation acceptance, and invalidation events.
3. Update public exports, runtime checks, focused tests, Phase 5 documentation, and advanced playback checker rules.
4. Validate with OpenSpec, analyzer, focused Flutter tests, runtime checks, and Phase 5 checker scripts.

Rollback is straightforward because this change introduces contract/value/state scaffolding only; no concrete renderer, decoder, native plugin, or external dependency is introduced.

## Open Questions

- None blocking for the contract slice. Concrete Matrix4 layout math, Flutter composition, PGS decoding, ASS renderer behavior, diagnostics snapshots, and VLC fallback interactions are intentionally deferred.
