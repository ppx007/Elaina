## Context

This design outlines how the RSS Feed subscription management and BT downloads tracking views are structured and connected to their domain-level runtimes.

## Goals / Non-Goals

**Goals:**
- Construct the `RssPage` showing subscribed feeds and seasonal indexes.
- Construct the `DownloadsPage` displaying torrent progress, piece priority maps, and action controls.
- Connect pages to [RssEngineRuntime](file:///D:/CodeWork/pkpk/lib/src/domain/rss/rss_engine_runtime.dart) and [BtTaskCoreRuntime](file:///D:/CodeWork/pkpk/lib/src/streaming/bt_task_core_runtime.dart).

**Non-Goals:**
- Modifying the underlying torrent piece selection algorithm or RSS scheduler scheduling interval.

## Decisions

### 1. Polling and Throttle for Torrent Speed updates
- **Choice**: The `DownloadsPage` widget will throttle layout rebuilds to a maximum of once every 1000ms.
- **Rationale**: Torrent download speed and peer count change constantly. Restricting UI refreshes to a 1s throttle prevents excessive CPU overhead and keeps rendering lightweight.

### 2. Virtualized RSS Lists
- **Choice**: Use a virtualized list `ListView.builder` for displaying RSS catalog entries.
- **Rationale**: RSS indices (like yuc.wiki) can contain hundreds of anime items. Virtualized lists keep memory footprints small and scroll animations smooth.

## Risks / Trade-offs

- **[Risk] Rapid download progress updates cause UI thread lag** → **Mitigation**: Throttle progress notifications and perform heavy data parsing outside the UI thread, updating only progress percentages.
