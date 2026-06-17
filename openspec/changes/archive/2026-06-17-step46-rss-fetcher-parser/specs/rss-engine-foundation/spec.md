## ADDED Requirements

### Requirement: RSS foundation SHALL provide concrete feed fetch and XML parse adapters
The RSS foundation SHALL include Provider-layer concrete adapters for HTTP feed
fetching and RSS/Atom XML parsing while preserving the existing feed contracts.

#### Scenario: Concrete feed adapters are composed
- **WHEN** an app composition root supplies the concrete HTTP feed fetcher and
  RSS or Atom XML parser to `RssEngineBootstrap`
- **THEN** the runtime refreshes through `FeedFetcher` and `FeedParser`
  contracts, preserves source-neutral `FeedItem` output, and keeps concrete
  transport and XML parsing details outside `lib/src/domain/rss/**`, UI,
  seasonal indexing, RSS auto-download, BT, online-rule, diagnostics, WebView,
  network-policy, and native-player implementations

### Requirement: RSS foundation SHALL parse RSS and Atom feed item metadata
Concrete RSS and Atom parsers SHALL project feed entries into existing
`FeedItem` values with stable identity, dedupe keys, links, dates, summaries,
categories, and optional enclosures. Dedupe identity SHALL prefer GUID/id, then
link, then title fallback when a feed item lacks explicit identity fields.

#### Scenario: XML feed is parsed
- **WHEN** a supported RSS channel item or Atom entry contains title,
  GUID/id/link, date metadata, categories/tags, summary text, and enclosure
  metadata
- **THEN** parsing returns source-neutral `FeedItem` values without adding
  source-specific scraper models or downstream seasonal/automation behavior
