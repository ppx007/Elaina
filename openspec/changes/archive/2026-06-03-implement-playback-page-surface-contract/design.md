## Context

The Player core runtime slice now verifies `PlaybackController.resolveSurfaceState()` and capability-driven control exposure. The remaining gap is a UI-owned surface contract that turns this Domain/Playback state into stable, renderable descriptors for future playback page widgets.

The current UI playback contract is intentionally thin: it wraps `PlaybackController.resolveSurfaceState()`. This change keeps that direction but makes the UI layer's ownership explicit: UI maps Domain state into presentation descriptors, while Domain and Playback remain free of UI imports, Flutter widget types, concrete player engines, provider internals, and streaming internals.

## Goals / Non-Goals

**Goals:**

- Define a Dart-only playback page surface model under the UI layer.
- Map `PlaybackSurfaceState` controls and panels into stable UI-facing descriptors with IDs, visibility, and enabled state.
- Add executable checks that prove unsupported capabilities are not exposed as active controls.
- Extend checker coverage so the UI layer remains isolated from MPV/VLC/native/provider/streaming internals.

**Non-Goals:**

- No Flutter widget, `BuildContext`, layout, theme, animation, rendering surface, or visual design implementation.
- No native MPV/libmpv/media-kit/VLC binding.
- No provider metadata, Bangumi, Dandanplay, RSS, BT streaming, danmaku, subtitle-provider, Anime4K, online-rule, or diagnostics integration.
- No Domain/Playback changes unless a small public contract gap is discovered during implementation.

## Decisions

### Decision 1: UI owns the surface contract

The playback page surface contract SHALL live under `lib/src/ui/playback/` because it is a presentation mapping layer. It may depend on Domain-facing playback contracts, but Domain and Playback SHALL NOT import UI contracts.

Alternative considered: move the surface model into Domain so all consumers share it. This was rejected because page-specific controls, labels, enabled states, and panel entries are UI concerns and would reverse the 8-layer dependency direction.

### Decision 2: Use framework-neutral descriptors, not Flutter widgets

The surface contract SHALL produce plain Dart descriptors such as control IDs, panel IDs, visibility, and enabled state. Future Flutter widgets can render those descriptors later without changing the Domain/Playback contracts.

Alternative considered: build a minimal Flutter page now. This was rejected because the next useful boundary is the presentation contract, not visual rendering.

### Decision 3: Treat advanced features as inactive panel/descriptor entries only when supported

The surface contract SHALL not expose unsupported later-phase features as active controls. When a capability is absent, the descriptor is hidden or absent; it must not trigger provider, streaming, or native-player behavior.

Alternative considered: include placeholder active controls for future features. This was rejected because it violates capability-driven UI and encourages premature integration with later phases.

## Risks / Trade-offs

- [Risk] The UI surface descriptors become too close to a future Flutter widget tree -> Mitigation: keep descriptors framework-neutral and data-only.
- [Risk] Domain starts importing UI surface types for convenience -> Mitigation: add checker coverage forbidding Domain/Playback imports from `lib/src/ui`.
- [Risk] The surface contract duplicates `PlaybackSurfaceState` too closely -> Mitigation: keep the mapping useful by introducing UI-facing stable IDs and enabled/visibility semantics.
- [Risk] Scope creeps into a full playback page -> Mitigation: explicitly exclude widgets, layout, native surface rendering, and later-phase systems.
