// Seasonal indexer runtime contract keeps feed normalization, catalog storage,
// and match-queue behavior executable from the Dart validation CLI.
// UI recommendation behavior should stay in widget/domain tests.
import 'dart:async';

import '../../lib/elaina.dart';
import 'rss_engine_runtime_contract.dart';

Future<void> main() async {
  await verifySeasonalIndexerRuntimeContract();
}

Future<void> verifySeasonalIndexerRuntimeContract() async {
  await verifyRssEngineRuntimeContract();

  final _CheckRssEngine rssEngine = _CheckRssEngine();
  final DeterministicSeasonalCatalogStore catalogStore =
      DeterministicSeasonalCatalogStore();
  final DeterministicBangumiMatchQueueStore queueStore =
      DeterministicBangumiMatchQueueStore();
  final SeasonalIndexerRuntime runtime = SeasonalIndexerRuntime(
    rssEngine: rssEngine,
    consumers: <SeasonalAnimeConsumer>[_CheckSeasonalConsumer()],
    catalogStore: catalogStore,
    matchQueueStore: queueStore,
    clock: _now,
  );

  final SeasonalIndexerActionResult<FeedSource> registered =
      await runtime.registerYucWikiSource();
  _expect(registered.isSuccess, 'Seasonal runtime must register YucWiki.');
  _expect(
    registered.value?.id.value == yucWikiSeasonalFeedSource.id.value,
    'YucWiki must remain ordinary FeedSource metadata.',
  );
  _expect(
    rssEngine.registered.single.id.value == yucWikiSeasonalFeedSource.id.value,
    'Seasonal runtime must delegate source registration to RSS contract.',
  );

  final SeasonalIndexerActionResult<SeasonalCatalogUpdateObservation>
      observation = runtime.observeCatalogUpdates();
  final Future<List<SeasonalCatalogEntry>> observed =
      observation.value!.updates.take(1).toList();
  _expect((await runtime.startListening()).isSuccess,
      'Seasonal runtime must start RSS update listening.');
  rssEngine.emit(_feedItem(id: 'check-feed-item'));
  _expect((await observed).single.id.value == 'seasonal-check-feed-item',
      'Seasonal runtime must consume accepted RSS updates.');
  _expect((await runtime.stopListening()).isSuccess,
      'Seasonal runtime must stop RSS update listening.');

  final SeasonalIndexerActionResult<List<SeasonalCatalogEntry>> duplicate =
      await runtime.processFeedItem(_feedItem(id: 'check-feed-item'));
  final SeasonalIndexerActionResult<SeasonalCatalogProjection> catalog =
      await runtime.listCatalogEntries();
  final SeasonalIndexerActionResult<BangumiMatchQueueProjection> queue =
      await runtime.pendingMatchQueue();
  _expect(duplicate.value?.isEmpty == true,
      'Seasonal runtime must suppress duplicate source items.');
  _expect(catalog.value?.entries.single.title == 'Seasonal Check Anime',
      'Seasonal runtime must persist catalog entries.');
  _expect(queue.value?.pendingCount == 1,
      'Seasonal runtime must enqueue pending Bangumi matches.');

  await runtime.dispose();

  final DeterministicProviderBindingStore bindingStore =
      DeterministicProviderBindingStore();
  final DeterministicBangumiMatchQueueStore matchQueueStore =
      DeterministicBangumiMatchQueueStore(
    seedItems: <StoredBangumiMatchQueueItemRecord>[
      _queueItem(id: 'queue-user-confirmed', localMediaId: 'confirmed-media'),
      _queueItem(id: 'queue-low-confidence', localMediaId: 'low-media'),
      _queueItem(id: 'queue-applied', localMediaId: 'applied-media'),
    ],
  );
  await bindingStore.saveUserConfirmed(ProviderBinding(
    id: const ProviderBindingId('confirmed-binding'),
    localMediaId: const LocalMediaId('confirmed-media'),
    providerId: 'bangumi',
    subjectId: const ProviderSubjectId('confirmed-subject'),
    authority: ProviderBindingAuthority.userConfirmed,
    confidence: 0.2,
    createdAt: _now(),
  ));
  final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
  final SeasonalIndexerRuntime matchRuntime = SeasonalIndexerRuntime(
    rssEngine: _CheckRssEngine(),
    consumers: <SeasonalAnimeConsumer>[_CheckSeasonalConsumer()],
    catalogStore: DeterministicSeasonalCatalogStore(),
    matchQueueStore: matchQueueStore,
    bindingStore: bindingStore,
    matchWorker: DeterministicBangumiMatchWorker(
      queueStore: matchQueueStore,
      bindingStore: bindingStore,
      bangumiProvider: _CheckBangumiProvider(),
      cacheInvalidationBus: bus,
      clock: _now,
    ),
    clock: _now,
  );

  final SeasonalIndexerActionResult<BangumiMatchWorkerResult> skipped =
      await matchRuntime.processNextBangumiMatch();
  final SeasonalIndexerActionResult<BangumiMatchWorkerResult> rejected =
      await matchRuntime.processNextBangumiMatch();
  final Future<List<CacheInvalidationEvent>> appliedEvents =
      bus.events.take(1).toList();
  final SeasonalIndexerActionResult<BangumiMatchWorkerResult> applied =
      await matchRuntime.processNextBangumiMatch();
  _expect(
    skipped.value?.matchResult?.outcome ==
        AutomaticBangumiMatchOutcome.skippedUserConfirmedBinding,
    'Seasonal match worker must preserve user-confirmed bindings.',
  );
  _expect(
    rejected.value?.matchResult?.outcome ==
        AutomaticBangumiMatchOutcome.rejectedLowConfidence,
    'Seasonal match worker must reject low-confidence candidates.',
  );
  _expect(
    applied.value?.matchResult?.outcome == AutomaticBangumiMatchOutcome.applied,
    'Seasonal match worker must apply confident automatic matches.',
  );
  _expect((await appliedEvents).single is BangumiMatchApplied,
      'Seasonal match worker must emit cache invalidation on apply.');

  final DeterministicBangumiMatchQueueStore failingQueueStore =
      DeterministicBangumiMatchQueueStore(
    seedItems: <StoredBangumiMatchQueueItemRecord>[
      _queueItem(id: 'queue-fail')
    ],
  );
  final SeasonalIndexerRuntime failingRuntime = SeasonalIndexerRuntime(
    rssEngine: _CheckRssEngine(),
    consumers: <SeasonalAnimeConsumer>[_CheckSeasonalConsumer()],
    catalogStore: DeterministicSeasonalCatalogStore(),
    matchQueueStore: failingQueueStore,
    bindingStore: DeterministicProviderBindingStore(),
    matchWorker: DeterministicBangumiMatchWorker(
      queueStore: failingQueueStore,
      bindingStore: DeterministicProviderBindingStore(),
      bangumiProvider: _FailingBangumiProvider(),
    ),
  );
  final SeasonalIndexerActionResult<BangumiMatchWorkerResult> failed =
      await failingRuntime.processNextBangumiMatch();
  _expect(failed.kind == SeasonalIndexerActionResultKind.failed,
      'Seasonal runtime must normalize match worker provider failures.');
  _expect(
      failed.failure?.kind == SeasonalIndexerRuntimeFailureKind.matchFailure,
      'Seasonal runtime must expose provider failures as match failures.');

  await matchRuntime.dispose();
  await failingRuntime.dispose();
  await bus.close();
}

void _expect(bool condition, String message) {
  if (!condition) throw StateError(message);
}

DateTime _now() => DateTime.utc(2026, 6, 11, 12);

FeedItem _feedItem({required String id}) {
  return FeedItem(
    id: FeedItemId(id),
    sourceId: const FeedSourceId('seasonal-check-rss'),
    dedupeKey: FeedDedupeKey(id),
    title: 'Seasonal Check Anime',
    link: Uri.parse('https://example.test/$id'),
    publishedAt: DateTime.utc(2026, 6, 11, 11),
  );
}

StoredBangumiMatchQueueItemRecord _queueItem({
  required String id,
  String localMediaId = 'seasonal-check-entry',
}) {
  return StoredBangumiMatchQueueItemRecord(
    id: id,
    seasonalCatalogEntryId: 'seasonal-$id',
    localMediaId: localMediaId,
    title: id == 'queue-low-confidence'
        ? 'Unmatched Seasonal Check Anime'
        : 'Seasonal Check Anime',
    status: StoredBangumiMatchQueueStatus.pending,
    enqueuedAt: _now(),
  );
}

final class _CheckSeasonalConsumer implements SeasonalAnimeConsumer {
  @override
  bool accepts(SeasonalFeedSourceId sourceId) =>
      sourceId.value == 'seasonal-check-rss';

  @override
  Future<List<SeasonalCatalogEntry>> consume(
    SeasonalFeedSourceId sourceId,
    Iterable<SeasonalSourceItem> items,
  ) {
    return Future<List<SeasonalCatalogEntry>>.value(<SeasonalCatalogEntry>[
      for (final SeasonalSourceItem item in items)
        SeasonalCatalogEntry(
          id: SeasonalCatalogEntryId('seasonal-${item.id}'),
          season: const AnimeSeason(year: 2026, kind: AnimeSeasonKind.summer),
          title: item.title,
          sourceItem: item,
          officialUri: item.link,
          publishedAt: item.publishedAt,
        ),
    ]);
  }
}

final class _CheckRssEngine implements RssEngineContract {
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

final class _CheckBangumiProvider implements BangumiProvider {
  @override
  String get displayName => 'Check Bangumi Provider';

  @override
  ProviderGateway get gateway => throw UnsupportedError('No gateway required.');

  @override
  String get id => 'check-bangumi';

  @override
  ProviderKind get kind => ProviderKind.metadata;

  @override
  ProviderRegistration get registration => ProviderRegistration(
        providerId: const ProviderId('check-bangumi'),
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
        subjectId: const BangumiSubjectId('check-subject'),
        index: 1,
        title: 'Episode 1',
      )),
    );
  }

  @override
  Future<AcgProviderResult<List<BangumiEpisode>>> listEpisodes(
    BangumiSubjectId subjectId,
  ) {
    return Future<AcgProviderResult<List<BangumiEpisode>>>.value(
      <BangumiEpisode>[
        BangumiEpisode(
          id: const BangumiEpisodeId('check-episode'),
          subjectId: subjectId,
          index: 1,
          title: 'Episode 1',
        ),
      ].success,
    );
  }

  @override
  Future<AcgProviderResult<List<BangumiRelatedPerson>>> listSubjectPersons(
    BangumiSubjectId subjectId,
  ) {
    return Future<AcgProviderResult<List<BangumiRelatedPerson>>>.value(
      const <BangumiRelatedPerson>[].success,
    );
  }

  @override
  Future<AcgProviderResult<List<BangumiRelatedCharacter>>>
      listSubjectCharacters(
    BangumiSubjectId subjectId,
  ) {
    return Future<AcgProviderResult<List<BangumiRelatedCharacter>>>.value(
      const <BangumiRelatedCharacter>[].success,
    );
  }

  @override
  Future<AcgProviderResult<List<BangumiRelatedSubject>>> listSubjectRelations(
    BangumiSubjectId subjectId,
  ) {
    return Future<AcgProviderResult<List<BangumiRelatedSubject>>>.value(
      const <BangumiRelatedSubject>[].success,
    );
  }

  @override
  Future<AcgProviderResult<BangumiSubject>> lookupSubject(BangumiSubjectId id) {
    return Future<AcgProviderResult<BangumiSubject>>.value(
      BangumiSubject(id: id, title: 'Seasonal Check Anime').success,
    );
  }

  @override
  ProviderRequestKey requestKey(String cacheKey) => ProviderRequestKey(
      providerId: const ProviderId('check-bangumi'), cacheKey: cacheKey);

  @override
  Future<AcgProviderResult<List<BangumiSubject>>> searchSubjects(
    String query, {
    BangumiSubjectSearchSort sort = BangumiSubjectSearchSort.match,
  }) {
    final String title = query == 'Unmatched Seasonal Check Anime'
        ? 'Different Seasonal Check Anime'
        : 'Seasonal Check Anime';
    return Future<AcgProviderResult<List<BangumiSubject>>>.value(
      <BangumiSubject>[
        BangumiSubject(
            id: const BangumiSubjectId('check-subject'), title: title),
      ].success,
    );
  }
}

final class _FailingBangumiProvider extends _CheckBangumiProvider {
  @override
  Future<AcgProviderResult<List<BangumiSubject>>> searchSubjects(
    String query, {
    BangumiSubjectSearchSort sort = BangumiSubjectSearchSort.match,
  }) {
    return Future<AcgProviderResult<List<BangumiSubject>>>.value(
      const AcgProviderFailure<List<BangumiSubject>>(
        kind: AcgProviderFailureKind.retryable,
        message: 'check match provider failure',
      ),
    );
  }
}

extension _Success<T> on T {
  AcgProviderSuccess<T> get success => AcgProviderSuccess<T>(this);
}
