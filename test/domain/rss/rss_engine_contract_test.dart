import 'package:celesteria/celesteria.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('deterministic RSS store persists sources items cursors and dedupe keys',
      () async {
    final DeterministicRssFeedStore store = DeterministicRssFeedStore();
    final DateTime observedAt = DateTime.utc(2026, 6, 4, 12);

    await store.storeSource(_storedSource());
    await store.saveCursor(
      StoredFeedCursorRecord(
        sourceId: 'anime-feed',
        etag: 'etag-v1',
        lastModified: observedAt,
        refreshedAt: observedAt,
      ),
    );
    await store.recordDedupeKey(StoredFeedDedupeKeyRecord(
        sourceId: 'anime-feed', dedupeKey: 'item-1', acceptedAt: observedAt));
    await store.storeItems(
        <StoredFeedItemRecord>[_storedItem(acceptedAt: observedAt)]);

    expect((await store.sourceById('anime-feed'))?.displayName, 'Anime Feed');
    expect((await store.listSources()).single.id, 'anime-feed');
    expect((await store.cursorFor('anime-feed'))?.etag, 'etag-v1');
    expect(
        await store.hasDedupeKey(sourceId: 'anime-feed', dedupeKey: 'item-1'),
        isTrue);
    expect((await store.dedupeKeysForSource('anime-feed')).single.dedupeKey,
        'item-1');
    expect(
        (await store.itemsForSource('anime-feed')).single.title, 'Episode 1');
  });

  test(
      'RSS engine refreshes fetches parses persists emits and replays cursor metadata',
      () async {
    final DeterministicRssFeedStore store = DeterministicRssFeedStore();
    final FeedItem item = _feedItem();
    final DateTime refreshedAt = DateTime.utc(2026, 6, 4, 12);
    final _FakeFeedFetcher fetcher = _FakeFeedFetcher(
      responses: <AcgProviderResult<FeedFetchResponse>>[
        FeedFetchResponse(
                sourceId: const FeedSourceId('anime-feed'),
                body: '<rss />',
                etag: 'etag-v1',
                lastModified: refreshedAt)
            .success,
        FeedFetchResponse(
                sourceId: const FeedSourceId('anime-feed'),
                body: '<rss />',
                etag: 'etag-v2',
                lastModified: refreshedAt.add(const Duration(minutes: 30)))
            .success,
      ],
    );
    final _FakeFeedParser parser = _FakeFeedParser(
        items: <FeedItem>[item], warnings: const <String>['runtime warning']);
    final DeterministicRssEngine engine = DeterministicRssEngine(
      store: store,
      fetcher: fetcher,
      parser: parser,
      deduplicator: DeterministicFeedDeduplicator(),
      clock: () => refreshedAt,
    );

    await engine.registerSource(_source());
    final Future<List<FeedItem>> updates = engine.updates.take(1).toList();
    final RssRefreshOutcome first = await engine.refreshSource(
        const RssRefreshRequest(sourceId: FeedSourceId('anime-feed')));
    final RssRefreshOutcome second = await engine.refreshSource(
        const RssRefreshRequest(sourceId: FeedSourceId('anime-feed')));
    final List<FeedItem> emitted = await updates;
    await engine.close();

    expect(first.isSuccess, isTrue);
    expect(first.newItems.single, item);
    expect(first.warnings.single, 'runtime warning');
    expect(emitted.single, item);
    expect(
        (await store.itemsForSource('anime-feed')).single.dedupeKey, 'item-1');
    expect((await store.cursorFor('anime-feed'))?.etag, 'etag-v2');
    expect(fetcher.requests.first.etag, isNull);
    expect(fetcher.requests[1].etag, 'etag-v1');
    expect(fetcher.requests[1].lastModified, refreshedAt);
    expect(parser.requests.length, 2);
    expect(second.newItems, isEmpty);
  });

  test('RSS engine preserves gateway-normalized provider failures', () async {
    final DeterministicRssEngine engine = DeterministicRssEngine(
      store: DeterministicRssFeedStore(
          seedSources: <StoredFeedSourceRecord>[_storedSource()]),
      fetcher: _FakeFeedFetcher(
        responses: const <AcgProviderResult<FeedFetchResponse>>[
          AcgProviderFailure<FeedFetchResponse>(
              kind: AcgProviderFailureKind.retryable,
              message: 'temporary feed failure'),
        ],
      ),
      parser: _FakeFeedParser(items: const <FeedItem>[]),
      deduplicator: DeterministicFeedDeduplicator(),
      clock: () => DateTime.utc(2026, 6, 4, 12),
    );

    final RssRefreshOutcome result = await engine.refreshSource(
        const RssRefreshRequest(sourceId: FeedSourceId('anime-feed')));
    await engine.close();

    expect(result.isSuccess, isFalse);
    expect(result.failure?.kind, AcgProviderFailureKind.retryable);
    expect(result.failure?.message, 'temporary feed failure');
  });
}

extension on FeedFetchResponse {
  AcgProviderSuccess<FeedFetchResponse> get success =>
      AcgProviderSuccess<FeedFetchResponse>(this);
}

FeedSource _source() {
  return FeedSource(
    id: const FeedSourceId('anime-feed'),
    displayName: 'Anime Feed',
    uri: Uri.parse('https://example.test/rss.xml'),
    format: FeedFormat.rss,
    refreshInterval: const Duration(hours: 1),
  );
}

StoredFeedSourceRecord _storedSource() {
  final FeedSource source = _source();
  return StoredFeedSourceRecord(
    id: source.id.value,
    displayName: source.displayName,
    uri: source.uri,
    format: source.format.name,
    refreshInterval: source.refreshInterval,
    defaultHeaders: source.defaultHeaders,
  );
}

FeedItem _feedItem() {
  return FeedItem(
    id: const FeedItemId('feed-item-1'),
    sourceId: const FeedSourceId('anime-feed'),
    dedupeKey: const FeedDedupeKey('item-1'),
    title: 'Episode 1',
    link: Uri.parse('https://example.test/episode-1'),
    publishedAt: DateTime.utc(2026, 6, 4, 11),
    summary: 'A new episode.',
    categories: const <String>['anime'],
    enclosure: FeedEnclosure(
        uri: Uri.parse('https://example.test/episode-1.torrent'),
        mimeType: 'application/x-bittorrent',
        lengthBytes: 42),
  );
}

StoredFeedItemRecord _storedItem({required DateTime acceptedAt}) {
  final FeedItem item = _feedItem();
  return StoredFeedItemRecord(
    id: item.id.value,
    sourceId: item.sourceId.value,
    dedupeKey: item.dedupeKey.value,
    title: item.title,
    link: item.link,
    publishedAt: item.publishedAt,
    summary: item.summary,
    categories: item.categories,
    enclosure: StoredFeedEnclosureRecord(
      uri: item.enclosure!.uri,
      mimeType: item.enclosure!.mimeType,
      lengthBytes: item.enclosure!.lengthBytes,
    ),
    acceptedAt: acceptedAt,
  );
}

final class _FakeFeedParser implements FeedParser {
  _FakeFeedParser({required this.items, this.warnings = const <String>[]});

  final List<FeedItem> items;
  final List<String> warnings;
  final List<FeedParseRequest> requests = <FeedParseRequest>[];

  @override
  FeedFormat get format => FeedFormat.rss;

  @override
  Future<FeedParseResult> parse(FeedParseRequest request) {
    requests.add(request);
    return Future<FeedParseResult>.value(FeedParseResult(
        sourceId: request.source.id, items: items, warnings: warnings));
  }
}

final class _FakeFeedFetcher implements FeedFetcher {
  _FakeFeedFetcher({required this.responses});

  final List<AcgProviderResult<FeedFetchResponse>> responses;
  final List<FeedFetchRequest> requests = <FeedFetchRequest>[];
  int _index = 0;

  @override
  String get displayName => 'Fake Feed Fetcher';

  @override
  ProviderGateway get gateway => _UnsupportedProviderGateway();

  @override
  String get id => 'fake-feed-fetcher';

  @override
  ProviderKind get kind => ProviderKind.rss;

  @override
  ProviderRegistration get registration => rssProviderRegistration(
      sourceId: const FeedSourceId('fake-feed-fetcher'));

  @override
  Future<ProviderGatewayResponse<T>> executeGatewayRequest<T>({
    required String cacheKey,
    required Future<T> Function() load,
    ProviderCachePolicy cachePolicy = ProviderCachePolicy.networkOnly,
  }) {
    return load().then((T value) => ProviderGatewayResponse<T>(
        value: value, source: ProviderGatewayResponseSource.network));
  }

  @override
  Future<AcgProviderResult<FeedFetchResponse>> fetchFeed(
      FeedFetchRequest request) {
    requests.add(request);
    final AcgProviderResult<FeedFetchResponse> response =
        responses[_index < responses.length ? _index : responses.length - 1];
    _index += 1;
    return Future<AcgProviderResult<FeedFetchResponse>>.value(response);
  }

  @override
  ProviderRequestKey requestKey(String cacheKey) {
    return ProviderRequestKey(
        providerId: const ProviderId('fake-feed-fetcher'), cacheKey: cacheKey);
  }
}

final class _UnsupportedProviderGateway implements ProviderGateway {
  @override
  StorageFoundation get storage =>
      throw StateError('Storage is not used by this test gateway.');

  @override
  Future<ProviderGatewayResponse<T>> execute<T>(
      ProviderGatewayRequest<T> request) async {
    return ProviderGatewayResponse<T>(
        value: await request.load(),
        source: ProviderGatewayResponseSource.network);
  }

  @override
  Future<void> registerProvider(ProviderRegistration registration) =>
      Future<void>.value();
}
