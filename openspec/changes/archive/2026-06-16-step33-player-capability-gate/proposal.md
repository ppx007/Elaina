## Why

Step 31 introduced the concrete media_kit/libmpv playback binding, and Step 32
added the runtime composition contract. The remaining Step 33 gap is to make
the verified capability gate explicit for UI/app-shell consumers without
implementing UI.

The local-file concrete path currently supports local file playback,
play/pause, seek, and stop. UI-owned code needs a stable rule: render and
dispatch playback controls only from the active capability-derived surface, not
from assumptions about the concrete player backend.

## What Changes

- Document the UI-facing capability gate for local file playback.
- Add focused test coverage proving the media_kit composition exposes only the
  verified playback controls through `PlaybackPageContract`.
- Extend player-core checks so the capability gate notes remain present and the
  concrete local-file matrix does not accidentally advertise unverified HTTP,
  HLS, track, progress, advanced playback, or fallback capabilities.
- Keep all UI implementation work outside this change.

## Impact

- Affected files are limited to docs, tests, checker scripts, and OpenSpec
  specs.
- This change MUST NOT modify `lib/src/ui/**`, `lib/main.dart`, or
  `windows/**`.
- UI/app-shell implementation remains owned by the external UI model.
