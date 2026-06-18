# Phase 4: BT Streaming Core

This phase adds contract scaffolding for Celesteria architecture plan steps 18-21.

## Implemented Boundary

- BT task contracts define engine-neutral magnet/torrent sources, metadata, file descriptors, lifecycle state, events, and a `DownloadEngineAdapter` boundary.
- Virtual media stream contracts expose byte-range reads and buffered ranges without exposing torrent pieces to player adapters.
- Piece priority scheduler contracts define piece maps, playback windows, seek targets, strategy profiles, and adapter-applied priority plans.
- Timeline overlay contracts expose read-only progress, buffered ranges, piece states, priority windows, markers, heat layers, and layer visibility/order without owning BT, scheduler, or rendering behavior.
- Playback receives a `VirtualStreamPlaybackSource` that points to a stream abstraction instead of a concrete torrent engine.
- Step 55 provides a non-UI smoke gate that verifies BT task -> virtual stream -> byte range -> priority application composition using existing Streaming contracts and checker tooling.

## Non-Goals Preserved

- No UI download page, playback page, video surface, file picker, app shell, or `lib/main.dart` ownership.
- No concrete HTTP server, socket server, pipe server, or platform networking implementation.
- No RSS auto-download or online rule-source parsing.
- No diagnostics center, Anime4K, VLC fallback, DNS policy, or WebView challenge handling.
- No promise of long-running iOS background BT download support.

The current libtorrent Dart surface supports file-priority application; Step 55
does not claim arbitrary native per-piece priority control.
