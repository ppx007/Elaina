import '../../lib/elaina.dart';
import 'subtitle_provider_runtime_contract.dart';

Future<void> main() async {
  await verifyRssEngineRuntimeContract();
}

Future<void> verifyRssEngineRuntimeContract() async {
  final DateTime now = DateTime.utc(2026, 6, 11, 12);
  final DeterministicRssFeedStore store = DeterministicRssFeedStore();
  final _CheckFeedFetcher fetcher = _CheckFeedFetcher(now);
  final _CheckFeedParser parser = _CheckFeedParser();
  final RssEngineBootstrap bootstrap = RssEngineBootstrap(
    store: store,
    fetcher: fetcher,
    parser: parser,
    scheduler: _CheckFeedScheduler(),
    clock: () => now,
  );

  final FeedSource source = _source();
  _expect((await bootstrap.registerSource(source)).isSuccess,
      'RSS runtime must register sources.');
  _expect(
      (await bootstrap.dueSources()).value?.single.id.value == source.id.value,
      'RSS runtime must project due sources.');
  final Future<List<FeedItem>> updates =
      bootstrap.runtime.updates.take(1).toList();
  final RssEngineActionResult<RssEngineRefreshSnapshot> first =
      await bootstrap.refreshSource(source.id);
  final RssEngineActionResult<RssEngineRefreshSnapshot> second =
      await bootstrap.refreshSource(source.id);
  _expect(first.value?.acceptedItems.single.id.value == 'check-feed-item',
      'RSS runtime must accept parsed feed items.');
  _expect(first.value?.warnings.single == 'check parser warning',
      'RSS runtime must preserve parser warnings.');
  _expect(second.value?.acceptedItems.isEmpty == true,
      'RSS runtime must suppress duplicate feed items.');
  _expect((await updates).single.id.value == 'check-feed-item',
      'RSS runtime must emit accepted updates.');
  _expect(
      (await bootstrap.runtime.cursorSnapshot(source.id)).value?.etag ==
          'etag-v2',
      'RSS runtime must preserve cursor metadata.');

  final RssEngineBootstrap failed = RssEngineBootstrap(
    store: DeterministicRssFeedStore(
        seedSources: <StoredFeedSourceRecord>[_storedSource(source)]),
    fetcher: _FailingFeedFetcher(),
    parser: parser,
    scheduler: _CheckFeedScheduler(),
    clock: () => now,
  );
  final RssEngineActionResult<RssEngineRefreshSnapshot> failure =
      await failed.refreshSource(source.id);
  _expect(failure.failure?.kind == RssEngineRuntimeFailureKind.providerFailure,
      'RSS runtime must normalize provider failures.');

  await bootstrap.dispose();
  await failed.dispose();
  await verifySubtitleProviderRuntimeContract();
}

void _expect(bool condition, String message) {
  if (!condition) throw StateError(message);
}

FeedSource _source() {
  return FeedSource(
    id: const FeedSourceId('check-feed'),
    displayName: 'Check Feed',
    uri: Uri.parse('https://example.test/check.xml'),
    format: FeedFormat.rss,
    refreshInterval: const Duration(hours: 1),
  );
}

StoredFeedSourceRecord _storedSource(FeedSource source) {
  return StoredFeedSourceRecord(
    id: source.id.value,
    displayName: source.displayName,
    uri: source.uri,
    format: source.format.name,
    refreshInterval: source.refreshInterval,
    defaultHeaders: source.defaultHeaders,
  );
}

final class _CheckFeedScheduler implements FeedScheduler {
  @override
  Stream<FeedScheduleDecision> dueSources(Iterable<FeedSource> sources) async* {
    for (final FeedSource source in sources) {
      yield FeedScheduleDecision(
          source: source, dueAt: DateTime.utc(2026, 6, 11, 12));
    }
  }
}

final class _CheckFeedParser implements FeedParser {
  @override
  FeedFormat get format => FeedFormat.rss;

  @override
  Future<FeedParseResult> parse(FeedParseRequest request) {
    return Future<FeedParseResult>.value(FeedParseResult(
      sourceId: request.source.id,
      warnings: const <String>['check parser warning'],
      items: <FeedItem>[
        FeedItem(
          id: const FeedItemId('check-feed-item'),
          sourceId: request.source.id,
          dedupeKey: const FeedDedupeKey('check-dedupe-key'),
          title: 'Check Episode',
          link: Uri.parse('https://example.test/check-episode'),
        ),
      ],
    ));
  }
}

final class _CheckFeedFetcher implements FeedFetcher {
  _CheckFeedFetcher(this.now);

  final DateTime now;
  int count = 0;

  @override
  String get displayName => 'Check Feed Fetcher';

  @override
  ProviderGateway get gateway => throw UnsupportedError(
      'Smoke checker does not expose a provider gateway.');

  @override
  String get id => 'check-feed-fetcher';

  @override
  ProviderKind get kind => ProviderKind.rss;

  @override
  ProviderRegistration get registration => rssProviderRegistration(
      sourceId: const FeedSourceId('check-feed-fetcher'));

  @override
  Future<ProviderGatewayResponse<T>> executeGatewayRequest<T>(
      {required String cacheKey,
      required Future<T> Function() load,
      ProviderCachePolicy cachePolicy = ProviderCachePolicy.networkOnly}) {
    throw UnsupportedError('Smoke checker does not execute gateway requests.');
  }

  @override
  Future<AcgProviderResult<FeedFetchResponse>> fetchFeed(
      FeedFetchRequest request) {
    count += 1;
    return Future<AcgProviderResult<FeedFetchResponse>>.value(
        AcgProviderSuccess<FeedFetchResponse>(FeedFetchResponse(
      sourceId: request.source.id,
      body: '<rss />',
      etag: 'etag-v$count',
      lastModified: now.add(Duration(minutes: count)),
    )));
  }

  @override
  ProviderRequestKey requestKey(String cacheKey) => ProviderRequestKey(
      providerId: const ProviderId('check-feed-fetcher'), cacheKey: cacheKey);
}

final class _FailingFeedFetcher implements FeedFetcher {
  @override
  String get displayName => 'Failing Feed Fetcher';

  @override
  ProviderGateway get gateway => throw UnsupportedError(
      'Smoke checker does not expose a provider gateway.');

  @override
  String get id => 'failing-feed-fetcher';

  @override
  ProviderKind get kind => ProviderKind.rss;

  @override
  ProviderRegistration get registration => rssProviderRegistration(
      sourceId: const FeedSourceId('failing-feed-fetcher'));

  @override
  Future<ProviderGatewayResponse<T>> executeGatewayRequest<T>(
      {required String cacheKey,
      required Future<T> Function() load,
      ProviderCachePolicy cachePolicy = ProviderCachePolicy.networkOnly}) {
    throw UnsupportedError('Smoke checker does not execute gateway requests.');
  }

  @override
  Future<AcgProviderResult<FeedFetchResponse>> fetchFeed(
      FeedFetchRequest request) {
    return Future<AcgProviderResult<FeedFetchResponse>>.value(
        const AcgProviderFailure<FeedFetchResponse>(
      kind: AcgProviderFailureKind.retryable,
      message: 'check provider failure',
    ));
  }

  @override
  ProviderRequestKey requestKey(String cacheKey) => ProviderRequestKey(
      providerId: const ProviderId('failing-feed-fetcher'), cacheKey: cacheKey);
}
