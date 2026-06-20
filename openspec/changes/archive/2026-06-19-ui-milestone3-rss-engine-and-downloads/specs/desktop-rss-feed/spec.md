## ADDED Requirements

### Requirement: RSS Page SHALL display feed catalog
The RSS page SHALL show a list of subscribed RSS feed channels and a table of parsed items matching those channels.

#### Scenario: Display subscribed feeds
- **WHEN** the RSS page is loaded
- **THEN** it displays a list of active feed subscriptions retrieved from [RssEngineRuntime](file:///D:/CodeWork/elaina/lib/src/domain/rss/rss_engine_runtime.dart)
- **AND** lists recently parsed catalog items

### Requirement: RSS Page SHALL manage auto download policy
The RSS page SHALL allow users to toggle auto-download filters and match patterns for specific feed subscriptions.

#### Scenario: Enable auto download on feed
- **WHEN** the user enables the auto-download toggle for a selected feed
- **THEN** the UI updates the feed's download policy in [RssAutoDownloadPolicy](file:///D:/CodeWork/elaina/lib/src/provider/rss/rss_auto_download_policy.dart)
