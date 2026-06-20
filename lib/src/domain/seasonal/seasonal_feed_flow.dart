import '../../foundation/cache_invalidation/cache_invalidation_bus.dart';
import '../../foundation/storage/storage_contracts.dart';
import '../rss/rss_engine_runtime.dart';
import 'seasonal_anime.dart';
import 'seasonal_indexer_runtime.dart';

enum SeasonalFeedFlowStatus {
  idle,
  registering,
  refreshing,
  ready,
  failed,
  disposed,
}

enum SeasonalFeedFlowFailureKind {
  disposed,
  rssFailure,
  seasonalFailure,
}

final class SeasonalFeedFlowFailure {
  const SeasonalFeedFlowFailure({
    required this.kind,
    required this.message,
  }) : assert(
          message != '',
          'Seasonal feed flow failure message must not be empty.',
        );

  final SeasonalFeedFlowFailureKind kind;
  final String message;
}

enum SeasonalFeedFlowActionResultKind {
  success,
  failed,
  disposed,
}

final class SeasonalFeedFlowActionResult<T> {
  const SeasonalFeedFlowActionResult._({
    required this.kind,
    this.value,
    this.failure,
  });

  const SeasonalFeedFlowActionResult.success([T? value])
      : this._(kind: SeasonalFeedFlowActionResultKind.success, value: value);

  const SeasonalFeedFlowActionResult.failed(SeasonalFeedFlowFailure failure)
      : this._(kind: SeasonalFeedFlowActionResultKind.failed, failure: failure);

  const SeasonalFeedFlowActionResult.disposed(SeasonalFeedFlowFailure failure)
      : this._(
          kind: SeasonalFeedFlowActionResultKind.disposed,
          failure: failure,
        );

  final SeasonalFeedFlowActionResultKind kind;
  final T? value;
  final SeasonalFeedFlowFailure? failure;

  bool get isSuccess => kind == SeasonalFeedFlowActionResultKind.success;
}

final class SeasonalFeedFlowRefreshSnapshot {
  SeasonalFeedFlowRefreshSnapshot({
    required this.rssRefresh,
    required Iterable<SeasonalCatalogEntry> catalogEntries,
    required this.matchQueue,
  }) : catalogEntries = List<SeasonalCatalogEntry>.unmodifiable(
          catalogEntries,
        );

  final RssEngineRefreshSnapshot rssRefresh;
  final List<SeasonalCatalogEntry> catalogEntries;
  final BangumiMatchQueueProjection matchQueue;
}

final class SeasonalFeedFlowSnapshot {
  SeasonalFeedFlowSnapshot({
    required this.status,
    required this.rss,
    required this.seasonal,
    this.latestRefresh,
    Iterable<SeasonalFeedFlowFailure> failures =
        const <SeasonalFeedFlowFailure>[],
  }) : failures = List<SeasonalFeedFlowFailure>.unmodifiable(failures);

  SeasonalFeedFlowSnapshot.idle({
    required RssEngineRuntimeSnapshot rss,
    required SeasonalIndexerRuntimeSnapshot seasonal,
  }) : this(
          status: SeasonalFeedFlowStatus.idle,
          rss: rss,
          seasonal: seasonal,
        );

  final SeasonalFeedFlowStatus status;
  final RssEngineRuntimeSnapshot rss;
  final SeasonalIndexerRuntimeSnapshot seasonal;
  final SeasonalFeedFlowRefreshSnapshot? latestRefresh;
  final List<SeasonalFeedFlowFailure> failures;
}

final class SeasonalFeedFlowRuntime {
  SeasonalFeedFlowRuntime({
    required RssEngineRuntime rssRuntime,
    required SeasonalIndexerRuntime seasonalRuntime,
  })  : _rssRuntime = rssRuntime,
        _seasonalRuntime = seasonalRuntime {
    _snapshot = SeasonalFeedFlowSnapshot.idle(
      rss: _rssRuntime.currentSnapshot,
      seasonal: _seasonalRuntime.currentSnapshot,
    );
  }

  final RssEngineRuntime _rssRuntime;
  final SeasonalIndexerRuntime _seasonalRuntime;
  late SeasonalFeedFlowSnapshot _snapshot;
  bool _disposed = false;

  bool get isDisposed => _disposed;

  SeasonalFeedFlowSnapshot get currentSnapshot => _snapshot;

  Future<SeasonalFeedFlowActionResult<FeedSource>> registerSource(
    FeedSource source,
  ) async {
    if (_disposed) return _disposedResult();
    _publish(status: SeasonalFeedFlowStatus.registering);
    try {
      final SeasonalIndexerActionResult<FeedSource> registered =
          await _seasonalRuntime.registerSource(source);
      if (!registered.isSuccess || registered.value == null) {
        return _failedResult(
          SeasonalFeedFlowFailureKind.seasonalFailure,
          registered.failure?.message ?? 'Seasonal source registration failed.',
        );
      }
      _publish(status: SeasonalFeedFlowStatus.ready);
      return SeasonalFeedFlowActionResult<FeedSource>.success(
        registered.value,
      );
    } on Object catch (error) {
      return _failedResult(
        SeasonalFeedFlowFailureKind.seasonalFailure,
        error.toString(),
      );
    }
  }

  Future<SeasonalFeedFlowActionResult<SeasonalFeedFlowRefreshSnapshot>>
      refreshSource(FeedSourceId sourceId) async {
    if (_disposed) return _disposedResult();
    _publish(status: SeasonalFeedFlowStatus.refreshing);
    try {
      final RssEngineActionResult<RssEngineRefreshSnapshot> rss =
          await _rssRuntime.refreshSource(sourceId);
      if (!rss.isSuccess || rss.value == null) {
        return _failedResult(
          SeasonalFeedFlowFailureKind.rssFailure,
          rss.failure?.message ?? 'RSS source refresh failed.',
        );
      }

      final List<SeasonalCatalogEntry> catalogEntries =
          <SeasonalCatalogEntry>[];
      for (final FeedItem item in rss.value!.acceptedItems) {
        final SeasonalIndexerActionResult<List<SeasonalCatalogEntry>> consumed =
            await _seasonalRuntime.processFeedItem(item);
        if (!consumed.isSuccess || consumed.value == null) {
          return _failedResult(
            SeasonalFeedFlowFailureKind.seasonalFailure,
            consumed.failure?.message ??
                'Seasonal feed item consumption failed.',
          );
        }
        catalogEntries.addAll(consumed.value!);
      }

      final SeasonalIndexerActionResult<BangumiMatchQueueProjection> queue =
          await _seasonalRuntime.pendingMatchQueue();
      if (!queue.isSuccess || queue.value == null) {
        return _failedResult(
          SeasonalFeedFlowFailureKind.seasonalFailure,
          queue.failure?.message ?? 'Seasonal match queue projection failed.',
        );
      }

      final SeasonalFeedFlowRefreshSnapshot refresh =
          SeasonalFeedFlowRefreshSnapshot(
        rssRefresh: rss.value!,
        catalogEntries: catalogEntries,
        matchQueue: queue.value!,
      );
      _publish(status: SeasonalFeedFlowStatus.ready, latestRefresh: refresh);
      return SeasonalFeedFlowActionResult<
          SeasonalFeedFlowRefreshSnapshot>.success(refresh);
    } on Object catch (error) {
      return _failedResult(
        SeasonalFeedFlowFailureKind.seasonalFailure,
        error.toString(),
      );
    }
  }

  Future<SeasonalFeedFlowActionResult<bool>> dispose() async {
    if (_disposed) return _disposedResult();
    _disposed = true;
    try {
      await _seasonalRuntime.dispose();
      await _rssRuntime.dispose();
      _publish(
        status: SeasonalFeedFlowStatus.disposed,
        failures: const <SeasonalFeedFlowFailure>[
          SeasonalFeedFlowFailure(
            kind: SeasonalFeedFlowFailureKind.disposed,
            message: 'SeasonalFeedFlowRuntime has been disposed.',
          ),
        ],
      );
      return const SeasonalFeedFlowActionResult<bool>.success(true);
    } on Object catch (error) {
      return SeasonalFeedFlowActionResult<bool>.failed(
        SeasonalFeedFlowFailure(
          kind: SeasonalFeedFlowFailureKind.seasonalFailure,
          message: error.toString(),
        ),
      );
    }
  }

  void _publish({
    required SeasonalFeedFlowStatus status,
    SeasonalFeedFlowRefreshSnapshot? latestRefresh,
    Iterable<SeasonalFeedFlowFailure> failures =
        const <SeasonalFeedFlowFailure>[],
  }) {
    _snapshot = SeasonalFeedFlowSnapshot(
      status: status,
      rss: _rssRuntime.currentSnapshot,
      seasonal: _seasonalRuntime.currentSnapshot,
      latestRefresh: latestRefresh ?? _snapshot.latestRefresh,
      failures: failures,
    );
  }

  SeasonalFeedFlowActionResult<T> _failedResult<T>(
    SeasonalFeedFlowFailureKind kind,
    String message,
  ) {
    final SeasonalFeedFlowFailure failure = SeasonalFeedFlowFailure(
      kind: kind,
      message: message,
    );
    _publish(
      status: SeasonalFeedFlowStatus.failed,
      failures: <SeasonalFeedFlowFailure>[failure],
    );
    return SeasonalFeedFlowActionResult<T>.failed(failure);
  }

  SeasonalFeedFlowActionResult<T> _disposedResult<T>() {
    return SeasonalFeedFlowActionResult<T>.disposed(
      const SeasonalFeedFlowFailure(
        kind: SeasonalFeedFlowFailureKind.disposed,
        message: 'SeasonalFeedFlowRuntime has been disposed.',
      ),
    );
  }
}

final class SeasonalFeedFlowBootstrap {
  factory SeasonalFeedFlowBootstrap({
    required RssFeedStore rssStore,
    required FeedFetcher fetcher,
    required FeedParser parser,
    required FeedScheduler scheduler,
    required Iterable<SeasonalAnimeConsumer> consumers,
    required SeasonalCatalogStore catalogStore,
    required BangumiMatchQueueStore matchQueueStore,
    FeedDeduplicator? deduplicator,
    CacheInvalidationBus? cacheInvalidationBus,
    DateTime Function()? clock,
  }) {
    final RssEngineBootstrap rss = RssEngineBootstrap(
      store: rssStore,
      fetcher: fetcher,
      parser: parser,
      scheduler: scheduler,
      deduplicator: deduplicator,
      clock: clock,
    );
    final SeasonalIndexerBootstrap seasonal =
        SeasonalIndexerBootstrap.fromRssRuntime(
      rssRuntime: rss.runtime,
      consumers: consumers,
      catalogStore: catalogStore,
      matchQueueStore: matchQueueStore,
      cacheInvalidationBus: cacheInvalidationBus,
      clock: clock,
    );
    return SeasonalFeedFlowBootstrap._(
      rss: rss,
      seasonal: seasonal,
      runtime: SeasonalFeedFlowRuntime(
        rssRuntime: rss.runtime,
        seasonalRuntime: seasonal.runtime,
      ),
    );
  }

  const SeasonalFeedFlowBootstrap._({
    required this.rss,
    required this.seasonal,
    required this.runtime,
  });

  final RssEngineBootstrap rss;
  final SeasonalIndexerBootstrap seasonal;
  final SeasonalFeedFlowRuntime runtime;

  Future<SeasonalFeedFlowActionResult<FeedSource>> registerSource(
    FeedSource source,
  ) {
    return runtime.registerSource(source);
  }

  Future<SeasonalFeedFlowActionResult<SeasonalFeedFlowRefreshSnapshot>>
      refreshSource(FeedSourceId sourceId) {
    return runtime.refreshSource(sourceId);
  }

  Future<SeasonalFeedFlowActionResult<bool>> dispose() => runtime.dispose();
}
