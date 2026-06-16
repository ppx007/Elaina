## Why

Step 31 and Step 31b introduced a concrete media_kit/libmpv playback binding
and Windows bundled `libmpv-2.dll` packaging support. The next gap is not UI:
it is a stable composition contract that tells the external app shell how to
wire the concrete binding into `PlayerCoreRuntime` without importing concrete
player packages from UI code.

The current bootstrap can already accept an injected `MpvAdapterBinding`, but
the app composition root still needs a named, documented value to pair the
binding with its verified capability matrix.

## What Changes

- Add a playback-owned runtime composition descriptor that carries an
  `MpvAdapterBinding` and the verified `PlaybackCapabilityMatrix`.
- Add a media_kit/libmpv composition factory for local file playback with an
  optional `libmpvPath`, including bundled-DLL resolution through the existing
  binding.
- Add a `PlayerCoreBootstrap` constructor that accepts the neutral composition
  descriptor without importing concrete media_kit/libmpv implementation code
  into Domain runtime files.
- Document the external UI/app-shell integration flow and packaged-release
  smoke steps.
- Extend player-core boundary checks so future UI and `lib/main.dart` code
  cannot import `media_kit` or concrete player packages directly.

## Impact

- Affected code is limited to Playback composition contracts, Domain bootstrap
  wiring, tests, docs, checkers, and OpenSpec specs.
- This change MUST NOT modify `lib/src/ui/**`, `lib/main.dart`, or
  `windows/**`.
- UI implementation, routes, file picker UX, video surface, and visual playback
  controls remain owned by the external UI implementation track.
