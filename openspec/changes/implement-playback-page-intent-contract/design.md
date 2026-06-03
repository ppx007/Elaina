## Context

The current playback page surface contract maps `PlaybackSurfaceState` into UI-owned control and panel descriptors. Future widgets still need a separate, plain Dart way to express user actions and dispatch only actions that are visible, enabled, and supported by the active Domain playback state.

## Goals / Non-Goals

**Goals:**
- Define framework-neutral playback page intents for transport, progress seeking, secondary panel opening, and track selection.
- Resolve intents through the existing `PlaybackPageContract`, `PlaybackPageSurfaceDescriptor`, and `PlaybackController` boundary.
- Return deterministic intent results for executed, ignored, and unsupported actions.
- Validate intent behavior with the existing Dart-only runtime checker.

**Non-Goals:**
- No Flutter widget tree, layout, theme, gesture recognizer, or BuildContext work.
- No changes to native player bindings, MPV facade internals, provider systems, streaming systems, storage, gateway, network, danmaku, Anime4K, VLC fallback, online rules, or diagnostics center.
- No new external dependency.

## Decisions

- Represent user actions as plain Dart intent values. This keeps the UI layer framework-neutral and lets future Flutter widgets bind button presses to stable contract objects without leaking Flutter-specific concepts into Domain or Playback.
- Dispatch intents from the UI layer through `PlaybackController`, not through `PlayerAdapter`. This preserves the existing Domain boundary, keeps capability checks centralized, and avoids direct UI dependency on concrete playback implementations.
- Gate executable intents against `PlaybackPageSurfaceDescriptor` before dispatch. This makes visible/enabled controls the source of truth for whether a UI action can run and prevents unsupported controls from becoming active commands.
- Return explicit intent results rather than throwing for normal unsupported or ignored actions. This gives future widgets deterministic feedback and keeps unsupported capabilities as expected runtime states rather than exceptional failures.

## Risks / Trade-offs

- Intent coverage may overreach into later playback features -> Limit the first slice to transport, seek, tracks panel, and track selection, with later-phase actions intentionally excluded.
- The intent contract may duplicate controller capability checks -> Keep UI gating descriptor-driven and allow Domain/Playback to remain the final enforcement boundary.
- Track selection needs a Domain track identifier -> Reuse existing track-management contract types rather than introducing UI-owned track identifiers.
