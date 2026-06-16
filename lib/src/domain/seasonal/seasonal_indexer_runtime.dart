import 'dart:async';

import '../../foundation/baseline_defaults.dart';
import '../../foundation/cache_invalidation/cache_invalidation_bus.dart';
import '../../foundation/storage/storage_contracts.dart';
import '../../provider/bangumi/bangumi_provider.dart';
import '../../provider/provider_result.dart';
import '../../provider/rss/feed_contracts.dart';
import '../../provider/rss/yuc_wiki_feed_source.dart';
import '../media/media_library.dart';
import '../rss/rss_engine.dart';
import '../rss/rss_engine_runtime.dart';
import 'seasonal_anime.dart';

enum SeasonalIndexerRuntimeStatus {
  idle,
  registering,
  listening,
  stopped,
  consuming,
  projecting,
  matching,
  ready,
  failed,
  disposed,
}

enum SeasonalIndexerRuntimeFailureKind {
  disposed,
  unavailable,
  ignored,
  rssFailure,
  consumerFailure,
  catalogFailure,
  queueFailure,
  matchFailure,
  streamFailure,
}

final class SeasonalIndexerRuntimeFailure {
  const SeasonalIndexerRuntimeFailure({
    required this.kind,
    required this.message,
  }) : assert(
          message != '',
          'Seasonal indexer runtime failure message must not be empty.',
        );

  final SeasonalIndexerRuntimeFailureKind kind;
  final String message;
}

enum SeasonalIndexerActionResultKind {
  success,
  ignored,
  unavailable,
  failed,
  disposed,
}

final class SeasonalIndexerActionResult<T> {
  const SeasonalIndexerActionResult._({
    required this.kind,
    this.value,
    this.failure,
  });

  const SeasonalIndexerActionResult.success([T? value])
      : this._(kind: SeasonalIndexerActionResultKind.success, value: value);

  const SeasonalIndexerActionResult.ignored(
    SeasonalIndexerRuntimeFailure failure,
  ) : this._(
          kind: SeasonalIndexerActionResultKind.ignored,
          failure: failure,
        );

  const SeasonalIndexerActionResult.unavailable(
    SeasonalIndexerRuntimeFailure failure,
  ) : this._(
          kind: SeasonalIndexerActionResultKind.unavailable,
          failure: failure,
        );

  const SeasonalIndexerActionResult.failed(
    SeasonalIndexerRuntimeFailure failure,
  ) : this._(
          kind: SeasonalIndexerActionResultKind.failed,
          failure: failure,
        );

  const SeasonalIndexerActionResult.disposed(
    SeasonalIndexerRuntimeFailure failure,
  ) : this._(
          kind: SeasonalIndexerActionResultKind.disposed,
          failure: failure,
        );

  final SeasonalIndexerActionResultKind kind;
  final T? value;
  final SeasonalIndexerRuntimeFailure? failure;

  bool get isSuccess => kind == SeasonalIndexerActionResultKind.success;
}

final class SeasonalCatalogProjection {
  SeasonalCatalogProjection({required Iterable<SeasonalCatalogEntry> entries})
      : entries = List<SeasonalCatalogEntry>.unmodifiable(entries);

  final List<SeasonalCatalogEntry> entries;
}

final class SeasonalCatalogUpdateObservation {
  const SeasonalCatalogUpdateObservation({required this.updates});

  final Stream<SeasonalCatalogEntry> updates;
}

final class BangumiMatchQueueProjection {
  const BangumiMatchQueueProjection({
    required this.pendingCount,
    this.nextPending,
  });

  final int pendingCount;
  final StoredBangumiMatchQueueItemRecord? nextPending;
}

final class SeasonalIndexerRuntimeSnapshot {
  SeasonalIndexerRuntimeSnapshot({
    required this.status,
    this.listening = false,
    Iterable<FeedSource> registeredSources = const <FeedSource>[],
    Iterable<SeasonalCatalogEntry> catalogEntries =
        const <SeasonalCatalogEntry>[],
    this.matchQueue,
    this.latestMatchResult,
    Iterable<SeasonalIndexerRuntimeFailure> failures =
        const <SeasonalIndexerRuntimeFailure>[],
  })  : registeredSources = List<FeedSource>.unmodifiable(registeredSources),
        catalogEntries = List<SeasonalCatalogEntry>.unmodifiable(
          catalogEntries,
        ),
        failures = List<SeasonalIndexerRuntimeFailure>.unmodifiable(failures);

  const SeasonalIndexerRuntimeSnapshot.idle()
      : status = SeasonalIndexerRuntimeStatus.idle,
        listening = false,
        registeredSources = const <FeedSource>[],
        catalogEntries = const <SeasonalCatalogEntry>[],
        matchQueue = null,
        latestMatchResult = null,
        failures = const <SeasonalIndexerRuntimeFailure>[];

  final SeasonalIndexerRuntimeStatus status;
  final bool listening;
  final List<FeedSource> registeredSources;
  final List<SeasonalCatalogEntry> catalogEntries;
  final BangumiMatchQueueProjection? matchQueue;
  final BangumiMatchWorkerResult? latestMatchResult;
  final List<SeasonalIndexerRuntimeFailure> failures;
}

abstract interface class SeasonalIndexerRuntimeObserver {
  void onSeasonalIndexerRuntimeSnapshot(
    SeasonalIndexerRuntimeSnapshot snapshot,
  );
}

final class SeasonalIndexerRuntime {
  SeasonalIndexerRuntime({
    required RssEngineContract rssEngine,
    required Iterable<SeasonalAnimeConsumer> consumers,
    required SeasonalCatalogStore catalogStore,
    required BangumiMatchQueueStore matchQueueStore,
    RssEngineRuntime? rssRuntime,
    ProviderBindingStore? bindingStore,
    BangumiMatchWorkerContract? matchWorker,
    CacheInvalidationBus? cacheInvalidationBus,
    DateTime Function()? clock,
  })  : _rssEngine = rssEngine,
        _rssRuntime = rssRuntime,
        _consumers = List<SeasonalAnimeConsumer>.unmodifiable(consumers),
        _catalogStore = catalogStore,
        _matchQueueStore = matchQueueStore,
        _bindingStore = bindingStore,
        _matchWorker = matchWorker,
        _indexer = DeterministicSeasonalIndexer(
          rssEngine: rssEngine,
          consumers: List<SeasonalAnimeConsumer>.unmodifiable(consumers),
          catalogStore: catalogStore,
          matchQueueStore: matchQueueStore,
          cacheInvalidationBus: cacheInvalidationBus,
          clock: clock,
        );

  SeasonalIndexerRuntime.fromRssRuntime({
    required RssEngineRuntime rssRuntime,
    required Iterable<SeasonalAnimeConsumer> consumers,
    required SeasonalCatalogStore catalogStore,
    required BangumiMatchQueueStore matchQueueStore,
    ProviderBindingStore? bindingStore,
    BangumiMatchWorkerContract? matchWorker,
    CacheInvalidationBus? cacheInvalidationBus,
    DateTime Function()? clock,
  }) : this(
          rssEngine: _RuntimeBackedRssEngineContract(rssRuntime),
          rssRuntime: rssRuntime,
          consumers: consumers,
          catalogStore: catalogStore,
          matchQueueStore: matchQueueStore,
          bindingStore: bindingStore,
          matchWorker: matchWorker,
          cacheInvalidationBus: cacheInvalidationBus,
          clock: clock,
        );

  final RssEngineContract _rssEngine;
  final RssEngineRuntime? _rssRuntime;
  final List<SeasonalAnimeConsumer> _consumers;
  final SeasonalCatalogStore _catalogStore;
  final BangumiMatchQueueStore _matchQueueStore;
  final ProviderBindingStore? _bindingStore;
  final BangumiMatchWorkerContract? _matchWorker;
  final DeterministicSeasonalIndexer _indexer;
  final List<SeasonalIndexerRuntimeObserver> _observers =
      <SeasonalIndexerRuntimeObserver>[];
  final List<FeedSource> _registeredSources = <FeedSource>[];

  SeasonalIndexerRuntimeSnapshot _snapshot =
      const SeasonalIndexerRuntimeSnapshot.idle();
  bool _disposed = false;
  bool _listening = false;

  bool get isDisposed => _disposed;

  bool get isListening => _listening;

  SeasonalIndexerRuntimeSnapshot get currentSnapshot => _snapshot;

  Stream<SeasonalCatalogEntry> get catalogUpdates => _indexer.catalogUpdates;

  void addObserver(SeasonalIndexerRuntimeObserver observer) {
    if (_disposed) {
      throw StateError('SeasonalIndexerRuntime has been disposed.');
    }
    if (!_observers.contains(observer)) {
      _observers.add(observer);
    }
  }

  void removeObserver(SeasonalIndexerRuntimeObserver observer) {
    _observers.remove(observer);
  }

  Future<SeasonalIndexerActionResult<FeedSource>> registerYucWikiSource() {
    return registerSource(yucWikiSeasonalFeedSource);
  }

  Future<SeasonalIndexerActionResult<FeedSource>> registerSource(
    FeedSource source,
  ) async {
    if (_disposed) return _disposedResult();
    _publish(status: SeasonalIndexerRuntimeStatus.registering);
    try {
      final RssEngineRuntime? runtime = _rssRuntime;
      if (runtime == null) {
        await _rssEngine.registerSource(source);
      } else {
        final RssEngineActionResult<FeedSource> result =
            await runtime.registerSource(source);
        if (!result.isSuccess) {
          return _failedResult(
            _failureKindFromRssResult(result.kind),
            result.failure?.message ?? 'RSS source registration failed.',
          );
        }
      }
      _rememberSource(source);
      _publish(status: SeasonalIndexerRuntimeStatus.ready);
      return SeasonalIndexerActionResult<FeedSource>.success(source);
    } on Object catch (error) {
      return _failedResult(
        SeasonalIndexerRuntimeFailureKind.rssFailure,
        error.toString(),
      );
    }
  }

  Future<SeasonalIndexerActionResult<List<SeasonalCatalogEntry>>>
      processFeedItem(FeedItem item) async {
    if (_disposed) return _disposedResult();
    _publish(status: SeasonalIndexerRuntimeStatus.consuming);
    try {
      final bool hasConsumer = _consumers.any(
        (SeasonalAnimeConsumer consumer) =>
            consumer.accepts(SeasonalFeedSourceId(item.sourceId.value)),
      );
      if (!hasConsumer) {
        final SeasonalIndexerRuntimeFailure failure =
            SeasonalIndexerRuntimeFailure(
          kind: SeasonalIndexerRuntimeFailureKind.ignored,
          message: 'No seasonal consumer accepts this feed source.',
        );
        _publish(
          status: SeasonalIndexerRuntimeStatus.ready,
          failures: <SeasonalIndexerRuntimeFailure>[failure],
        );
        return SeasonalIndexerActionResult<List<SeasonalCatalogEntry>>.ignored(
          failure,
        );
      }
      final List<SeasonalCatalogEntry> entries =
          await _indexer.processFeedItem(item);
      _publish(
        status: SeasonalIndexerRuntimeStatus.ready,
        catalogEntries: await _catalogEntries(),
        matchQueue: await _queueProjection(),
      );
      return SeasonalIndexerActionResult<List<SeasonalCatalogEntry>>.success(
        List<SeasonalCatalogEntry>.unmodifiable(entries),
      );
    } on Object catch (error) {
      return _failedResult(
        SeasonalIndexerRuntimeFailureKind.consumerFailure,
        error.toString(),
      );
    }
  }

  Future<SeasonalIndexerActionResult<bool>> startListening() async {
    if (_disposed) return _disposedResult();
    if (_listening) {
      final SeasonalIndexerRuntimeFailure failure =
          SeasonalIndexerRuntimeFailure(
        kind: SeasonalIndexerRuntimeFailureKind.ignored,
        message: 'Seasonal indexer runtime is already listening.',
      );
      _publish(
        status: SeasonalIndexerRuntimeStatus.listening,
        failures: <SeasonalIndexerRuntimeFailure>[failure],
      );
      return SeasonalIndexerActionResult<bool>.ignored(failure);
    }
    try {
      await _indexer.startListening();
      _listening = true;
      _publish(status: SeasonalIndexerRuntimeStatus.listening);
      return const SeasonalIndexerActionResult<bool>.success(true);
    } on Object catch (error) {
      return _failedResult(
        SeasonalIndexerRuntimeFailureKind.streamFailure,
        error.toString(),
      );
    }
  }

  Future<SeasonalIndexerActionResult<bool>> stopListening() async {
    if (_disposed) return _disposedResult();
    if (!_listening) {
      final SeasonalIndexerRuntimeFailure failure =
          SeasonalIndexerRuntimeFailure(
        kind: SeasonalIndexerRuntimeFailureKind.ignored,
        message: 'Seasonal indexer runtime is not listening.',
      );
      _publish(
        status: SeasonalIndexerRuntimeStatus.stopped,
        failures: <SeasonalIndexerRuntimeFailure>[failure],
      );
      return SeasonalIndexerActionResult<bool>.ignored(failure);
    }
    try {
      await _indexer.stopListening();
      _listening = false;
      _publish(status: SeasonalIndexerRuntimeStatus.stopped);
      return const SeasonalIndexerActionResult<bool>.success(true);
    } on Object catch (error) {
      return _failedResult(
        SeasonalIndexerRuntimeFailureKind.streamFailure,
        error.toString(),
      );
    }
  }

  SeasonalIndexerActionResult<SeasonalCatalogUpdateObservation>
      observeCatalogUpdates() {
    if (_disposed) return _disposedResult();
    return SeasonalIndexerActionResult<
            SeasonalCatalogUpdateObservation>.success(
        SeasonalCatalogUpdateObservation(updates: catalogUpdates));
  }

  Future<SeasonalIndexerActionResult<SeasonalCatalogProjection>>
      listCatalogEntries(
          {int offset = 0, int limit = defaultListPageLimit}) async {
    if (_disposed) return _disposedResult();
    _publish(status: SeasonalIndexerRuntimeStatus.projecting);
    try {
      final List<SeasonalCatalogEntry> entries = await _catalogEntries(
        offset: offset,
        limit: limit,
      );
      final SeasonalCatalogProjection projection = SeasonalCatalogProjection(
        entries: entries,
      );
      _publish(
        status: SeasonalIndexerRuntimeStatus.ready,
        catalogEntries: entries,
      );
      return SeasonalIndexerActionResult<SeasonalCatalogProjection>.success(
        projection,
      );
    } on Object catch (error) {
      return _failedResult(
        SeasonalIndexerRuntimeFailureKind.catalogFailure,
        error.toString(),
      );
    }
  }

  Future<SeasonalIndexerActionResult<SeasonalCatalogProjection>>
      catalogForSeason(AnimeSeason season) async {
    if (_disposed) return _disposedResult();
    _publish(status: SeasonalIndexerRuntimeStatus.projecting);
    try {
      final List<SeasonalCatalogEntry> entries = <SeasonalCatalogEntry>[
        for (final StoredSeasonalCatalogEntryRecord record
            in await _catalogStore.entriesForSeason(
          year: season.year,
          kind: season.kind.name,
        ))
          seasonalEntryFromStoredRecord(record),
      ];
      final SeasonalCatalogProjection projection = SeasonalCatalogProjection(
        entries: entries,
      );
      _publish(
        status: SeasonalIndexerRuntimeStatus.ready,
        catalogEntries: entries,
      );
      return SeasonalIndexerActionResult<SeasonalCatalogProjection>.success(
        projection,
      );
    } on Object catch (error) {
      return _failedResult(
        SeasonalIndexerRuntimeFailureKind.catalogFailure,
        error.toString(),
      );
    }
  }

  Future<SeasonalIndexerActionResult<BangumiMatchQueueProjection>>
      pendingMatchQueue() async {
    if (_disposed) return _disposedResult();
    _publish(status: SeasonalIndexerRuntimeStatus.projecting);
    try {
      final BangumiMatchQueueProjection projection = await _queueProjection();
      _publish(
        status: SeasonalIndexerRuntimeStatus.ready,
        matchQueue: projection,
      );
      return SeasonalIndexerActionResult<BangumiMatchQueueProjection>.success(
        projection,
      );
    } on Object catch (error) {
      return _failedResult(
        SeasonalIndexerRuntimeFailureKind.queueFailure,
        error.toString(),
      );
    }
  }

  Future<SeasonalIndexerActionResult<BangumiMatchWorkerResult>>
      processNextBangumiMatch() async {
    if (_disposed) return _disposedResult();
    final BangumiMatchWorkerContract? worker = _matchWorker;
    if (worker == null || _bindingStore == null) {
      return _unavailableResult('Bangumi match worker is not configured.');
    }
    _publish(status: SeasonalIndexerRuntimeStatus.matching);
    try {
      final BangumiMatchWorkerResult result = await worker.processNext();
      final SeasonalIndexerRuntimeStatus status = result.failure == null
          ? SeasonalIndexerRuntimeStatus.ready
          : SeasonalIndexerRuntimeStatus.failed;
      final Iterable<SeasonalIndexerRuntimeFailure> failures =
          result.failure == null
              ? const <SeasonalIndexerRuntimeFailure>[]
              : <SeasonalIndexerRuntimeFailure>[
                  SeasonalIndexerRuntimeFailure(
                    kind: SeasonalIndexerRuntimeFailureKind.matchFailure,
                    message: result.failure!.message,
                  ),
                ];
      _publish(
        status: status,
        matchQueue: await _queueProjection(),
        latestMatchResult: result,
        failures: failures,
      );
      if (result.failure != null) {
        return SeasonalIndexerActionResult<BangumiMatchWorkerResult>.failed(
          SeasonalIndexerRuntimeFailure(
            kind: SeasonalIndexerRuntimeFailureKind.matchFailure,
            message: result.failure!.message,
          ),
        );
      }
      return SeasonalIndexerActionResult<BangumiMatchWorkerResult>.success(
        result,
      );
    } on Object catch (error) {
      return _failedResult(
        SeasonalIndexerRuntimeFailureKind.matchFailure,
        error.toString(),
      );
    }
  }

  Future<SeasonalIndexerActionResult<bool>> dispose() async {
    if (_disposed) return _disposedResult();
    _disposed = true;
    try {
      _listening = false;
      await _indexer.close();
      _publish(
        status: SeasonalIndexerRuntimeStatus.disposed,
        failures: const <SeasonalIndexerRuntimeFailure>[
          SeasonalIndexerRuntimeFailure(
            kind: SeasonalIndexerRuntimeFailureKind.disposed,
            message: 'SeasonalIndexerRuntime has been disposed.',
          ),
        ],
      );
      _observers.clear();
      return const SeasonalIndexerActionResult<bool>.success(true);
    } on Object catch (error) {
      return SeasonalIndexerActionResult<bool>.failed(
        SeasonalIndexerRuntimeFailure(
          kind: SeasonalIndexerRuntimeFailureKind.streamFailure,
          message: error.toString(),
        ),
      );
    }
  }

  Future<List<SeasonalCatalogEntry>> _catalogEntries({
    int offset = 0,
    int limit = defaultListPageLimit,
  }) async {
    return <SeasonalCatalogEntry>[
      for (final StoredSeasonalCatalogEntryRecord record
          in await _catalogStore.list(offset: offset, limit: limit))
        seasonalEntryFromStoredRecord(record),
    ];
  }

  Future<BangumiMatchQueueProjection> _queueProjection() async {
    return BangumiMatchQueueProjection(
      pendingCount: await _matchQueueStore.pendingCount(),
      nextPending: await _matchQueueStore.nextPending(),
    );
  }

  void _rememberSource(FeedSource source) {
    _registeredSources.removeWhere(
      (FeedSource existing) => existing.id.value == source.id.value,
    );
    _registeredSources.add(source);
  }

  void _publish({
    required SeasonalIndexerRuntimeStatus status,
    Iterable<SeasonalCatalogEntry>? catalogEntries,
    BangumiMatchQueueProjection? matchQueue,
    BangumiMatchWorkerResult? latestMatchResult,
    Iterable<SeasonalIndexerRuntimeFailure>? failures,
  }) {
    _snapshot = SeasonalIndexerRuntimeSnapshot(
      status: status,
      listening: _listening,
      registeredSources: _registeredSources,
      catalogEntries: catalogEntries ?? _snapshot.catalogEntries,
      matchQueue: matchQueue ?? _snapshot.matchQueue,
      latestMatchResult: latestMatchResult ?? _snapshot.latestMatchResult,
      failures: failures ?? const <SeasonalIndexerRuntimeFailure>[],
    );
    for (final SeasonalIndexerRuntimeObserver observer
        in List<SeasonalIndexerRuntimeObserver>.of(_observers)) {
      observer.onSeasonalIndexerRuntimeSnapshot(_snapshot);
    }
  }

  SeasonalIndexerActionResult<T> _disposedResult<T>() {
    return SeasonalIndexerActionResult<T>.disposed(
      const SeasonalIndexerRuntimeFailure(
        kind: SeasonalIndexerRuntimeFailureKind.disposed,
        message: 'SeasonalIndexerRuntime has been disposed.',
      ),
    );
  }

  SeasonalIndexerActionResult<T> _unavailableResult<T>(String message) {
    final SeasonalIndexerRuntimeFailure failure = SeasonalIndexerRuntimeFailure(
      kind: SeasonalIndexerRuntimeFailureKind.unavailable,
      message: message,
    );
    _publish(
      status: SeasonalIndexerRuntimeStatus.failed,
      failures: <SeasonalIndexerRuntimeFailure>[failure],
    );
    return SeasonalIndexerActionResult<T>.unavailable(failure);
  }

  SeasonalIndexerActionResult<T> _failedResult<T>(
    SeasonalIndexerRuntimeFailureKind kind,
    String message,
  ) {
    final SeasonalIndexerRuntimeFailure failure = SeasonalIndexerRuntimeFailure(
      kind: kind,
      message: message,
    );
    _publish(
      status: SeasonalIndexerRuntimeStatus.failed,
      failures: <SeasonalIndexerRuntimeFailure>[failure],
    );
    return SeasonalIndexerActionResult<T>.failed(failure);
  }
}

final class SeasonalIndexerBootstrap {
  SeasonalIndexerBootstrap({
    required RssEngineContract rssEngine,
    required Iterable<SeasonalAnimeConsumer> consumers,
    required SeasonalCatalogStore catalogStore,
    required BangumiMatchQueueStore matchQueueStore,
    ProviderBindingStore? bindingStore,
    BangumiProvider? bangumiProvider,
    CacheInvalidationBus? cacheInvalidationBus,
    DateTime Function()? clock,
    double minimumConfidence = defaultAutomaticBangumiMatchMinimumConfidence,
  }) : runtime = SeasonalIndexerRuntime(
          rssEngine: rssEngine,
          consumers: consumers,
          catalogStore: catalogStore,
          matchQueueStore: matchQueueStore,
          bindingStore: bindingStore,
          matchWorker: bindingStore == null || bangumiProvider == null
              ? null
              : DeterministicBangumiMatchWorker(
                  queueStore: matchQueueStore,
                  bindingStore: bindingStore,
                  bangumiProvider: bangumiProvider,
                  cacheInvalidationBus: cacheInvalidationBus,
                  clock: clock,
                  minimumConfidence: minimumConfidence,
                ),
          cacheInvalidationBus: cacheInvalidationBus,
          clock: clock,
        );

  SeasonalIndexerBootstrap.fromRssRuntime({
    required RssEngineRuntime rssRuntime,
    required Iterable<SeasonalAnimeConsumer> consumers,
    required SeasonalCatalogStore catalogStore,
    required BangumiMatchQueueStore matchQueueStore,
    ProviderBindingStore? bindingStore,
    BangumiProvider? bangumiProvider,
    CacheInvalidationBus? cacheInvalidationBus,
    DateTime Function()? clock,
    double minimumConfidence = defaultAutomaticBangumiMatchMinimumConfidence,
  }) : runtime = SeasonalIndexerRuntime.fromRssRuntime(
          rssRuntime: rssRuntime,
          consumers: consumers,
          catalogStore: catalogStore,
          matchQueueStore: matchQueueStore,
          bindingStore: bindingStore,
          matchWorker: bindingStore == null || bangumiProvider == null
              ? null
              : DeterministicBangumiMatchWorker(
                  queueStore: matchQueueStore,
                  bindingStore: bindingStore,
                  bangumiProvider: bangumiProvider,
                  cacheInvalidationBus: cacheInvalidationBus,
                  clock: clock,
                  minimumConfidence: minimumConfidence,
                ),
          cacheInvalidationBus: cacheInvalidationBus,
          clock: clock,
        );

  const SeasonalIndexerBootstrap.fromRuntime({required this.runtime});

  final SeasonalIndexerRuntime runtime;

  Future<SeasonalIndexerActionResult<FeedSource>> registerYucWikiSource() {
    return runtime.registerYucWikiSource();
  }

  Future<SeasonalIndexerActionResult<FeedSource>> registerSource(
    FeedSource source,
  ) {
    return runtime.registerSource(source);
  }

  Future<SeasonalIndexerActionResult<List<SeasonalCatalogEntry>>>
      processFeedItem(FeedItem item) {
    return runtime.processFeedItem(item);
  }

  Future<SeasonalIndexerActionResult<bool>> startListening() {
    return runtime.startListening();
  }

  Future<SeasonalIndexerActionResult<bool>> stopListening() {
    return runtime.stopListening();
  }

  Future<SeasonalIndexerActionResult<SeasonalCatalogProjection>>
      listCatalogEntries({int offset = 0, int limit = defaultListPageLimit}) {
    return runtime.listCatalogEntries(offset: offset, limit: limit);
  }

  Future<SeasonalIndexerActionResult<SeasonalCatalogProjection>>
      catalogForSeason(AnimeSeason season) {
    return runtime.catalogForSeason(season);
  }

  Future<SeasonalIndexerActionResult<BangumiMatchQueueProjection>>
      pendingMatchQueue() {
    return runtime.pendingMatchQueue();
  }

  Future<SeasonalIndexerActionResult<BangumiMatchWorkerResult>>
      processNextBangumiMatch() {
    return runtime.processNextBangumiMatch();
  }

  Future<SeasonalIndexerActionResult<bool>> dispose() => runtime.dispose();
}

SeasonalIndexerRuntimeFailureKind _failureKindFromRssResult(
  RssEngineActionResultKind kind,
) {
  return switch (kind) {
    RssEngineActionResultKind.disposed =>
      SeasonalIndexerRuntimeFailureKind.disposed,
    RssEngineActionResultKind.unavailable =>
      SeasonalIndexerRuntimeFailureKind.unavailable,
    RssEngineActionResultKind.ignored =>
      SeasonalIndexerRuntimeFailureKind.ignored,
    RssEngineActionResultKind.failed =>
      SeasonalIndexerRuntimeFailureKind.rssFailure,
    RssEngineActionResultKind.success =>
      SeasonalIndexerRuntimeFailureKind.rssFailure,
  };
}

final class _RuntimeBackedRssEngineContract implements RssEngineContract {
  const _RuntimeBackedRssEngineContract(this._runtime);

  final RssEngineRuntime _runtime;

  @override
  Stream<FeedItem> get updates => _runtime.updates;

  @override
  Future<void> registerSource(FeedSource source) async {
    final RssEngineActionResult<FeedSource> result =
        await _runtime.registerSource(source);
    if (!result.isSuccess) {
      throw StateError(result.failure?.message ?? 'RSS source unavailable.');
    }
  }

  @override
  Future<RssRefreshOutcome> refreshSource(RssRefreshRequest request) async {
    final RssEngineActionResult<RssEngineRefreshSnapshot> result =
        await _runtime.refreshSource(request.sourceId);
    if (result.isSuccess && result.value != null) {
      return result.value!.outcome;
    }
    return RssRefreshOutcome.failure(
      sourceId: request.sourceId,
      failure: RssRefreshFailure(
        kind: _providerFailureKindFromRuntimeResult(result.kind),
        message: result.failure?.message ?? 'RSS refresh unavailable.',
      ),
    );
  }
}

AcgProviderFailureKind _providerFailureKindFromRuntimeResult(
  RssEngineActionResultKind kind,
) {
  return switch (kind) {
    RssEngineActionResultKind.disposed => AcgProviderFailureKind.terminal,
    RssEngineActionResultKind.unavailable => AcgProviderFailureKind.unavailable,
    RssEngineActionResultKind.ignored => AcgProviderFailureKind.cachedMiss,
    RssEngineActionResultKind.failed => AcgProviderFailureKind.retryable,
    RssEngineActionResultKind.success => AcgProviderFailureKind.retryable,
  };
}
