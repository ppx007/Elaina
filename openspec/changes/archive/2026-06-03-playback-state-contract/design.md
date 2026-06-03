## Context

Playback page surface descriptors define available controls, and playback page intents define user actions. The missing contract is the state snapshot those controls render and those actions update: playback status, timeline position, buffering, active source identity, and active track selections.

## Goals / Non-Goals

**Goals:**
- Define immutable, plain Dart playback state snapshot types.
- Represent playback lifecycle status, timeline, buffering, and active track state without Flutter or native player concepts.
- Add a minimal state observation contract that can be implemented later by `PlaybackController`, adapters, or test doubles.
- Keep state contracts usable by UI, Domain, and Playback boundaries without reversing layer dependencies.

**Non-Goals:**
- No Flutter widgets, `ValueNotifier`, streams tied to Flutter, Riverpod, Bloc, Provider package, or widget tests.
- No native MPV/libmpv/media-kit/VLC event binding.
- No queue, playlist, media-library persistence, provider metadata, online rule parsing, storage, gateway, network, diagnostics, danmaku, advanced subtitles, BT streaming, Anime4K, or VLC fallback behavior.
- No A/V sync enforcement beyond preserving timestamp fields for future integration.

## Decisions

- Use immutable value objects for playback state. This keeps snapshots deterministic for runtime checks and future widget tests, and avoids choosing a state-management framework before Flutter exists in the repo.
- Keep lifecycle status separate from timeline data. A status such as idle, opening, playing, paused, buffering, ended, and failed describes playback mode, while timeline fields describe position and duration.
- Model buffering as data, not behavior. Buffer ranges or progress values can be exposed later without making the state contract responsible for network, streaming, or native events.
- Expose a minimal observation interface rather than a concrete event bus. This lets future controllers or adapters publish snapshots while keeping implementation choices open.

## Risks / Trade-offs

- [Risk] State fields grow into full media/session models -> Mitigation: restrict this slice to playback status, timeline, buffering, active source identity, and active tracks.
- [Risk] Observation contract chooses the wrong reactive primitive -> Mitigation: define only a minimal interface and avoid Flutter or package-specific types.
- [Risk] State contract duplicates surface descriptor capability state -> Mitigation: keep capabilities/surface controls separate; state describes playback condition, not UI availability.
- [Risk] Timeline values imply A/V sync guarantees too early -> Mitigation: include snapshot timestamps without implementing AVSyncGuard behavior in this change.
