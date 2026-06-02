# Phase 4: BT Streaming Core

This phase adds contract scaffolding for Celesteria architecture plan steps 18-21.

## Implemented Boundary

- BT task contracts define engine-neutral magnet/torrent sources, metadata, file descriptors, lifecycle state, events, and a `DownloadEngineAdapter` boundary.
- Virtual media stream contracts expose byte-range reads and buffered ranges without exposing torrent pieces to player adapters.
- Piece priority scheduler contracts define piece maps, playback windows, seek targets, strategy profiles, and adapter-applied priority plans.
- Timeline overlay contracts expose read-only progress, buffered ranges, piece states, markers, and layer visibility/order.
- Playback receives a `VirtualStreamPlaybackSource` that points to a stream abstraction instead of a concrete torrent engine.

## Non-Goals Preserved

- No libtorrent binding or native download engine implementation.
- No concrete HTTP server, file I/O, or platform networking implementation.
- No RSS auto-download or online rule-source parsing.
- No diagnostics center, Anime4K, VLC fallback, DNS policy, or WebView challenge handling.
- No promise of long-running iOS background BT download support.

The next change should move into Phase 5 only after this change is implemented and archived.
