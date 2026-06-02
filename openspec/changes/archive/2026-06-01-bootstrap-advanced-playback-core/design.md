## Context

Phase 4 archived the BT streaming boundary. The architecture plan defines Phase 5 as Step 22 `VideoEnhancementPipeline`, Step 23 `AVSyncGuard`, Step 24 advanced danmaku/subtitle rendering, and Step 25 VLC fallback.

This change defines the contracts needed to expose advanced playback safely. The goal is not to implement shaders, VLC bindings, diagnostics, or platform-native rendering; it is to make those future integrations capability-scoped and degradation-aware before any concrete engine code is introduced.

## Goals / Non-Goals

**Goals:**
- Define video enhancement pipeline contracts for profiles, scaler/HDR/deband/Anime4K-style presets, and render budget inputs.
- Define A/V sync guard contracts for drift, dropped frames, render delay, and degradation decisions.
- Define advanced danmaku/subtitle rendering contracts for Matrix4 danmaku, dual subtitles, PGS, and ASS enhancement.
- Define fallback adapter contracts for VLC-style secondary adapters, failure switching, and capability hiding.
- Extend playback capability matrix expectations for advanced playback and fallback features.

**Non-Goals:**
- Implementing MPV shader graphs, Anime4K presets, concrete HDR conversion, or concrete deband filters.
- Implementing VLC native bindings or shipping VLC as a dependency.
- Implementing diagnostics center, DNS/network policy, online source rules, RSS auto-download, or WebView challenge handling.
- Changing the core playback loop to require advanced rendering or fallback adapters.

## Decisions

### 1. Enhancement profiles are declarative contracts

Enhancement profiles will describe requested scaler, HDR, deband, and Anime4K-style preset behavior. Concrete adapters decide whether they can satisfy the profile and report capability status through the matrix.

**Alternative considered:** expose MPV-specific shader options directly. Rejected because UI and Domain must not depend on a concrete player engine.

### 2. AVSyncGuard owns degradation decisions

`AVSyncGuard` will consume drift, dropped-frame, render-delay, and frame-budget signals, then emit degradation decisions such as lowering enhancement intensity or disabling a profile. Drift above 120ms is the hard degradation trigger; drift under 40ms remains the target.

**Alternative considered:** let each renderer degrade independently. Rejected because inconsistent degradation would make playback behavior unpredictable across adapters.

### 3. Advanced captions remain feature-gated overlays

Matrix4 danmaku, dual subtitles, PGS, and ASS enhancement are modeled as rendering capabilities and overlay contracts. They do not replace the existing basic subtitle and danmaku foundations.

**Alternative considered:** fold advanced captions into basic subtitle parsing. Rejected because PGS and ASS enhancement have different rendering and capability requirements.

### 4. VLC fallback is an adapter strategy, not a UI branch

Fallback adapter contracts describe failure switching and capability hiding. UI reads capability state and never branches on VLC-specific implementation details.

**Alternative considered:** add a visible VLC toggle directly to UI. Rejected because fallback should be governed by adapter capability and failure policy.

## Risks / Trade-offs

- **[Risk] Advanced playback leaks MPV/VLC-specific concepts into UI** -> **Mitigation:** keep contracts in Playback/Domain surfaces and require capability matrix gating.
- **[Risk] Enhancement profiles overpromise rendering quality** -> **Mitigation:** profiles declare intent, while adapters report actual support and AVSyncGuard can degrade.
- **[Risk] AVSyncGuard becomes diagnostics center** -> **Mitigation:** keep it focused on sync measurements and playback degradation decisions, not system-wide diagnostics.
- **[Risk] Fallback switching hides capability loss** -> **Mitigation:** fallback state must expose hidden/unsupported capabilities and reason strings.

## Migration Plan

This is a greenfield continuation from Phase 4:

1. Add video enhancement profile and pipeline contracts.
2. Add AV sync guard metric and degradation decision contracts.
3. Add advanced caption rendering contracts.
4. Add fallback adapter contracts.
5. Extend capability matrix contracts and verification for advanced playback/fallback gating.

## Open Questions

- Which exact Anime4K preset names should the first concrete MPV adapter expose?
- Should PGS support be parser-first, renderer-first, or adapter-declared only in the first implementation pass?
- What fallback policy should be default when both MPV and VLC support a source but expose different subtitle/danmaku capabilities?
