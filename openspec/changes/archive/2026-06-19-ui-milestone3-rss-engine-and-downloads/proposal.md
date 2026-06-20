## Why

Users need a visual interface to manage RSS subscription feeds (including yuc.wiki index updates) and track active BT torrent download progress. Implementing the RSS Engine and Downloads pages is required to achieve the third frontend milestone.

## What Changes

- **RSS Engine UI**: Create the `RssPage` widget to manage feed catalog lists, subscription filters, auto-download rules, and manually trigger feed schedules.
- **RSS Controller Integration**: Connect the page to [RssEngineRuntime](file:///D:/CodeWork/elaina/lib/src/domain/rss/rss_engine_runtime.dart) to display feed updates.
- **Downloads Tracker UI**: Create the `DownloadsPage` widget to list ongoing BT streams, download speeds, peer counts, and active torrent task maps.
- **BT Controller Integration**: Wire the screen to [BtTaskCoreRuntime](file:///D:/CodeWork/elaina/lib/src/streaming/bt_task_core_runtime.dart) to pause/resume tasks.

## Capabilities

### New Capabilities
- `desktop-rss-feed`: Supports managing subscribed feed channels, viewing seasonal catalogs, and updating subscription rules.
- `desktop-downloads-tracking`: Displays active download speeds, progress percentages, active pieces, and peer stats.

### Modified Capabilities
<!-- No requirement changes to existing core specs. -->
