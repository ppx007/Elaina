## ADDED Requirements

### Requirement: Seasonal anime flow SHALL connect RSS refresh to Bangumi queue
The seasonal anime indexer SHALL support a concrete non-UI flow from RSS source
refresh through seasonal catalog persistence and Bangumi match queue enqueueing.

#### Scenario: RSS source produces accepted seasonal items
- **WHEN** an RSS source refresh produces accepted feed items
- **THEN** the seasonal flow converts those items into catalog entries, stores
  them, enqueues Bangumi match work, and exposes the resulting queue projection
  without requiring RSS pages, UI subscription management, RSS auto-download,
  BT tasks, online-rule evaluation, diagnostics, WebView, or native-player
  integrations
