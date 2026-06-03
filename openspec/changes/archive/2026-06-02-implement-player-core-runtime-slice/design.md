## Context

The baseline Player core contracts define the adapter boundary, capability matrix, playback page foundation, and track management semantics. The current code already exposes `PlaybackController`, `PlayerAdapter`, `PlaybackCapabilityMatrix`, `MpvPlayerAdapterFacade`, playback source types, and normalized track descriptors, but the repository still needs an executable slice proving that these contracts compose correctly.

This change runs after the repository baseline and before native playback integration. It must preserve the 8-layer architecture: UI consumes Domain/Playback state, Domain routes commands through Playback contracts, Playback hides concrete adapter details, and Provider/Gateway/Storage/Streaming/Network remain outside the core playback loop.

## Goals / Non-Goals

**Goals:**

- Add Dart-only verification for the Player core runtime path from `PlaybackController` to a bound in-memory adapter.
- Prove that unsupported MPV facade behavior remains explicit when no binding is available.
- Prove that source support, visible controls, secondary panels, and track operations are governed by the active adapter capability matrix.
- Keep the implementation small enough to validate with `dart analyze` and existing PowerShell checker scripts.

**Non-Goals:**

- No native MPV, libmpv, media-kit, Flutter video surface, or platform channel binding.
- No playback page UI implementation beyond existing Domain/Playback surface state contracts.
- No provider metadata, Bangumi, Dandanplay, RSS, online rule runtime, BT streaming, danmaku, advanced subtitles, Anime4K, VLC fallback, or diagnostics center integration.
- No changes that make online source parsing a prerequisite for local playback.

## Decisions

### Decision 1: Use an in-memory `MpvAdapterBinding` test double

The runtime slice SHALL exercise `MpvPlayerAdapterFacade.bound` with an in-memory binding rather than adding a native MPV dependency. This proves the facade and controller behavior while keeping Phase 1 independent of unavailable native tooling.

Alternative considered: introduce a real MPV/media-kit binding now. This was rejected because the current workspace is a contract scaffold and the existing spec explicitly says the facade must not claim support unless a concrete binding is available.

### Decision 2: Add source gating at the Playback contract boundary

The active adapter SHALL reject unsupported source categories before delegating load behavior. This keeps UI capability decisions and adapter command behavior aligned: if the matrix says HLS is unsupported, loading an HLS source returns a normalized failure.

Alternative considered: allow load to delegate blindly and let bindings fail. This was rejected because it leaks support decisions into concrete engines and makes capability-driven UI state less trustworthy.

### Decision 3: Validate surface state through `PlaybackController`

The executable checks SHALL assert visible controls and panels through `PlaybackController.resolveSurfaceState()` rather than a Flutter widget. This keeps the first runnable slice independent of UI framework setup while still proving the playback page foundation contract.

Alternative considered: build a minimal Flutter playback widget. This was rejected because the next useful proof is contract composition, not visual rendering.

### Decision 4: Treat track discovery and switching as normalized adapter operations

The runtime slice SHALL verify successful and unsupported track paths through `TrackDiscoveryResult` and `TrackSwitchResult`. UI and Domain code continue to see normalized descriptors instead of engine-specific track objects.

Alternative considered: model MPV-specific track IDs now. This was rejected because it would violate the replaceable adapter boundary before a native binding exists.

## Risks / Trade-offs

- In-memory adapter tests can pass while a future native MPV binding still fails -> Mitigation: keep the MPV facade unsupported by default and add native binding acceptance requirements in a later change.
- Source gating can duplicate binding-level validation -> Mitigation: make gating operate only on coarse source categories declared by `PlaybackCapabilityMatrix`; bindings remain responsible for concrete URI/runtime errors.
- Contract tests may grow into implementation detail assertions -> Mitigation: assert public result types, capability states, and controller surface state only.
- Keeping UI out of this change delays visual playback verification -> Mitigation: the next UI change can consume the already validated Domain/Playback surface state.
