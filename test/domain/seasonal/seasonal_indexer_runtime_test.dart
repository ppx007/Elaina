import 'dart:async';

import 'package:elaina/elaina.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('registers YucWiki as an ordinary feed source with immutable snapshots',
      () async {
    final _FakeRssEngine rssEngine = _FakeRssEngine();
    final SeasonalIndexerRuntime runtime = _runtime(rssEngine: rssEngine);
    final _RuntimeObserver observer = _RuntimeObserver();
    runtime.addObserver(observer);

    final SeasonalIndexerActionResult<FeedSource> registered =
        await runtime.registerYucWikiSource();
    final List<FeedSource> snapshotSources =
        runtime.currentSnapshot.registeredSources;
    runtime.removeObserver(observer);
    final SeasonalIndexerActionResult<FeedSource> registeredAgain =
        await runtime.registerYucWikiSource();

    expect(registered.isSuccess, isTrue);
    expect(registered.value?.id.value, yucWikiSeasonalFeedSource.id.value);
    expect(
        rssEngine.registered.map((FeedSource source) => source.id.value),
        <String>[
          yucWikiSeasonalFeedSource.id.value,
          yucWikiSeasonalFeedSource.id.value
        ]);
    expect(snapshotSources.single.id.value, yucWikiSeasonalFeedSource.id.value);
    expect(() => snapshotSources.clear(), throwsUnsupportedError);
    expect(runtime.currentSnapshot.registeredSources, hasLength(1));
    expect(registeredAgain.isSuccess, isTrue);
    expect(
      observer.snapshots
          .map((SeasonalIndexerRuntimeSnapshot snapshot) => snapshot.status),
      containsAllInOrder(<SeasonalIndexerRuntimeStatus>[
        SeasonalIndexerRuntimeStatus.registering,
        SeasonalIndexerRuntimeStatus.ready,
      ]),
    );
    await runtime.dispose();
  });

  test(
      'processes explicit feed items through consumer dispatch and persists once',
      () async {
    final DeterministicSeasonalCatalogStore catalogStore =
        DeterministicSeasonalCatalogStore();
    final DeterministicBangumiMatchQueueStore queueStore =
        DeterministicBangumiMatchQueueStore();
    final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
    final _FakeSeasonalConsumer consumer = _FakeSeasonalConsumer();
    final SeasonalIndexerRuntime runtime = _runtime(
      catalogStore: catalogStore,
      matchQueueStore: queueStore,
      consumers: <SeasonalAnimeConsumer>[consumer],
      cacheInvalidationBus: bus,
    );

    final Future<List<CacheInvalidationEvent>> events =
        bus.events.take(2).toList();
    final SeasonalIndexerActionResult<List<SeasonalCatalogEntry>> first =
        await runtime.processFeedItem(_feedItem());
    final SeasonalIndexerActionResult<List<SeasonalCatalogEntry>> duplicate =
        await runtime.processFeedItem(_feedItem());
    final SeasonalIndexerActionResult<SeasonalCatalogProjection> listed =
        await runtime.listCatalogEntries();
    final SeasonalIndexerActionResult<SeasonalCatalogProjection> bySeason =
        await runtime.catalogForSeason(
            const AnimeSeason(year: 2026, kind: AnimeSeasonKind.summer));
    final SeasonalIndexerActionResult<BangumiMatchQueueProjection> queue =
        await runtime.pendingMatchQueue();
    final List<CacheInvalidationEvent> delivered = await events;

    expect(first.value?.single.id.value, 'seasonal-entry-feed-item-1');
    expect(duplicate.value, isEmpty);
    expect(consumer.consumedItems.map((SeasonalSourceItem item) => item.id),
        <String>['feed-item-1', 'feed-item-1']);
    expect(await catalogStore.count(), 1);
    expect(listed.value?.entries.single.title, 'Seasonal Anime');
    expect(
        bySeason.value?.entries.single.id.value, 'seasonal-entry-feed-item-1');
    expect(() => listed.value!.entries.clear(), throwsUnsupportedError);
    expect(queue.value?.pendingCount, 1);
    expect(queue.value?.nextPending?.id, 'match-seasonal-entry-feed-item-1');
    expect(
        runtime.currentSnapshot.catalogEntries.single.title, 'Seasonal Anime');
    expect(runtime.currentSnapshot.matchQueue?.pendingCount, 1);
    expect(delivered.whereType<SeasonalCatalogUpdated>().single.seasonKind,
        AnimeSeasonKind.summer.name);
    expect(delivered.whereType<BangumiMatchEnqueued>().single.queueItemId,
        'match-seasonal-entry-feed-item-1');
    await runtime.dispose();
    await bus.close();
  });

  test('suppresses duplicates after store reuse', () async {
    final DeterministicSeasonalCatalogStore catalogStore =
        DeterministicSeasonalCatalogStore();
    final DeterministicBangumiMatchQueueStore queueStore =
        DeterministicBangumiMatchQueueStore();
    final SeasonalIndexerRuntime firstRuntime = _runtime(
      catalogStore: catalogStore,
      matchQueueStore: queueStore,
    );
    await firstRuntime.processFeedItem(_feedItem());
    await firstRuntime.dispose();

    final SeasonalIndexerRuntime reusedRuntime = _runtime(
      catalogStore: catalogStore,
      matchQueueStore: queueStore,
    );
    final SeasonalIndexerActionResult<List<SeasonalCatalogEntry>> reused =
        await reusedRuntime.processFeedItem(_feedItem());

    expect(reused.isSuccess, isTrue);
    expect(reused.value, isEmpty);
    expect(await catalogStore.count(), 1);
    expect(await queueStore.pendingCount(), 1);
    await reusedRuntime.dispose();
  });

  test('observes catalog updates and starts and stops RSS update listening',
      () async {
    final _FakeRssEngine rssEngine = _FakeRssEngine();
    final SeasonalIndexerRuntime runtime = _runtime(rssEngine: rssEngine);
    final SeasonalIndexerActionResult<SeasonalCatalogUpdateObservation>
        observation = runtime.observeCatalogUpdates();
    final Future<List<SeasonalCatalogEntry>> observed =
        observation.value!.updates.take(1).toList();

    final SeasonalIndexerActionResult<bool> started =
        await runtime.startListening();
    rssEngine.emit(_feedItem(id: 'feed-item-stream'));
    final List<SeasonalCatalogEntry> delivered = await observed;
    final SeasonalIndexerActionResult<bool> duplicateStart =
        await runtime.startListening();
    final SeasonalIndexerActionResult<bool> stopped =
        await runtime.stopListening();
    rssEngine.emit(_feedItem(id: 'feed-item-after-stop'));
    await pumpEventQueue();
    final SeasonalIndexerActionResult<SeasonalCatalogProjection> catalog =
        await runtime.listCatalogEntries();

    expect(started.isSuccess, isTrue);
    expect(runtime.isListening, isFalse);
    expect(duplicateStart.kind, SeasonalIndexerActionResultKind.ignored);
    expect(stopped.isSuccess, isTrue);
    expect(delivered.single.id.value, 'seasonal-entry-feed-item-stream');
    expect(
        catalog.value?.entries
            .map((SeasonalCatalogEntry entry) => entry.id.value),
        <String>['seasonal-entry-feed-item-stream']);
    await runtime.dispose();
  });

  test(
      'normalizes missing consumer, consumer failure, unavailable match worker, and disposed behavior',
      () async {
    final SeasonalIndexerRuntime missingConsumer = _runtime(
      consumers: <SeasonalAnimeConsumer>[
        _FakeSeasonalConsumer(acceptedSourceId: 'other-source')
      ],
    );
    final SeasonalIndexerActionResult<List<SeasonalCatalogEntry>> ignored =
        await missingConsumer.processFeedItem(_feedItem());
    final SeasonalIndexerActionResult<BangumiMatchWorkerResult> unavailable =
        await missingConsumer.processNextBangumiMatch();
    await missingConsumer.dispose();
    final SeasonalIndexerActionResult<SeasonalCatalogProjection> disposed =
        await missingConsumer.listCatalogEntries();

    final SeasonalIndexerRuntime failingConsumer = _runtime(
      consumers: <SeasonalAnimeConsumer>[_ThrowingSeasonalConsumer()],
    );
    final SeasonalIndexerActionResult<List<SeasonalCatalogEntry>> failed =
        await failingConsumer.processFeedItem(_feedItem());

    expect(ignored.kind, SeasonalIndexerActionResultKind.ignored);
    expect(ignored.failure?.kind, SeasonalIndexerRuntimeFailureKind.ignored);
    expect(unavailable.kind, SeasonalIndexerActionResultKind.unavailable);
    expect(disposed.kind, SeasonalIndexerActionResultKind.disposed);
    expect(disposed.failure?.kind, SeasonalIndexerRuntimeFailureKind.disposed);
    expect(failed.kind, SeasonalIndexerActionResultKind.failed);
    expect(failed.failure?.kind,
        SeasonalIndexerRuntimeFailureKind.consumerFailure);
    await failingConsumer.dispose();
  });

  test('projects match queue and normalizes provider failure in runtime worker',
      () async {
    final DeterministicBangumiMatchQueueStore queueStore =
        DeterministicBangumiMatchQueueStore(
      seedItems: <StoredBangumiMatchQueueItemRecord>[_storedQueueItem()],
    );
    final SeasonalIndexerRuntime runtime = _runtime(
      matchQueueStore: queueStore,
      bindingStore: DeterministicProviderBindingStore(),
      matchWorker: DeterministicBangumiMatchWorker(
        queueStore: queueStore,
        bindingStore: DeterministicProviderBindingStore(),
        bangumiProvider: _FakeBangumiProvider(
          subjects: const <BangumiSubject>[],
          failureKind: AcgProviderFailureKind.throttled,
        ),
      ),
    );

    final SeasonalIndexerActionResult<BangumiMatchQueueProjection> projection =
        await runtime.pendingMatchQueue();
    final SeasonalIndexerActionResult<BangumiMatchWorkerResult> failed =
        await runtime.processNextBangumiMatch();

    expect(projection.value?.pendingCount, 1);
    expect(projection.value?.nextPending?.id, 'queue-item');
    expect(failed.kind, SeasonalIndexerActionResultKind.failed);
    expect(
        failed.failure?.kind, SeasonalIndexerRuntimeFailureKind.matchFailure);
    expect(failed.value, isNull);
    expect(runtime.currentSnapshot.latestMatchResult?.failure?.kind,
        AcgProviderFailureKind.throttled);
    expect((await queueStore.findById('queue-item'))?.status,
        StoredBangumiMatchQueueStatus.failed);
    await runtime.dispose();
  });

  test(
      'preserves user-confirmed bindings, rejects low confidence, and applies matches with cache events',
      () async {
    final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
    final DeterministicProviderBindingStore bindingStore =
        DeterministicProviderBindingStore();
    final DeterministicBangumiMatchQueueStore queueStore =
        DeterministicBangumiMatchQueueStore(
      seedItems: <StoredBangumiMatchQueueItemRecord>[
        _storedQueueItem(
            id: 'queue-user-confirmed', localMediaId: 'confirmed-media'),
        _storedQueueItem(id: 'queue-low-confidence', localMediaId: 'low-media'),
        _storedQueueItem(id: 'queue-applied', localMediaId: 'applied-media'),
      ],
    );
    await bindingStore.saveUserConfirmed(
      ProviderBinding(
        id: const ProviderBindingId('confirmed-binding'),
        localMediaId: const LocalMediaId('confirmed-media'),
        providerId: 'bangumi',
        subjectId: const ProviderSubjectId('confirmed-subject'),
        authority: ProviderBindingAuthority.userConfirmed,
        confidence: 0.1,
        createdAt: _now(),
      ),
    );

    final SeasonalIndexerRuntime skippedRuntime = _runtime(
      matchQueueStore: queueStore,
      bindingStore: bindingStore,
      matchWorker: DeterministicBangumiMatchWorker(
        queueStore: queueStore,
        bindingStore: bindingStore,
        bangumiProvider: _FakeBangumiProvider(
            subjects: <BangumiSubject>[_subject('Seasonal Anime')]),
        cacheInvalidationBus: bus,
        clock: _now,
      ),
    );
    final SeasonalIndexerActionResult<BangumiMatchWorkerResult> skipped =
        await skippedRuntime.processNextBangumiMatch();
    final SeasonalIndexerActionResult<BangumiMatchWorkerResult> lowConfidence =
        await skippedRuntime.processNextBangumiMatch();

    final Future<List<CacheInvalidationEvent>> appliedEvents =
        bus.events.take(1).toList();
    final SeasonalIndexerActionResult<BangumiMatchWorkerResult> applied =
        await skippedRuntime.processNextBangumiMatch();
    final List<CacheInvalidationEvent> delivered = await appliedEvents;

    expect(skipped.value?.matchResult?.outcome,
        AutomaticBangumiMatchOutcome.skippedUserConfirmedBinding);
    expect((await queueStore.findById('queue-user-confirmed'))?.status,
        StoredBangumiMatchQueueStatus.skippedUserConfirmedBinding);
    expect(
        (await bindingStore.bindingFor(const LocalMediaId('confirmed-media')))
            ?.subjectId
            ?.value,
        'confirmed-subject');
    expect(lowConfidence.value?.matchResult?.outcome,
        AutomaticBangumiMatchOutcome.rejectedLowConfidence);
    expect((await queueStore.findById('queue-low-confidence'))?.status,
        StoredBangumiMatchQueueStatus.rejectedLowConfidence);
    expect(applied.value?.matchResult?.outcome,
        AutomaticBangumiMatchOutcome.applied);
    expect((await queueStore.candidatesFor('queue-applied')).single.subjectId,
        'subject-Seasonal-Anime');
    expect(
        (await bindingStore.bindingFor(const LocalMediaId('applied-media')))
            ?.subjectId
            ?.value,
        'subject-Seasonal-Anime');
    expect(delivered.single, isA<BangumiMatchApplied>());
    await skippedRuntime.dispose();
    await bus.close();
  });
}

SeasonalIndexerRuntime _runtime({
  RssEngineContract? rssEngine,
  Iterable<SeasonalAnimeConsumer>? consumers,
  DeterministicSeasonalCatalogStore? catalogStore,
  DeterministicBangumiMatchQueueStore? matchQueueStore,
  ProviderBindingStore? bindingStore,
  BangumiMatchWorkerContract? matchWorker,
  CacheInvalidationBus? cacheInvalidationBus,
}) {
  return SeasonalIndexerRuntime(
    rssEngine: rssEngine ?? _FakeRssEngine(),
    consumers: consumers ?? <SeasonalAnimeConsumer>[_FakeSeasonalConsumer()],
    catalogStore: catalogStore ?? DeterministicSeasonalCatalogStore(),
    matchQueueStore: matchQueueStore ?? DeterministicBangumiMatchQueueStore(),
    bindingStore: bindingStore,
    matchWorker: matchWorker,
    cacheInvalidationBus: cacheInvalidationBus,
    clock: _now,
  );
}

DateTime _now() => DateTime.utc(2026, 6, 11, 12);

FeedItem _feedItem(
    {String id = 'feed-item-1', String sourceId = 'seasonal-rss'}) {
  return FeedItem(
    id: FeedItemId(id),
    sourceId: FeedSourceId(sourceId),
    dedupeKey: FeedDedupeKey(id),
    title: 'Seasonal Anime',
    link: Uri.parse('https://example.test/$id'),
    publishedAt: DateTime.utc(2026, 6, 11, 11),
    summary: 'A seasonal anime.',
  );
}

StoredBangumiMatchQueueItemRecord _storedQueueItem({
  String id = 'queue-item',
  String localMediaId = 'seasonal-entry',
}) {
  return StoredBangumiMatchQueueItemRecord(
    id: id,
    seasonalCatalogEntryId: 'seasonal-entry-$id',
    localMediaId: localMediaId,
    title: id == 'queue-low-confidence'
        ? 'Unmatched Seasonal Anime'
        : 'Seasonal Anime',
    status: StoredBangumiMatchQueueStatus.pending,
    enqueuedAt: _now(),
  );
}

BangumiSubject _subject(String title) {
  return BangumiSubject(
    id: BangumiSubjectId('subject-${title.replaceAll(' ', '-')}'),
    title: title,
  );
}

final class _RuntimeObserver implements SeasonalIndexerRuntimeObserver {
  final List<SeasonalIndexerRuntimeSnapshot> snapshots =
      <SeasonalIndexerRuntimeSnapshot>[];

  @override
  void onSeasonalIndexerRuntimeSnapshot(
    SeasonalIndexerRuntimeSnapshot snapshot,
  ) {
    snapshots.add(snapshot);
  }
}

final class _FakeSeasonalConsumer implements SeasonalAnimeConsumer {
  _FakeSeasonalConsumer({this.acceptedSourceId = 'seasonal-rss'});

  final String acceptedSourceId;
  final List<SeasonalSourceItem> consumedItems = <SeasonalSourceItem>[];

  @override
  bool accepts(SeasonalFeedSourceId sourceId) =>
      sourceId.value == acceptedSourceId;

  @override
  Future<List<SeasonalCatalogEntry>> consume(
    SeasonalFeedSourceId sourceId,
    Iterable<SeasonalSourceItem> items,
  ) {
    consumedItems.addAll(items);
    return Future<List<SeasonalCatalogEntry>>.value(<SeasonalCatalogEntry>[
      for (final SeasonalSourceItem item in items)
        SeasonalCatalogEntry(
          id: SeasonalCatalogEntryId('seasonal-entry-${item.id}'),
          season: const AnimeSeason(year: 2026, kind: AnimeSeasonKind.summer),
          title: item.title,
          sourceItem: item,
          summary: item.summary,
          officialUri: item.link,
          publishedAt: item.publishedAt,
        ),
    ]);
  }
}

final class _ThrowingSeasonalConsumer implements SeasonalAnimeConsumer {
  @override
  bool accepts(SeasonalFeedSourceId sourceId) => true;

  @override
  Future<List<SeasonalCatalogEntry>> consume(
    SeasonalFeedSourceId sourceId,
    Iterable<SeasonalSourceItem> items,
  ) {
    throw StateError('consumer failure');
  }
}

final class _FakeRssEngine implements RssEngineContract {
  final StreamController<FeedItem> _updates =
      StreamController<FeedItem>.broadcast(sync: true);
  final List<FeedSource> registered = <FeedSource>[];

  @override
  Stream<FeedItem> get updates => _updates.stream;

  void emit(FeedItem item) {
    _updates.add(item);
  }

  @override
  Future<void> registerSource(FeedSource source) {
    registered.add(source);
    return Future<void>.value();
  }

  @override
  Future<RssRefreshOutcome> refreshSource(RssRefreshRequest request) {
    return Future<RssRefreshOutcome>.value(RssRefreshOutcome.success(
      sourceId: request.sourceId,
      newItems: const <FeedItem>[],
    ));
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
  }) async {
    return ProviderGatewayResponse<T>(
        value: await load(), source: ProviderGatewayResponseSource.network);
  }

  @override
  Future<AcgProviderResult<BangumiEpisode>> lookupEpisode(BangumiEpisodeId id) {
    return Future<AcgProviderResult<BangumiEpisode>>.value(
      AcgProviderSuccess<BangumiEpisode>(BangumiEpisode(
        id: id,
        subjectId: const BangumiSubjectId('subject-Seasonal-Anime'),
        index: 1,
        title: 'Episode 1',
      )),
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
    if (query == 'Unmatched Seasonal Anime') {
      return Future<AcgProviderResult<List<BangumiSubject>>>.value(
        AcgProviderSuccess<List<BangumiSubject>>(
            <BangumiSubject>[_subject('Different Title')]),
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
