## Why

The Phase 0 foundation is archived, so Elaina can now move into the first playback-facing slice without violating the architecture plan's sequencing. This change freezes the player core boundary before advanced subtitles, danmaku, provider integrations, RSS, BT streaming, or enhancement features are introduced.

## What Changes

- Establish **Phase 1 / Step 5-8** as the next implementation boundary.
- Define an MPV adapter facade for local file, HTTP, and HLS playback without letting UI import concrete MPV/libmpv implementations; if a concrete binding is unavailable, it must report playback as unsupported rather than pretending MPV playback works.
- Define a playback capability matrix so UI and Domain code render only features supported by the active player adapter and platform.
- Define the playback page foundation at contract level: video surface, playback controls, progress, and secondary panel entry points are driven by capability declarations.
- Define track management contracts for reading and switching audio and subtitle tracks.

## Capabilities

### New Capabilities
- `mpv-adapter-boundary`: Defines the replaceable MPV adapter facade and support reporting for core playback sources.
- `playback-capability-matrix`: Defines how playback capabilities are declared and consumed.
- `playback-page-foundation`: Defines the baseline playback page behavior that is allowed in Phase 1.
- `track-management`: Defines audio and subtitle track discovery and switching contracts.

### Modified Capabilities

None.

## Impact

- Adds playback-facing contracts and implementation tasks under the existing Playback, Domain, and UI boundaries.
- Carries forward Phase 0 restrictions: no UI direct dependency on MPV/VLC/native engines, no provider-specific work, no online source parsing as a playback prerequisite, and no advanced rendering work.
- Prepares later VLC, ExoPlayer, AVPlayer, subtitle, danmaku, BT streaming, and diagnostics work to extend player capabilities rather than rewriting playback UI assumptions.
