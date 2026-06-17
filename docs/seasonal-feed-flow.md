# Seasonal Feed Flow

Step 47 adds the non-UI core flow from RSS refresh to seasonal catalog and
Bangumi match queue projection.

```text
FeedSource -> RssEngineRuntime.refreshSource
  -> accepted FeedItem values
  -> SeasonalIndexerRuntime.processFeedItem
  -> SeasonalCatalogStore + BangumiMatchQueueStore
```

The flow is explicit instead of relying on asynchronous RSS update listeners.
That keeps tests and app composition deterministic: a refresh call returns only
after accepted feed items have been passed through seasonal consumers and the
match queue projection has been read.

## Composition

Create the Step 46 fetcher/parser, then pass them into
`SeasonalFeedFlowBootstrap`:

```dart
final SeasonalFeedFlowBootstrap flow = SeasonalFeedFlowBootstrap(
  rssStore: foundationRuntime.storage.rssFeed,
  fetcher: HttpFeedFetcher(
    gateway: foundationRuntime.gateway,
    transport: HttpFeedHttpTransport(),
  ),
  parser: const RssXmlFeedParser(),
  scheduler: scheduler,
  consumers: <SeasonalAnimeConsumer>[
    FeedItemSeasonalAnimeConsumer(
      sourceId: SeasonalFeedSourceId(feedSource.id.value),
      season: AnimeSeason(year: 2026, kind: AnimeSeasonKind.summer),
    ),
  ],
  catalogStore: foundationRuntime.storage.seasonalCatalog,
  matchQueueStore: foundationRuntime.storage.bangumiMatchQueue,
);

await flow.registerSource(feedSource);
final result = await flow.refreshSource(feedSource.id);
```

Use `RssXmlFeedParser` for RSS sources and `AtomXmlFeedParser` for Atom sources.
The flow itself does not import concrete HTTP or XML packages; those stay in the
provider RSS implementation.

## Consumer Behavior

`FeedItemSeasonalAnimeConsumer` is source-neutral. It accepts one configured
`SeasonalFeedSourceId`, maps accepted feed item title/link/summary/publication
fields into `SeasonalCatalogEntry`, and uses the configured `AnimeSeason`.

Catalog ids are derived from `defaultSeasonalCatalogEntryIdPrefix` plus the feed
item id unless the caller supplies a different prefix.

## Runtime Behavior

`SeasonalFeedFlowRuntime.registerSource` delegates source registration through
`SeasonalIndexerRuntime`, which registers the source with the underlying RSS
runtime when created through `SeasonalIndexerBootstrap.fromRssRuntime`.

`SeasonalFeedFlowRuntime.refreshSource`:

- refreshes the RSS source;
- consumes only accepted RSS refresh items;
- returns success with no new catalog entries for not-modified refreshes;
- projects pending Bangumi match queue state;
- returns typed failure/disposed outcomes instead of leaking raw exceptions.

## Boundaries

This flow does not implement RSS pages, subscription UI, yuc.wiki scraping,
RSS auto-download, BT enqueueing, online rules, WebView, diagnostics, network
policy, or native-player behavior.

UI-owned code should depend on `SeasonalFeedFlowRuntime`,
`SeasonalFeedFlowSnapshot`, and existing seasonal/RSS projections. It should not
import `HttpFeedFetcher`, concrete transports, XML parser packages, or storage
implementations directly.
