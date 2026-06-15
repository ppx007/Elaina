## Context

Phase 5 Step 24 adds the runtime/bootstrap acceptance layer for advanced caption rendering. The contract layer (`AdvancedCaptionRenderer` interface, `DeterministicAdvancedCaptionRenderer`, `AdvancedCaptionStore`, five cache invalidation events) is already implemented. This change fills the same gap that Steps 22/23 filled for video enhancement pipeline and AV sync guard: providing a scope-gated, typed-outcome runtime that wraps the deterministic renderer and projects combined in-memory + stored state for restart replay.

## Goals / Non-Goals

**Goals:**
- Scope-gate all advanced caption operations (evaluate, renderMatrixDanmaku, renderDualSubtitles, renderAdvancedSubtitle, disable, acceptDegradation) by disposed/unavailable/unsupported checks
- Return typed `AdvancedCaptionRuntimeActionResult<T>` with success/failed/unavailable/disposed variants for every operation
- Project combination of in-memory latest report/state + stored active profile + stored renderer state + stored dual subtitle selection for snapshot and restart replay
- Publish cache invalidation events through the bus on evaluate/render/disable/degradation paths (delegated to DeterministicAdvancedCaptionRenderer)
- Support `AdvancedCaptionRuntime.unavailable()` for scopes without a renderer

**Non-Goals:**
- No native renderer, GPU shader, FFI, or Flutter widget integration
- No VLC fallback, AV sync guard policy logic, diagnostics center, RSS, network policy, WebView, or online rule dependency
- No concrete PGS decoder or ASS layout engine — runtime wraps the deterministic renderer only
- No clock parameter at runtime level (clock stays at DeterministicAdvancedCaptionRenderer level, same as Step 23 cleanup)

## Decisions

**D1: Bootstrap pattern matches Steps 22/23** — `AdvancedCaptionRuntimeBootstrap` accepts `captionStore`, `Map<String, DeterministicAdvancedCaptionRenderer> rendererByScope`, `Map<String, PlaybackCapabilityMatrix> capabilitiesByScope`, optional `CacheInvalidationBus?`, creates `AdvancedCaptionRuntime` via `createRuntime()`. Rationale: proven pattern, consistent API surface, zero drift from existing runtime contracts.

**D2: Runtime gate checks disposed then unavailable then missing scope then unsupported capability** — `AdvancedCaptionRuntime._gate(scopeId)` returns typed failures in priority order, matching Step 22/23 gate contract. Rationale: ensures no operation reaches a deterministic renderer that shouldn't.

**D3: Projection combines stored + in-memory** — `AdvancedCaptionRuntimeProjection` reads active profile ID and latest renderer state from store, latest report from in-memory evaluation, degradation reason from latest stored state. `AdvancedCaptionRuntimeRestartProjection` reads only from store. Rationale: restart must succeed without any in-memory state.

**D4: Failure kinds reuse domain failures** — `AdvancedCaptionRuntimeFailureKind` includes `capabilityUnsupported`, `unavailable`, `disposed` (from runtime pattern) plus `featureDisabled`, `profileNotFound`, `dualSubtitleOrderRejected`, `staleEvaluation`, `avSyncDegradation` (from contract's `AdvancedCaptionFailureKind`). Rationale: runtime failures are a superset, not a replacement.

**D5: No clock at runtime/bootstrap layer** — Following Step 23 cleanup, the runtime layer does not accept or store a clock parameter. Clock stays at `DeterministicAdvancedCaptionRenderer` where timestamps are generated. Rationale: avoids unused field warnings and keeps the runtime a thin acceptance layer.

## Risks / Trade-offs

- [AdvancedCaptionRenderer has 6 methods vs 3-4 in Steps 22/23] → Runtime delegates each method individually; no shortcut. More boilerplate but complete coverage.
- [Dual subtitle selection is unique to Step 24] → Restart projection must include dual subtitle data from store. Adds one field to `AdvancedCaptionRuntimeRestartProjection` compared to Steps 22/23.
