import 'dart:io';

import '../lib/celesteria.dart';

Future<void> main() async {
  final SeasonalFeedFlowSmokeResult result = await runSeasonalFeedFlowSmoke();
  stdout.writeln(
    'Seasonal feed flow passed: '
    '${result.catalogEntryCount} catalog entries, '
    '${result.pendingMatchCount} pending Bangumi match.',
  );
}

final class SeasonalFeedFlowSmokeResult {
  const SeasonalFeedFlowSmokeResult({
    required this.catalogEntryCount,
    required this.pendingMatchCount,
    required this.notModifiedCatalogEntryCount,
  });

  final int catalogEntryCount;
  final int pendingMatchCount;
  final int notModifiedCatalogEntryCount;
}

Future<SeasonalFeedFlowSmokeResult> runSeasonalFeedFlowSmoke() async {
  final DeterministicStorageFoundation storage =
      DeterministicStorageFoundation();
  final _SmokeFeedHttpTransport transport = _SmokeFeedHttpTransport(
    responses: <FeedHttpResponse>[
      FeedHttpResponse(
        statusCode: HttpStatus.ok,
        body: _rssBody(),
        headers: const <String, String>{HttpHeaders.etagHeader: '"etag-v1"'},
      ),
      const FeedHttpResponse(statusCode: HttpStatus.notModified, body: ''),
    ],
  );
  final DeterministicSeasonalCatalogStore catalogStore =
      DeterministicSeasonalCatalogStore();
  final DeterministicBangumiMatchQueueStore queueStore =
      DeterministicBangumiMatchQueueStore();
  final SeasonalFeedFlowBootstrap bootstrap = SeasonalFeedFlowBootstrap(
    rssStore: storage.rssFeed,
    fetcher: HttpFeedFetcher(
      gateway: DeterministicProviderGateway(storage: storage),
      transport: transport,
    ),
    parser: const RssXmlFeedParser(),
    scheduler: _SmokeFeedScheduler(),
    consumers: const <SeasonalAnimeConsumer>[
      FeedItemSeasonalAnimeConsumer(
        sourceId: SeasonalFeedSourceId('seasonal-flow-check'),
        season: AnimeSeason(year: 2026, kind: AnimeSeasonKind.summer),
      ),
    ],
    catalogStore: catalogStore,
    matchQueueStore: queueStore,
    clock: () => DateTime.utc(2026, 6, 17, 12),
  );
  final FeedSource source = _source();

  try {
    _expect(
      (await bootstrap.registerSource(source)).isSuccess,
      'Seasonal flow must register RSS source.',
    );
    final SeasonalFeedFlowActionResult<SeasonalFeedFlowRefreshSnapshot> first =
        await bootstrap.refreshSource(source.id);
    _expect(first.isSuccess, 'Seasonal flow first refresh must succeed.');
    _expect(
      first.value?.catalogEntries.single.title == 'Seasonal Flow Check',
      'Seasonal flow must project RSS item into catalog entry.',
    );
    _expect(
      first.value?.matchQueue.pendingCount == 1,
      'Seasonal flow must enqueue Bangumi match work.',
    );

    final SeasonalFeedFlowActionResult<SeasonalFeedFlowRefreshSnapshot> second =
        await bootstrap.refreshSource(source.id);
    _expect(
        second.isSuccess, 'Seasonal flow not-modified refresh must succeed.');
    _expect(
      second.value?.catalogEntries.isEmpty == true,
      'Not-modified refresh must not consume new seasonal entries.',
    );
    _expect(
      transport.requests[1].headers[HttpHeaders.ifNoneMatchHeader] ==
          '"etag-v1"',
      'Seasonal flow must preserve RSS validators through Step 46 fetcher.',
    );

    return SeasonalFeedFlowSmokeResult(
      catalogEntryCount: await catalogStore.count(),
      pendingMatchCount: await queueStore.pendingCount(),
      notModifiedCatalogEntryCount: second.value?.catalogEntries.length ?? -1,
    );
  } finally {
    await bootstrap.dispose();
  }
}

FeedSource _source() {
  return FeedSource(
    id: const FeedSourceId('seasonal-flow-check'),
    displayName: 'Seasonal Flow Check',
    uri: Uri.parse('https://example.test/seasonal-flow.xml'),
    format: FeedFormat.rss,
    refreshInterval: const Duration(hours: 1),
  );
}

String _rssBody() {
  return '''
<rss version="2.0">
  <channel>
    <item>
      <title>Seasonal Flow Check</title>
      <guid>seasonal-flow-check-01</guid>
      <link>/seasonal-flow-check-01</link>
      <pubDate>Wed, 17 Jun 2026 12:00:00 GMT</pubDate>
      <description>Seasonal flow smoke item.</description>
    </item>
  </channel>
</rss>
''';
}

void _expect(bool condition, String message) {
  if (!condition) throw StateError(message);
}

final class _SmokeFeedScheduler implements FeedScheduler {
  @override
  Stream<FeedScheduleDecision> dueSources(Iterable<FeedSource> sources) {
    return const Stream<FeedScheduleDecision>.empty();
  }
}

final class _SmokeFeedHttpTransport implements FeedHttpTransport {
  _SmokeFeedHttpTransport({required this.responses});

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
