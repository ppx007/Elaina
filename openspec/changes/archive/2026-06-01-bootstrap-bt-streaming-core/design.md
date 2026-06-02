## Context

Phase 3 archived the detail page, media library, subtitle provider, RSS engine, and seasonal indexer contracts. The architecture plan defines Phase 4 as Step 18 BT task core, Step 19 `VirtualMediaStream`, Step 20 `PiecePriorityScheduler`, and Step 21 `TimelineOverlay`.

This slice introduces BT playback as a contract layer, not as a concrete libtorrent implementation. UI must not depend on libtorrent, torrent metadata structures, or piece scheduling internals. Player adapters must consume playback/stream abstractions, while download engines remain replaceable through adapter boundaries.

## Goals / Non-Goals

**Goals:**
- Define BT task identity, metadata, file selection, and lifecycle contracts.
- Define virtual media stream contracts for range reads and buffered ranges.
- Define piece priority scheduling contracts for playback windows and seek targets.
- Define timeline overlay data contracts for progress, buffered ranges, piece maps, and heat/marker layers.

**Non-Goals:**
- Implementing libtorrent bindings or platform-specific native download engines.
- Implementing RSS auto-download or online rule-source parsing.
- Implementing diagnostics center, DNS policy, WebView challenge handling, Anime4K, VLC fallback, or advanced rendering features.
- Promising long-running iOS background BT downloads.

## Decisions

### 1. BT task core stays behind a DownloadEngine adapter boundary

BT task contracts will describe magnet/torrent input, metadata, files, task state, and lifecycle commands. Concrete engines such as libtorrent attach later through adapters and must not be visible to UI or player code.

**Alternative considered:** expose libtorrent-native task models directly. Rejected because it would make engine replacement and platform capability gating difficult.

### 2. Player adapters consume virtual streams, not torrent internals

`VirtualMediaStream` will expose range-readable media and buffered ranges so playback code can request media bytes without understanding pieces, peers, or torrent tasks.

**Alternative considered:** make MPV read torrent files directly. Rejected because it couples player behavior to one download engine and weakens buffering policy control.

### 3. Piece priorities are planned by playback-aware scheduler contracts

`PiecePriorityScheduler` will accept current playback position, seek targets, and file-piece maps, then produce priority plans. Strategy profiles allow later tuning without changing task or player contracts.

**Alternative considered:** let the download engine decide priorities alone. Rejected because playback must prioritize current and near-future windows deterministically.

### 4. Timeline overlays expose display data, not engine control

Timeline overlay contracts will represent playback progress, buffered ranges, piece states, and marker/heat layers. UI consumes these read models but does not control BT task internals through the overlay.

**Alternative considered:** merge timeline overlays into BT tasks. Rejected because overlays are presentation-facing read models and should not own task lifecycle behavior.

## Risks / Trade-offs

- **[Risk] BT contracts leak concrete engine details** -> **Mitigation:** define engine-neutral identifiers, task states, file descriptors, and adapter interfaces.
- **[Risk] Virtual streams become a second player adapter** -> **Mitigation:** keep stream contracts focused on byte ranges and buffered ranges; playback remains responsible for source selection.
- **[Risk] Priority scheduler overpromises performance** -> **Mitigation:** define planning contracts and strategy profiles, not concrete throughput guarantees.
- **[Risk] Timeline overlay becomes diagnostics center** -> **Mitigation:** keep overlays limited to user-facing progress/buffer/piece/marker layers; diagnostics remain later Phase 6 work.

## Migration Plan

This is a greenfield continuation from Phase 3:

1. Add BT task and download-engine adapter contracts.
2. Add virtual media stream and buffered range contracts.
3. Add piece priority scheduler and profile contracts.
4. Add timeline overlay read-model contracts.
5. Add verification that UI/player layers do not import concrete BT engine internals.

## Open Questions

- Which native BT engine should be the first concrete adapter after the contract slice?
- How should platform capability profiles expose iOS background limitations?
- Which timeline markers should come from playback, danmaku, subtitle, or BT state in the first UI implementation?
