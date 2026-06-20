## 1. RSS Feed Page Implementation

- [x] 1.1 Create `RssPage` widget conforming to the `desktop-rss-feed` capability spec [UI Layer]
- [x] 1.2 Bind the RSS seasonal feed item listings and auto-download policy switches to [RssEngineRuntime] [UI Layer]

## 2. Downloads Page Implementation

- [x] 2.1 Create `DownloadsPage` widget conforming to the `desktop-downloads-tracking` capability spec [UI Layer]
- [x] 2.2 Bind the BT task manager controls and render download speeds, piece progress bars, and stats from [BtTaskCoreRuntime] [UI Layer]

## 3. Verification and Integration Testing

- [x] 3.1 Write UI widget and controller-backed tests for RSS filter selection and torrent task toggle interactions [UI Layer]
- [x] 3.2 Run repository analysis and layer boundary checkers to ensure zero forbidden concrete backend imports [UI Layer]
