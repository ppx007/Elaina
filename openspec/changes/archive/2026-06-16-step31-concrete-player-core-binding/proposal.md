## Why

Celesteria has completed the Step 1-30 contract scaffold and runtime bootstrap
acceptance layer. The next implementation layer needs a first concrete runtime
binding while preserving the existing layer boundaries and keeping UI work
outside this change.

The player core already defines `PlayerAdapter`, `MpvPlayerAdapterFacade`,
`MpvAdapterBinding`, and `PlayerCoreRuntime`. Those types can host a real
local-file playback binding without requiring Flutter pages, routing, file
pickers, or video-surface widgets.

## What Changes

- Add a media_kit/libmpv-backed concrete `MpvAdapterBinding` for local file
  playback commands.
- Add core runtime wiring that constructs `PlayerCoreRuntime.bound(...)` through
  the existing MPV facade.
- Keep only verified capabilities enabled: local file playback, play/pause,
  seek, stop, and lifecycle disposal.
- Keep HTTP/HLS and track operations unsupported unless explicitly implemented
  and tested in this change.
- Add boundary validation so concrete player imports stay out of Domain, UI,
  Provider, Storage, Streaming, and Network layers.

## Impact

- Affected code is limited to Playback concrete binding, Domain player-core
  runtime wiring, tests, checker scripts, package manifest, and OpenSpec specs.
- This change MUST NOT modify `lib/src/ui/**` or `lib/main.dart`.
- UI implementation, video surface rendering, app shell, routes, and file picker
  UX remain owned by an external UI implementation track.
