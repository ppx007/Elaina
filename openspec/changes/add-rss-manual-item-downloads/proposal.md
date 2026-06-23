## Why

The RSS page can configure automatic download rules, but it cannot download a
specific feed item on demand or batch-download the currently filtered resource
items. That forces users to leave the RSS workflow for routine manual
downloads and makes the "contains resource" filter less useful than it should
be.

## What Changes

- Add a manual RSS item download API to `RssEngineRuntime`.
- Reuse the existing RSS-to-download enqueuer and torrent URL resolver.
- Expose per-item download and selected batch download controls in the RSS page.
- Keep source recognition shared between RSS filtering, automatic rules, and
  manual downloads.
- Keep the RSS page out of `DownloadRuntime`, BT engines, concrete storage, and
  concrete HTTP torrent fetching.

## Impact

- Affects RSS runtime, RSS auto-download source detection, RSS page UI, stable
  UI ids, and focused RSS tests.
- Does not add torrent file selection inside RSS; detailed file selection
  remains owned by the downloads page.
