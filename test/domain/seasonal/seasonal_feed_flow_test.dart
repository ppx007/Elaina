import 'dart:io';

import 'package:elaina/elaina.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('refresh composes concrete RSS fetch parse seasonal catalog and queue',
      () async {
    final DeterministicSeasonalCatalogStore catalogStore =
        DeterministicSeasonalCatalogStore();
    final DeterministicBangumiMatchQueueStore queueStore =
        DeterministicBangumiMatchQueueStore();
    final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
    final _RecordingFeedHttpTransport transport = _RecordingFeedHttpTransport(
      responses: <FeedHttpResponse>[
        FeedHttpResponse(
          statusCode: HttpStatus.ok,
          body: _rssBody(guid: 'episode-1', title: 'Seasonal Flow 01'),
          headers: const <String, String>{HttpHeaders.etagHeader: '"etag-v1"'},
        ),
      ],
    );
    final SeasonalFeedFlowBootstrap bootstrap = _bootstrap(
      transport: transport,
      catalogStore: catalogStore,
      queueStore: queueStore,
      cacheInvalidationBus: bus,
    );
    final Future<List<CacheInvalidationEvent>> events =
        bus.events.take(2).toList();

    final SeasonalFeedFlowActionResult<FeedSource> registered =
        await bootstrap.registerSource(_source());
    final SeasonalFeedFlowActionResult<SeasonalFeedFlowRefreshSnapshot>
        refreshed = await bootstrap.refreshSource(_source().id);
    final List<CacheInvalidationEvent> delivered = await events;

    expect(registered.isSuccess, isTrue);
    expect(refreshed.isSuccess, isTrue);
    expect(refreshed.value!.rssRefresh.acceptedItems.single.title,
        'Seasonal Flow 01');
    expect(refreshed.value!.catalogEntries.single.title, 'Seasonal Flow 01');
    expect(refreshed.value!.catalogEntries.single.id.value,
        '$defaultSeasonalCatalogEntryIdPrefix-seasonal-rss::episode-1');
    expect(refreshed.value!.catalogEntries.single.season.kind,
        AnimeSeasonKind.summer);
    expect(refreshed.value!.matchQueue.pendingCount, 1);
    expect((await catalogStore.count()), 1);
    expect((await queueStore.pendingCount()), 1);
    expect((await queueStore.nextPending())?.title, 'Seasonal Flow 01');
    expect(transport.requests.single.headers[HttpHeaders.acceptHeader],
        defaultFeedAcceptHeader);
    expect(delivered.whereType<SeasonalCatalogUpdated>().single.seasonYear,
        _season.year);
    expect(delivered.whereType<BangumiMatchEnqueued>().single.queueItemId,
        refreshed.value!.matchQueue.nextPending?.id);
    expect(
        bootstrap.runtime.currentSnapshot.status, SeasonalFeedFlowStatus.ready);
    await bootstrap.dispose();
    await bus.close();
  });

  test('not-modified refresh updates RSS cursor without consuming new catalog',
      () async {
    final DeterministicSeasonalCatalogStore catalogStore =
        DeterministicSeasonalCatalogStore();
    final DeterministicBangumiMatchQueueStore queueStore =
        DeterministicBangumiMatchQueueStore();
    final _CountingSeasonalConsumer consumer = _CountingSeasonalConsumer();
    final _RecordingFeedHttpTransport transport = _RecordingFeedHttpTransport(
      responses: <FeedHttpResponse>[
        FeedHttpResponse(
          statusCode: HttpStatus.ok,
          body: _rssBody(guid: 'episode-1', title: 'Seasonal Flow 01'),
          headers: const <String, String>{HttpHeaders.etagHeader: '"etag-v1"'},
        ),
        const FeedHttpResponse(
          statusCode: HttpStatus.notModified,
          body: '',
        ),
      ],
    );
    final SeasonalFeedFlowBootstrap bootstrap = _bootstrap(
      transport: transport,
      catalogStore: catalogStore,
      queueStore: queueStore,
      consumers: <SeasonalAnimeConsumer>[consumer],
    );

    await bootstrap.registerSource(_source());
    final SeasonalFeedFlowActionResult<SeasonalFeedFlowRefreshSnapshot> first =
        await bootstrap.refreshSource(_source().id);
    final SeasonalFeedFlowActionResult<SeasonalFeedFlowRefreshSnapshot> second =
        await bootstrap.refreshSource(_source().id);

    expect(first.value!.catalogEntries, hasLength(1));
    expect(second.isSuccess, isTrue);
    expect(second.value!.rssRefresh.acceptedItems, isEmpty);
    expect(second.value!.catalogEntries, isEmpty);
    expect(second.value!.matchQueue.pendingCount, 1);
    expect(consumer.consumeCount, 1);
    expect((await catalogStore.count()), 1);
    expect(transport.requests[1].headers[HttpHeaders.ifNoneMatchHeader],
        '"etag-v1"');
    await bootstrap.dispose();
  });

  test('normalizes missing source and disposed outcomes', () async {
    final SeasonalFeedFlowBootstrap bootstrap = _bootstrap(
      transport: _RecordingFeedHttpTransport(
        responses: <FeedHttpResponse>[
          FeedHttpResponse(
            statusCode: HttpStatus.ok,
            body: _rssBody(guid: 'episode-1', title: 'Seasonal Flow 01'),
          ),
        ],
      ),
    );

    final SeasonalFeedFlowActionResult<SeasonalFeedFlowRefreshSnapshot>
        missing = await bootstrap.refreshSource(_source().id);
    await bootstrap.dispose();
    final SeasonalFeedFlowActionResult<FeedSource> disposed =
        await bootstrap.registerSource(_source());

    expect(missing.kind, SeasonalFeedFlowActionResultKind.failed);
    expect(missing.failure?.kind, SeasonalFeedFlowFailureKind.rssFailure);
    expect(disposed.kind, SeasonalFeedFlowActionResultKind.disposed);
    expect(disposed.failure?.kind, SeasonalFeedFlowFailureKind.disposed);
  });
}

const AnimeSeason _season =
    AnimeSeason(year: 2026, kind: AnimeSeasonKind.summer);

SeasonalFeedFlowBootstrap _bootstrap({
  required FeedHttpTransport transport,
  DeterministicSeasonalCatalogStore? catalogStore,
  DeterministicBangumiMatchQueueStore? queueStore,
  CacheInvalidationBus? cacheInvalidationBus,
  Iterable<SeasonalAnimeConsumer>? consumers,
}) {
  final DeterministicStorageFoundation storage =
      DeterministicStorageFoundation();
  return SeasonalFeedFlowBootstrap(
    rssStore: storage.rssFeed,
    fetcher: HttpFeedFetcher(
      gateway: DeterministicProviderGateway(storage: storage),
      transport: transport,
    ),
    parser: const RssXmlFeedParser(),
    scheduler: _NeverDueFeedScheduler(),
    consumers: consumers ??
        <SeasonalAnimeConsumer>[
          FeedItemSeasonalAnimeConsumer(
            sourceId: SeasonalFeedSourceId(_source().id.value),
            season: _season,
          ),
        ],
    catalogStore: catalogStore ?? DeterministicSeasonalCatalogStore(),
    matchQueueStore: queueStore ?? DeterministicBangumiMatchQueueStore(),
    cacheInvalidationBus: cacheInvalidationBus,
    clock: () => DateTime.utc(2026, 6, 17, 12),
  );
}

FeedSource _source() {
  return FeedSource(
    id: const FeedSourceId('seasonal-rss'),
    displayName: 'Seasonal RSS',
    uri: Uri.parse('https://example.test/seasonal.xml'),
    format: FeedFormat.rss,
    refreshInterval: const Duration(hours: 1),
  );
}

String _rssBody({required String guid, required String title}) {
  return '''
<rss version="2.0">
  <channel>
    <item>
      <title>$title</title>
      <guid>$guid</guid>
      <link>/anime/$guid</link>
      <pubDate>Wed, 17 Jun 2026 12:00:00 GMT</pubDate>
      <description>Seasonal flow summary.</description>
    </item>
  </channel>
</rss>
''';
}

final class _NeverDueFeedScheduler implements FeedScheduler {
  @override
  Stream<FeedScheduleDecision> dueSources(Iterable<FeedSource> sources) {
    return const Stream<FeedScheduleDecision>.empty();
  }
}

final class _CountingSeasonalConsumer implements SeasonalAnimeConsumer {
  _CountingSeasonalConsumer()
      : _delegate = FeedItemSeasonalAnimeConsumer(
          sourceId: SeasonalFeedSourceId(_source().id.value),
          season: _season,
        );

  final FeedItemSeasonalAnimeConsumer _delegate;
  int consumeCount = 0;

  @override
  bool accepts(SeasonalFeedSourceId sourceId) => _delegate.accepts(sourceId);

  @override
  Future<List<SeasonalCatalogEntry>> consume(
    SeasonalFeedSourceId sourceId,
    Iterable<SeasonalSourceItem> items,
  ) {
    consumeCount += 1;
    return _delegate.consume(sourceId, items);
  }
}

final class _RecordingFeedHttpTransport implements FeedHttpTransport {
  _RecordingFeedHttpTransport({required this.responses});

  final List<FeedHttpResponse> responses;
  final List<FeedHttpRequest> requests = <FeedHttpRequest>[];
  int _index = 0;

  @override
  Future<FeedHttpResponse> send(FeedHttpRequest request) {
    requests.add(request);
    final FeedHttpResponse response =
        responses[_index < responses.length ? _index : responses.length - 1];
    _index += 1;
    return Future<FeedHttpResponse>.value(response);
  }
}
