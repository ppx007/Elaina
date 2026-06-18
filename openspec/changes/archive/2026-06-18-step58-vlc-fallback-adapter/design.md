## Context

The existing fallback adapter contract and runtime already model secondary
adapter registration, deterministic selection, hidden capabilities, and durable
strategy state. Step 58 needs a concrete Playback-owned VLC fallback candidate
that can participate in that flow. The repository does not currently contain a
verified VLC native package or packaged VLC binary, so the implementation must
not claim native VLC playback by default.

## Goals / Non-Goals

**Goals:**

- Provide a `PlayerAdapter` implementation for VLC fallback selection.
- Keep VLC execution behind a Playback-owned backend interface.
- Declare only verified local-file fallback capabilities when a backend is
  supplied.
- Normalize unavailable, unsupported, disposed, and backend-failure outcomes
  through existing playback contracts.
- Preserve UI ownership and layer boundaries.

**Non-Goals:**

- No Flutter UI, app shell, route, video surface, status display, file picker,
  `lib/main.dart`, or `windows/**` work.
- No unverified VLC package dependency, FFI bridge, platform channel, or binary
  packaging claim.
- No changes to MPV primary playback behavior or fallback strategy semantics.

## Decisions

- Use an injected `VlcFallbackBackend` rather than adding a VLC dependency now.
  This keeps Step 58 honest: tests can verify adapter behavior, while future
  native VLC work can plug in behind the backend interface.
- Make backend availability drive the default capability matrix. A candidate
  without a backend cannot register as a supported fallback adapter, so fallback
  selection cannot report fake native support.
- Keep hidden capabilities explicit by assigning unsupported reasons for every
  unverified playback capability. This keeps UI-owned code capability-driven
  after fallback.
- Reuse existing `PlaybackCommandResult`, `PlaybackFailure`, and
  `FallbackAdapterCandidate` contracts instead of adding a parallel VLC-specific
  result model.

## Risks / Trade-offs

- Backend-injected VLC is not full native VLC playback. Mitigation: capability
  gates reject unsupported candidates without a backend, and docs/specs state
  that native VLC packaging is not claimed by this change.
- The adapter supports only local files in this step. Mitigation: HTTP, HLS,
  track discovery, advanced captions, danmaku, and enhancement remain
  unsupported with explicit reasons until verified.
- Future native VLC implementation may need platform-specific setup. Mitigation:
  keep the backend interface small and Playback-owned so native details can be
  added without changing fallback strategy/runtime contracts.
