# RSS Fetcher And Parser Composition

Step 46 adds the concrete provider-side RSS/Atom fetch and parse path. It is
not a UI slice and does not add RSS pages, subscription management, automation,
seasonal indexing, BT enqueueing, WebView handling, or source-specific scraper
behavior.

## Composition

App/runtime composition should create a provider fetcher and a parser, then pass
them into the existing RSS engine bootstrap:

```dart
final HttpFeedFetcher fetcher = HttpFeedFetcher(
  gateway: foundationRuntime.gateway,
  transport: HttpFeedHttpTransport(),
);

final RssEngineBootstrap rss = RssEngineBootstrap(
  store: foundationRuntime.storage.rssFeed,
  fetcher: fetcher,
  parser: const RssXmlFeedParser(),
  scheduler: scheduler,
);
```

Use `RssXmlFeedParser` for `FeedFormat.rss` sources and `AtomXmlFeedParser` for
`FeedFormat.atom` sources. The runtime rejects parser/source format mismatch as
a typed parser failure.

## Fetch Behavior

`HttpFeedFetcher` accepts only HTTP and HTTPS `FeedSource.uri` values. It routes
requests through `ProviderGateway`, sends standard RSS/Atom accept headers,
preserves source default headers, and forwards ETag and Last-Modified validators
from `FeedFetchRequest`.

HTTP `304 Not Modified` returns `FeedFetchResponse(notModified: true)` with an
empty body. `DeterministicRssEngine` treats that as a successful refresh, saves
cursor metadata, and does not call the parser.

HTTP throttling, retryable server failures, unsupported schemes, empty bodies,
and malformed XML are normalized into existing provider/RSS failure types.

## Parser Behavior

The RSS parser maps:

- `item/title`
- `item/link`
- `item/guid`
- `item/pubDate`, `published`, or `updated`
- `item/description` or `summary`
- `item/category`
- `item/enclosure`

The Atom parser maps:

- `entry/title`
- `entry/id`
- alternate `entry/link`
- `entry/published` or `updated`
- `entry/summary` or `content`
- `entry/category`
- enclosure `entry/link`

Relative links and enclosure URLs resolve against the feed source URI. Dedupe
keys reuse the existing `FeedDedupeKey` contract and prefer feed identity fields,
then link, then title.

## Boundaries

Concrete HTTP and XML dependencies stay in
`lib/src/provider/rss/rss_feed_fetcher_parser.dart`. Domain RSS runtime code
continues to depend only on `FeedFetcher`, `FeedParser`, `FeedSource`, and store
contracts.

UI code should depend on RSS runtime contracts and snapshots only. It should not
import `HttpFeedFetcher`, `HttpFeedHttpTransport`, `RssXmlFeedParser`,
`AtomXmlFeedParser`, `dart:io`, or `package:xml/xml.dart`.

yuc.wiki remains ordinary `FeedSource` data. This slice does not add a crawler,
scraper, special-case yuc.wiki handling, JavaScript execution, or BT automation.
