## Why

Celesteria has completed the ACG data experience boundary through Step 17, so the next roadmap slice can define BT playback without leaking download-engine details into the UI or player. Phase 4 freezes Steps 18-21: BT task core, virtual media streaming, piece priority scheduling, and playback timeline overlays.

## What Changes

- Establish **Phase 4 / Step 18-21** as the next implementation boundary.
- Define BT task contracts for magnet/torrent identity, metadata, file lists, and task lifecycle management.
- Define `VirtualMediaStream` contracts that expose range-readable media over buffered pieces while players remain stream/source agnostic.
- Define `PiecePriorityScheduler` contracts for current playback window, seek targets, first/last piece priority, and strategy profiles.
- Define `TimelineOverlay` contracts for progress, buffered ranges, piece maps, and heat/marker layers without coupling UI to the download engine.

## Capabilities

### New Capabilities
- `bt-task-core`: Defines magnet/torrent task identity, metadata, file list, lifecycle, and adapter boundary contracts.
- `virtual-media-stream`: Defines range-readable virtual media stream contracts backed by task pieces and storage buffers.
- `piece-priority-scheduler`: Defines piece priority planning contracts for playback windows, seeking, and strategy profiles.
- `timeline-overlay`: Defines timeline overlay data contracts for progress, buffering, piece state, and heat/marker layers.

### Modified Capabilities

None.

## Impact

- Adds Streaming, Domain, Playback, Storage, and UI-facing contracts for BT playback scaffolding.
- Requires any libtorrent or platform download engine integration to remain behind adapter contracts.
- Keeps player adapters consuming playback/stream abstractions rather than torrent task internals.
- Keeps RSS auto-download, online rules, advanced rendering, diagnostics center, Anime4K, VLC fallback, DNS policy, and WebView challenge handling out of scope.
