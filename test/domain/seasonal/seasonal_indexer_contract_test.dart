import 'dart:async';

import 'package:elaina/elaina.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('seasonal catalog store persists and dedupes source items', () async {
    final DeterministicSeasonalCatalogStore store =
        DeterministicSeasonalCatalogStore();
    final DateTime updatedAt = DateTime.utc(2026, 6, 4, 12);

    await store.store(_storedEntry(updatedAt: updatedAt));
    await store.store(_storedEntry(updatedAt: updatedAt, title: 'Episode 1b'));

    expect((await store.findById('seasonal-entry'))?.title, 'Episode 1b');
    expect(
      (await store.findBySourceItem(
              sourceId: 'seasonal-rss', sourceItemId: 'feed-item-1'))
          ?.title,
      'Episode 1b',
    );
    expect((await store.entriesForSeason(year: 2026, kind: 'summer')).single.id,
        'seasonal-entry');
    expect(await store.count(), 1);
    expect(await store.remove('seasonal-entry'), isTrue);
    expect(await store.findById('seasonal-entry'), isNull);
  });

  test('bangumi match queue store persists candidates and status', () async {
    final DeterministicBangumiMatchQueueStore store =
        DeterministicBangumiMatchQueueStore();
    final StoredBangumiMatchQueueItemRecord item = _storedQueueItem();

    await store.enqueue(item);
    expect((await store.nextPending())?.id, item.id);
    expect(await store.pendingCount(), 1);

    await store.storeCandidates(
      queueItemId: item.id,
      candidates: const <StoredBangumiMatchCandidateRecord>[
        StoredBangumiMatchCandidateRecord(
            subjectId: 'subject-1', title: 'Seasonal Anime', confidence: 1),
      ],
    );
    expect((await store.candidatesFor(item.id)).single.subjectId, 'subject-1');
    expect((await store.findById(item.id))?.status,
        StoredBangumiMatchQueueStatus.candidatesStored);

    await store.updateStatus(
        queueItemId: item.id, status: StoredBangumiMatchQueueStatus.applied);
    expect(await store.nextPending(), isNull);
  });

  test('seasonal indexer consumes RSS updates persists and enqueues matches',
      () async {
    final _FakeRssEngine rssEngine = _FakeRssEngine();
    final DeterministicSeasonalCatalogStore catalogStore =
        DeterministicSeasonalCatalogStore();
    final DeterministicBangumiMatchQueueStore queueStore =
        DeterministicBangumiMatchQueueStore();
    final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
    final _FakeSeasonalConsumer consumer = _FakeSeasonalConsumer();
    final DeterministicSeasonalIndexer indexer = DeterministicSeasonalIndexer(
      rssEngine: rssEngine,
      consumers: <SeasonalAnimeConsumer>[consumer],
      catalogStore: catalogStore,
      matchQueueStore: queueStore,
      cacheInvalidationBus: bus,
      clock: () => DateTime.utc(2026, 6, 4, 12),
    );

    final Future<List<CacheInvalidationEvent>> events =
        bus.events.take(2).toList();
    await indexer.startListening();
    rssEngine.emit(_feedItem());
    final List<CacheInvalidationEvent> delivered = await events;
    await indexer.stopListening();
    await indexer.close();
    await bus.close();

    expect(consumer.consumedItems.single.id, 'feed-item-1');
    expect((await catalogStore.count()), 1);
    expect((await queueStore.pendingCount()), 1);
    expect(
        delivered.whereType<SeasonalCatalogUpdated>().single.seasonYear, 2026);
    expect(delivered.whereType<BangumiMatchEnqueued>().single.queueItemId,
        'match-seasonal-entry');

    await indexer.processFeedItem(_feedItem());
    expect(await catalogStore.count(), 1);
  });

  test('bangumi match worker searches applies and preserves user priority',
      () async {
    final DeterministicBangumiMatchQueueStore queueStore =
        DeterministicBangumiMatchQueueStore(
      seedItems: <StoredBangumiMatchQueueItemRecord>[_storedQueueItem()],
    );
    final DeterministicProviderBindingStore bindingStore =
        DeterministicProviderBindingStore();
    final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
    final DeterministicBangumiMatchWorker worker =
        DeterministicBangumiMatchWorker(
      queueStore: queueStore,
      bindingStore: bindingStore,
      bangumiProvider: _FakeBangumiProvider(
        subjects: <BangumiSubject>[_subject(title: 'Seasonal Anime')],
      ),
      cacheInvalidationBus: bus,
      clock: () => DateTime.utc(2026, 6, 4, 12),
    );

    final Future<List<CacheInvalidationEvent>> appliedEvents =
        bus.events.take(1).toList();
    final BangumiMatchWorkerResult result = await worker.processNext();
    final List<CacheInvalidationEvent> delivered = await appliedEvents;

    expect(result.isSuccess, isTrue);
    expect(result.matchResult?.outcome, AutomaticBangumiMatchOutcome.applied);
    expect(
        (await bindingStore.bindingFor(const LocalMediaId('seasonal-entry')))
            ?.subjectId
            ?.value,
        'subject-1');
    expect(delivered.single, isA<BangumiMatchApplied>());

    await queueStore.enqueue(_storedQueueItem(
        id: 'queue-user-confirmed', localMediaId: 'confirmed-media'));
    await bindingStore.saveUserConfirmed(
      ProviderBinding(
        id: const ProviderBindingId('confirmed-binding'),
        localMediaId: const LocalMediaId('confirmed-media'),
        providerId: defaultVideoDetailMetadataProviderId,
        subjectId: const ProviderSubjectId('confirmed-subject'),
        authority: ProviderBindingAuthority.userConfirmed,
        confidence: 0.2,
        createdAt: DateTime.utc(2026, 6, 4, 12),
      ),
    );
    final BangumiMatchWorkerResult skipped = await worker.processNext();
    expect(skipped.matchResult?.outcome,
        AutomaticBangumiMatchOutcome.skippedUserConfirmedBinding);

    await queueStore.enqueue(_storedQueueItem(id: 'queue-low-confidence'));
    final DeterministicBangumiMatchWorker lowConfidenceWorker =
        DeterministicBangumiMatchWorker(
      queueStore: queueStore,
      bindingStore: bindingStore,
      bangumiProvider: _FakeBangumiProvider(
        subjects: <BangumiSubject>[_subject(title: 'Different Title')],
      ),
    );
    final BangumiMatchWorkerResult rejected =
        await lowConfidenceWorker.processNext();
    expect(rejected.matchResult?.outcome,
        AutomaticBangumiMatchOutcome.rejectedLowConfidence);
    await bus.close();
  });

  test('bangumi match worker preserves provider failures', () async {
    final DeterministicBangumiMatchQueueStore queueStore =
        DeterministicBangumiMatchQueueStore(
      seedItems: <StoredBangumiMatchQueueItemRecord>[_storedQueueItem()],
    );
    final DeterministicBangumiMatchWorker worker =
        DeterministicBangumiMatchWorker(
      queueStore: queueStore,
      bindingStore: DeterministicProviderBindingStore(),
      bangumiProvider: _FakeBangumiProvider(
        subjects: const <BangumiSubject>[],
        failureKind: AcgProviderFailureKind.throttled,
      ),
    );

    final BangumiMatchWorkerResult result = await worker.processNext();

    expect(result.isSuccess, isFalse);
    expect(result.failure?.kind, AcgProviderFailureKind.throttled);
    expect((await queueStore.findById('queue-item'))?.status,
        StoredBangumiMatchQueueStatus.failed);
  });
}

StoredSeasonalCatalogEntryRecord _storedEntry(
    {required DateTime updatedAt, String title = 'Episode 1'}) {
  return StoredSeasonalCatalogEntryRecord(
    id: 'seasonal-entry',
    seasonYear: 2026,
    seasonKind: 'summer',
    title: title,
    sourceId: 'seasonal-rss',
    sourceItemId: 'feed-item-1',
    link: Uri.parse('https://example.test/seasonal'),
    summary: 'A seasonal anime.',
    officialUri: Uri.parse('https://example.test/official'),
    publishedAt: DateTime.utc(2026, 6, 4, 11),
    updatedAt: updatedAt,
  );
}

StoredBangumiMatchQueueItemRecord _storedQueueItem(
    {String id = 'queue-item', String localMediaId = 'seasonal-entry'}) {
  return StoredBangumiMatchQueueItemRecord(
    id: id,
    seasonalCatalogEntryId: 'seasonal-entry',
    localMediaId: localMediaId,
    title: 'Seasonal Anime',
    status: StoredBangumiMatchQueueStatus.pending,
    enqueuedAt: DateTime.utc(2026, 6, 4, 12),
  );
}

FeedItem _feedItem() {
  return FeedItem(
    id: const FeedItemId('feed-item-1'),
    sourceId: const FeedSourceId('seasonal-rss'),
    dedupeKey: const FeedDedupeKey('feed-item-1'),
    title: 'Seasonal Anime',
    link: Uri.parse('https://example.test/seasonal'),
    publishedAt: DateTime.utc(2026, 6, 4, 11),
    summary: 'A seasonal anime.',
  );
}

BangumiSubject _subject({required String title}) {
  return BangumiSubject(id: const BangumiSubjectId('subject-1'), title: title);
}

final class _FakeSeasonalConsumer implements SeasonalAnimeConsumer {
  final List<SeasonalSourceItem> consumedItems = <SeasonalSourceItem>[];

  @override
  bool accepts(SeasonalFeedSourceId sourceId) =>
      sourceId.value == 'seasonal-rss';

  @override
  Future<List<SeasonalCatalogEntry>> consume(
      SeasonalFeedSourceId sourceId, Iterable<SeasonalSourceItem> items) {
    consumedItems.addAll(items);
    return Future<List<SeasonalCatalogEntry>>.value(
      <SeasonalCatalogEntry>[
        for (final SeasonalSourceItem item in items)
          SeasonalCatalogEntry(
            id: const SeasonalCatalogEntryId('seasonal-entry'),
            season: const AnimeSeason(year: 2026, kind: AnimeSeasonKind.summer),
            title: item.title,
            sourceItem: item,
            summary: item.summary,
            officialUri: item.link,
            publishedAt: item.publishedAt,
          ),
      ],
    );
  }
}

final class _FakeRssEngine implements RssEngineContract {
  final StreamController<FeedItem> _updates =
      StreamController<FeedItem>.broadcast(sync: true);

  @override
  Stream<FeedItem> get updates => _updates.stream;

  void emit(FeedItem item) {
    _updates.add(item);
  }

  @override
  Future<void> registerSource(FeedSource source) => Future<void>.value();

  @override
  Future<RssRefreshOutcome> refreshSource(RssRefreshRequest request) {
    return Future<RssRefreshOutcome>.value(RssRefreshOutcome.success(
        sourceId: request.sourceId, newItems: const <FeedItem>[]));
  }
}

final class _FakeBangumiProvider implements BangumiProvider {
  _FakeBangumiProvider({required this.subjects, this.failureKind});

  final List<BangumiSubject> subjects;
  final AcgProviderFailureKind? failureKind;

  @override
  String get displayName => 'Fake Bangumi Provider';

  @override
  ProviderGateway get gateway => _UnsupportedProviderGateway();

  @override
  String get id => 'fake-bangumi';

  @override
  ProviderKind get kind => ProviderKind.metadata;

  @override
  ProviderRegistration get registration => ProviderRegistration(
        providerId: const ProviderId('fake-bangumi'),
        ratePolicy: const ProviderRatePolicy(
            maxRequests: 12, window: Duration(minutes: 1)),
        retryPolicy: const ProviderRetryPolicy(
            maxAttempts: 3, initialBackoff: Duration(seconds: 1)),
      );

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
  Future<AcgProviderResult<BangumiEpisode>> lookupEpisode(BangumiEpisodeId id) {
    return Future<AcgProviderResult<BangumiEpisode>>.value(
      AcgProviderSuccess<BangumiEpisode>(
        BangumiEpisode(
            id: id,
            subjectId: const BangumiSubjectId('subject-1'),
            index: 1,
            title: 'Episode 1'),
      ),
    );
  }

  @override
  Future<AcgProviderResult<List<BangumiEpisode>>> listEpisodes(
    BangumiSubjectId subjectId,
  ) {
    return Future<AcgProviderResult<List<BangumiEpisode>>>.value(
      AcgProviderSuccess<List<BangumiEpisode>>(
        <BangumiEpisode>[
          BangumiEpisode(
            id: const BangumiEpisodeId('episode-1'),
            subjectId: subjectId,
            index: 1,
            title: 'Episode 1',
          ),
        ],
      ),
    );
  }

  @override
  Future<AcgProviderResult<BangumiSubject>> lookupSubject(BangumiSubjectId id) {
    return Future<AcgProviderResult<BangumiSubject>>.value(
        AcgProviderSuccess<BangumiSubject>(subjects.first));
  }

  @override
  ProviderRequestKey requestKey(String cacheKey) {
    return ProviderRequestKey(
        providerId: const ProviderId('fake-bangumi'), cacheKey: cacheKey);
  }

  @override
  Future<AcgProviderResult<List<BangumiSubject>>> searchSubjects(String query) {
    final AcgProviderFailureKind? kind = failureKind;
    if (kind != null) {
      return Future<AcgProviderResult<List<BangumiSubject>>>.value(
        AcgProviderFailure<List<BangumiSubject>>(
          kind: kind,
          message: 'Search failed.',
        ),
      );
    }
    return Future<AcgProviderResult<List<BangumiSubject>>>.value(
        AcgProviderSuccess<List<BangumiSubject>>(subjects));
  }
}

final class _UnsupportedProviderGateway implements ProviderGateway {
  @override
  StorageFoundation get storage => throw StateError('Storage is not used.');

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
