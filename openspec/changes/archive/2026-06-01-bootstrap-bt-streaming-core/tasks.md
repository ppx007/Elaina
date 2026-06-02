## 1. BT task core

- [x] 1.1 Define BT task identity, source, metadata, file descriptor, and lifecycle state contracts.
- [x] 1.2 Define `DownloadEngine` adapter boundary for task creation, lifecycle commands, and task events.
- [x] 1.3 Define platform capability contracts for unsupported or degraded BT task behavior, including iOS background limitations.

## 2. Virtual media stream

- [x] 2.1 Define `VirtualMediaStream` identity, byte range request, byte range response, and stream failure contracts.
- [x] 2.2 Define buffered range contracts that connect virtual streams to Storage-layer media cache responsibilities.
- [x] 2.3 Ensure player-facing contracts consume stream/playback abstractions rather than BT task or concrete engine objects.

## 3. Piece priority scheduler

- [x] 3.1 Define piece map, playback window, seek target, and priority plan contracts.
- [x] 3.2 Define strategy profile contracts for first-piece, tail-piece, lookahead, and stale-window behavior.
- [x] 3.3 Define scheduler output boundaries that can be applied by a download engine adapter without UI/player direct piece mutation.

## 4. Timeline overlay

- [x] 4.1 Define timeline overlay read models for playback progress, buffered ranges, piece states, and marker layers.
- [x] 4.2 Define layer visibility/ordering contracts without introducing final timeline UI implementation.
- [x] 4.3 Ensure timeline overlays remain read-only presentation contracts, not BT task lifecycle or diagnostics center controllers.

## 5. Verification and next boundary

- [x] 5.1 Verify UI does not import libtorrent, BT engine internals, piece scheduler internals, or concrete stream implementations.
- [x] 5.2 Verify player adapters depend on playback/stream abstractions rather than BT task or torrent engine contracts.
- [x] 5.3 Verify RSS auto-download, online rules, Anime4K, VLC fallback, diagnostics center, DNS policy, and WebView challenge handling remain out of scope.
