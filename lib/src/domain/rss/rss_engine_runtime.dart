import 'dart:async';

import '../../foundation/storage/storage_contracts.dart';
import '../../provider/provider_result.dart';
import '../../provider/rss/feed_contracts.dart';
import '../../provider/rss/rss_auto_download_policy.dart';
import 'rss_engine.dart';

export '../../provider/rss/feed_contracts.dart';

enum RssEngineRuntimeStatus {
  idle,
  registering,
  removing,
  projecting,
  refreshing,
  ready,
  failed,
  disposed,
}

enum RssEngineRuntimeFailureKind {
  disposed,
  unavailable,
  ignored,
  providerFailure,
  parserFailure,
  storageFailure,
  schedulerFailure,
  refreshFailure,
  streamFailure,
}

final class RssEngineRuntimeFailure {
  const RssEngineRuntimeFailure({required this.kind, required this.message})
      : assert(message != '',
            'RSS engine runtime failure message must not be empty.');

  final RssEngineRuntimeFailureKind kind;
  final String message;
}

enum RssEngineActionResultKind {
  success,
  ignored,
  unavailable,
  failed,
  disposed,
}

final class RssEngineActionResult<T> {
  const RssEngineActionResult._({required this.kind, this.value, this.failure});

  const RssEngineActionResult.success([T? value])
      : this._(kind: RssEngineActionResultKind.success, value: value);

  const RssEngineActionResult.ignored(RssEngineRuntimeFailure failure)
      : this._(kind: RssEngineActionResultKind.ignored, failure: failure);

  const RssEngineActionResult.unavailable(RssEngineRuntimeFailure failure)
      : this._(kind: RssEngineActionResultKind.unavailable, failure: failure);

  const RssEngineActionResult.failed(RssEngineRuntimeFailure failure)
      : this._(kind: RssEngineActionResultKind.failed, failure: failure);

  const RssEngineActionResult.disposed(RssEngineRuntimeFailure failure)
      : this._(kind: RssEngineActionResultKind.disposed, failure: failure);

  final RssEngineActionResultKind kind;
  final T? value;
  final RssEngineRuntimeFailure? failure;

  bool get isSuccess => kind == RssEngineActionResultKind.success;
}

final class RssEngineCursorSnapshot {
  const RssEngineCursorSnapshot({
    required this.sourceId,
    required this.refreshedAt,
    this.etag,
    this.lastModified,
  });

  final FeedSourceId sourceId;
  final String? etag;
  final DateTime? lastModified;
  final DateTime refreshedAt;
}

final class RssEngineDedupeSnapshot {
  RssEngineDedupeSnapshot({
    required this.sourceId,
    Iterable<StoredFeedDedupeKeyRecord> records =
        const <StoredFeedDedupeKeyRecord>[],
  }) : records = List<StoredFeedDedupeKeyRecord>.unmodifiable(records);

  final FeedSourceId sourceId;
  final List<StoredFeedDedupeKeyRecord> records;
}

final class RssEngineRefreshSnapshot {
  RssEngineRefreshSnapshot({required RssRefreshOutcome outcome})
      : outcome = outcome,
        acceptedItems = List<FeedItem>.unmodifiable(outcome.newItems),
        warnings = List<String>.unmodifiable(outcome.warnings);

  final RssRefreshOutcome outcome;
  final List<FeedItem> acceptedItems;
  final List<String> warnings;
}

final class RssEngineRuntimeSnapshot {
  RssEngineRuntimeSnapshot({
    required this.status,
    Iterable<FeedSource> sources = const <FeedSource>[],
    Iterable<FeedSource> dueSources = const <FeedSource>[],
    Iterable<FeedItem> acceptedItems = const <FeedItem>[],
    Iterable<RssEngineCursorSnapshot> cursors =
        const <RssEngineCursorSnapshot>[],
    Iterable<RssEngineDedupeSnapshot> dedupe =
        const <RssEngineDedupeSnapshot>[],
    Map<String, RssRefreshOutcome> latestRefreshes =
        const <String, RssRefreshOutcome>{},
    Iterable<RssEngineRuntimeFailure> failures =
        const <RssEngineRuntimeFailure>[],
  })  : sources = List<FeedSource>.unmodifiable(sources),
        dueSources = List<FeedSource>.unmodifiable(dueSources),
        acceptedItems = List<FeedItem>.unmodifiable(acceptedItems),
        cursors = List<RssEngineCursorSnapshot>.unmodifiable(cursors),
        dedupe = List<RssEngineDedupeSnapshot>.unmodifiable(dedupe),
        latestRefreshes =
            Map<String, RssRefreshOutcome>.unmodifiable(latestRefreshes),
        failures = List<RssEngineRuntimeFailure>.unmodifiable(failures);

  const RssEngineRuntimeSnapshot.idle()
      : status = RssEngineRuntimeStatus.idle,
        sources = const <FeedSource>[],
        dueSources = const <FeedSource>[],
        acceptedItems = const <FeedItem>[],
        cursors = const <RssEngineCursorSnapshot>[],
        dedupe = const <RssEngineDedupeSnapshot>[],
        latestRefreshes = const <String, RssRefreshOutcome>{},
        failures = const <RssEngineRuntimeFailure>[];

  final RssEngineRuntimeStatus status;
  final List<FeedSource> sources;
  final List<FeedSource> dueSources;
  final List<FeedItem> acceptedItems;
  final List<RssEngineCursorSnapshot> cursors;
  final List<RssEngineDedupeSnapshot> dedupe;
  final Map<String, RssRefreshOutcome> latestRefreshes;
  final List<RssEngineRuntimeFailure> failures;
}

abstract interface class RssEngineRuntimeObserver {
  void onRssEngineRuntimeSnapshot(RssEngineRuntimeSnapshot snapshot);
}

final class RssEngineRuntime {
  RssEngineRuntime({
    required RssEngineContract engine,
    required RssFeedStore store,
    required FeedScheduler scheduler,
    RssAutoDownloadPolicyStore? policyStore,
  })  : _engine = engine,
        _store = store,
        _scheduler = scheduler,
        _policyStore = policyStore,
        _updates = StreamController<FeedItem>.broadcast(sync: true) {
    _engineUpdates = _engine.updates
        .listen(_recordAcceptedUpdate, onError: _recordUpdateFailure);
  }

  final RssEngineContract _engine;
  final RssFeedStore _store;
  final FeedScheduler _scheduler;
  final RssAutoDownloadPolicyStore? _policyStore;
  final StreamController<FeedItem> _updates;
  final List<RssEngineRuntimeObserver> _observers =
      <RssEngineRuntimeObserver>[];
  final Map<String, RssRefreshOutcome> _latestRefreshes =
      <String, RssRefreshOutcome>{};
  final List<FeedItem> _acceptedItems = <FeedItem>[];
  late final StreamSubscription<FeedItem> _engineUpdates;
  RssEngineRuntimeSnapshot _snapshot = const RssEngineRuntimeSnapshot.idle();
  bool _disposed = false;

  bool get isDisposed => _disposed;

  RssEngineRuntimeSnapshot get currentSnapshot => _snapshot;

  Stream<FeedItem> get updates => _updates.stream;

  Future<bool> isAutoDownloadEnabled(String sourceId) async {
    if (_policyStore == null) return false;
    final List<StoredRssAutoDownloadFeedActivationRecord> activations =
        await _policyStore.activationsForPolicy(defaultRssAutoDownloadPolicyId);
    for (final StoredRssAutoDownloadFeedActivationRecord act in activations) {
      if (act.sourceId == sourceId) {
        return act.enabled;
      }
    }
    return false;
  }

  Future<void> setAutoDownloadEnabled(String sourceId, bool enabled) async {
    if (_policyStore == null) return;
    await _policyStore.storeFeedActivation(
      StoredRssAutoDownloadFeedActivationRecord(
        policyId: defaultRssAutoDownloadPolicyId,
        sourceId: sourceId,
        enabled: enabled,
        updatedAt: DateTime.now(),
      ),
    );
  }

  void addObserver(RssEngineRuntimeObserver observer) {
    if (_disposed) throw StateError('RssEngineRuntime has been disposed.');
    if (!_observers.contains(observer)) _observers.add(observer);
  }

  void removeObserver(RssEngineRuntimeObserver observer) {
    _observers.remove(observer);
  }

  Future<RssEngineActionResult<FeedSource>> registerSource(
      FeedSource source) async {
    if (_disposed) return _disposedResult();
    _publish(status: RssEngineRuntimeStatus.registering);
    try {
      await _engine.registerSource(source);
      await _refreshRegistry(status: RssEngineRuntimeStatus.ready);
      return RssEngineActionResult<FeedSource>.success(source);
    } on Object catch (error) {
      return _failedResult(
          RssEngineRuntimeFailureKind.storageFailure, error.toString());
    }
  }

  Future<RssEngineActionResult<FeedSource>> registerSourceParams({
    required String id,
    required String displayName,
    required Uri uri,
    required FeedFormat format,
    Duration refreshInterval = const Duration(hours: 1),
  }) {
    return registerSource(
      FeedSource(
        id: FeedSourceId(id),
        displayName: displayName,
        uri: uri,
        format: format,
        refreshInterval: refreshInterval,
      ),
    );
  }

  Future<RssEngineActionResult<bool>> removeSource(
      FeedSourceId sourceId) async {
    if (_disposed) return _disposedResult();
    _publish(status: RssEngineRuntimeStatus.removing);
    try {
      final bool removed = await _store.removeSource(sourceId.value);
      if (!removed) {
        final RssEngineRuntimeFailure failure = RssEngineRuntimeFailure(
          kind: RssEngineRuntimeFailureKind.ignored,
          message: 'Feed source is not registered.',
        );
        _publish(
            status: RssEngineRuntimeStatus.ready,
            failures: <RssEngineRuntimeFailure>[failure]);
        return RssEngineActionResult<bool>.ignored(failure);
      }
      _latestRefreshes.remove(sourceId.value);
      _acceptedItems.removeWhere(
          (FeedItem item) => item.sourceId.value == sourceId.value);
      await _refreshRegistry(status: RssEngineRuntimeStatus.ready);
      return const RssEngineActionResult<bool>.success(true);
    } on Object catch (error) {
      return _failedResult(
          RssEngineRuntimeFailureKind.storageFailure, error.toString());
    }
  }

  Future<RssEngineActionResult<List<FeedSource>>> listSources() async {
    if (_disposed) return _disposedResult();
    try {
      await _refreshRegistry(status: RssEngineRuntimeStatus.ready);
      return RssEngineActionResult<List<FeedSource>>.success(
        _snapshot.sources,
      );
    } on Object catch (error) {
      return _failedResult(
          RssEngineRuntimeFailureKind.storageFailure, error.toString());
    }
  }

  Future<RssEngineActionResult<FeedSource>> sourceById(
      FeedSourceId sourceId) async {
    if (_disposed) return _disposedResult();
    try {
      final StoredFeedSourceRecord? record =
          await _store.sourceById(sourceId.value);
      if (record == null) {
        return _unavailableResult('Feed source is not registered.');
      }
      return RssEngineActionResult<FeedSource>.success(
          _feedSourceFromRecord(record));
    } on Object catch (error) {
      return _failedResult(
          RssEngineRuntimeFailureKind.storageFailure, error.toString());
    }
  }

  Future<RssEngineActionResult<RssEngineCursorSnapshot?>> cursorSnapshot(
      FeedSourceId sourceId) async {
    if (_disposed) return _disposedResult();
    try {
      final StoredFeedCursorRecord? cursor =
          await _store.cursorFor(sourceId.value);
      return RssEngineActionResult<RssEngineCursorSnapshot?>.success(
        cursor == null ? null : _cursorSnapshotFromRecord(cursor),
      );
    } on Object catch (error) {
      return _failedResult(
          RssEngineRuntimeFailureKind.storageFailure, error.toString());
    }
  }

  Future<RssEngineActionResult<RssEngineDedupeSnapshot>> dedupeSnapshot(
      FeedSourceId sourceId) async {
    if (_disposed) return _disposedResult();
    try {
      return RssEngineActionResult<RssEngineDedupeSnapshot>.success(
        RssEngineDedupeSnapshot(
          sourceId: sourceId,
          records: await _store.dedupeKeysForSource(sourceId.value),
        ),
      );
    } on Object catch (error) {
      return _failedResult(
          RssEngineRuntimeFailureKind.storageFailure, error.toString());
    }
  }

  Future<RssEngineActionResult<List<FeedItem>>> acceptedItemsForSource(
      FeedSourceId sourceId) async {
    if (_disposed) return _disposedResult();
    try {
      final List<FeedItem> items = <FeedItem>[
        for (final StoredFeedItemRecord record
            in await _store.itemsForSource(sourceId.value))
          feedItemFromStoredRecord(record),
      ];
      return RssEngineActionResult<List<FeedItem>>.success(
          List<FeedItem>.unmodifiable(items));
    } on Object catch (error) {
      return _failedResult(
          RssEngineRuntimeFailureKind.storageFailure, error.toString());
    }
  }

  Future<RssEngineActionResult<List<FeedSource>>> dueSources() async {
    if (_disposed) return _disposedResult();
    _publish(status: RssEngineRuntimeStatus.projecting);
    try {
      final List<FeedSource> sources = await _loadSources();
      final List<FeedSource> due = <FeedSource>[];
      await for (final FeedScheduleDecision decision
          in _scheduler.dueSources(sources)) {
        if (sources.any((FeedSource source) =>
            source.id.value == decision.source.id.value)) {
          due.add(decision.source);
        }
      }
      _publish(
          status: RssEngineRuntimeStatus.ready,
          sources: sources,
          dueSources: due);
      return RssEngineActionResult<List<FeedSource>>.success(
          List<FeedSource>.unmodifiable(due));
    } on Object catch (error) {
      return _failedResult(
          RssEngineRuntimeFailureKind.schedulerFailure, error.toString());
    }
  }

  Future<RssEngineActionResult<RssEngineRefreshSnapshot>> refreshSource(
      FeedSourceId sourceId) async {
    if (_disposed) return _disposedResult();
    _publish(status: RssEngineRuntimeStatus.refreshing);
    try {
      final StoredFeedSourceRecord? source =
          await _store.sourceById(sourceId.value);
      if (source == null)
        return _unavailableResult('Feed source is not registered.');
      final RssRefreshOutcome outcome =
          await _engine.refreshSource(RssRefreshRequest(sourceId: sourceId));
      _latestRefreshes[sourceId.value] = outcome;
      await _refreshRegistry(
          status: outcome.isSuccess
              ? RssEngineRuntimeStatus.ready
              : RssEngineRuntimeStatus.failed);
      if (!outcome.isSuccess) {
        final RssRefreshFailure failure = outcome.failure!;
        return RssEngineActionResult<RssEngineRefreshSnapshot>.failed(
          RssEngineRuntimeFailure(
              kind: _failureKindFor(failure.kind), message: failure.message),
        );
      }
      return RssEngineActionResult<RssEngineRefreshSnapshot>.success(
          RssEngineRefreshSnapshot(outcome: outcome));
    } on Object catch (error) {
      return _failedResult(
          RssEngineRuntimeFailureKind.refreshFailure, error.toString());
    }
  }

  Future<RssEngineActionResult<RssEngineRefreshSnapshot>> refreshSourceById(
      String sourceIdValue) {
    return refreshSource(FeedSourceId(sourceIdValue));
  }

  Future<RssEngineActionResult<List<RssEngineRefreshSnapshot>>>
      refreshDueSources() async {
    if (_disposed) return _disposedResult();
    final RssEngineActionResult<List<FeedSource>> due = await dueSources();
    if (!due.isSuccess) {
      return RssEngineActionResult<List<RssEngineRefreshSnapshot>>.failed(
          due.failure!);
    }
    final List<RssEngineRefreshSnapshot> refreshed =
        <RssEngineRefreshSnapshot>[];
    for (final FeedSource source in due.value!) {
      final RssEngineActionResult<RssEngineRefreshSnapshot> result =
          await refreshSource(source.id);
      if (result.isSuccess && result.value != null)
        refreshed.add(result.value!);
      if (result.kind == RssEngineActionResultKind.disposed)
        return _disposedResult();
    }
    return RssEngineActionResult<List<RssEngineRefreshSnapshot>>.success(
        List<RssEngineRefreshSnapshot>.unmodifiable(refreshed));
  }

  RssEngineActionResult<Stream<FeedItem>> observeUpdates() {
    if (_disposed) return _disposedResult();
    return RssEngineActionResult<Stream<FeedItem>>.success(updates);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _engineUpdates.cancel();
    unawaited(_updates.close());
    _publish(
      status: RssEngineRuntimeStatus.disposed,
      failures: const <RssEngineRuntimeFailure>[
        RssEngineRuntimeFailure(
          kind: RssEngineRuntimeFailureKind.disposed,
          message: 'RssEngineRuntime has been disposed.',
        ),
      ],
    );
    _observers.clear();
    final RssEngineContract engine = _engine;
    if (engine is DeterministicRssEngine) await engine.close();
  }

  Future<void> _refreshRegistry(
      {required RssEngineRuntimeStatus status}) async {
    final List<FeedSource> sources = await _loadSources();
    final List<FeedItem> acceptedItems = await _loadAcceptedItems(sources);
    final List<RssEngineCursorSnapshot> cursors = <RssEngineCursorSnapshot>[];
    final List<RssEngineDedupeSnapshot> dedupe = <RssEngineDedupeSnapshot>[];
    for (final FeedSource source in sources) {
      final StoredFeedCursorRecord? cursor =
          await _store.cursorFor(source.id.value);
      if (cursor != null) cursors.add(_cursorSnapshotFromRecord(cursor));
      dedupe.add(RssEngineDedupeSnapshot(
        sourceId: source.id,
        records: await _store.dedupeKeysForSource(source.id.value),
      ));
    }
    _acceptedItems
      ..clear()
      ..addAll(acceptedItems);
    _publish(
        status: status, sources: sources, cursors: cursors, dedupe: dedupe);
  }

  Future<List<FeedSource>> _loadSources() async {
    return <FeedSource>[
      for (final StoredFeedSourceRecord record in await _store.listSources())
        _feedSourceFromRecord(record),
    ];
  }

  Future<List<FeedItem>> _loadAcceptedItems(List<FeedSource> sources) async {
    final List<FeedItem> items = <FeedItem>[];
    for (final FeedSource source in sources) {
      items.addAll(<FeedItem>[
        for (final StoredFeedItemRecord record
            in await _store.itemsForSource(source.id.value))
          feedItemFromStoredRecord(record),
      ]);
    }
    return List<FeedItem>.unmodifiable(items);
  }

  void _recordAcceptedUpdate(FeedItem item) {
    _acceptedItems.add(item);
    _updates.add(item);
    _publish(status: RssEngineRuntimeStatus.ready);
  }

  void _recordUpdateFailure(Object error) {
    _publish(
      status: RssEngineRuntimeStatus.failed,
      failures: <RssEngineRuntimeFailure>[
        RssEngineRuntimeFailure(
            kind: RssEngineRuntimeFailureKind.streamFailure,
            message: error.toString()),
      ],
    );
  }

  void _publish({
    required RssEngineRuntimeStatus status,
    Iterable<FeedSource>? sources,
    Iterable<FeedSource>? dueSources,
    Iterable<RssEngineCursorSnapshot>? cursors,
    Iterable<RssEngineDedupeSnapshot>? dedupe,
    Iterable<RssEngineRuntimeFailure>? failures,
  }) {
    _snapshot = RssEngineRuntimeSnapshot(
      status: status,
      sources: sources ?? _snapshot.sources,
      dueSources: dueSources ?? _snapshot.dueSources,
      acceptedItems: _acceptedItems,
      cursors: cursors ?? _snapshot.cursors,
      dedupe: dedupe ?? _snapshot.dedupe,
      latestRefreshes: _latestRefreshes,
      failures: failures ?? const <RssEngineRuntimeFailure>[],
    );
    for (final RssEngineRuntimeObserver observer
        in List<RssEngineRuntimeObserver>.of(_observers)) {
      observer.onRssEngineRuntimeSnapshot(_snapshot);
    }
  }

  RssEngineActionResult<T> _disposedResult<T>() {
    return RssEngineActionResult<T>.disposed(
      const RssEngineRuntimeFailure(
        kind: RssEngineRuntimeFailureKind.disposed,
        message: 'RssEngineRuntime has been disposed.',
      ),
    );
  }

  RssEngineActionResult<T> _unavailableResult<T>(String message) {
    final RssEngineRuntimeFailure failure = RssEngineRuntimeFailure(
      kind: RssEngineRuntimeFailureKind.unavailable,
      message: message,
    );
    _publish(
        status: RssEngineRuntimeStatus.failed,
        failures: <RssEngineRuntimeFailure>[failure]);
    return RssEngineActionResult<T>.unavailable(failure);
  }

  RssEngineActionResult<T> _failedResult<T>(
      RssEngineRuntimeFailureKind kind, String message) {
    final RssEngineRuntimeFailure failure =
        RssEngineRuntimeFailure(kind: kind, message: message);
    _publish(
        status: RssEngineRuntimeStatus.failed,
        failures: <RssEngineRuntimeFailure>[failure]);
    return RssEngineActionResult<T>.failed(failure);
  }
}

final class RssEngineBootstrap {
  RssEngineBootstrap({
    required RssFeedStore store,
    required FeedFetcher fetcher,
    required FeedParser parser,
    required FeedScheduler scheduler,
    FeedDeduplicator? deduplicator,
    DateTime Function()? clock,
    RssAutoDownloadPolicyStore? policyStore,
  }) : runtime = RssEngineRuntime(
          engine: DeterministicRssEngine(
            store: store,
            fetcher: fetcher,
            parser: parser,
            deduplicator: deduplicator ?? DeterministicFeedDeduplicator(),
            clock: clock,
          ),
          store: store,
          scheduler: scheduler,
          policyStore: policyStore,
        );

  const RssEngineBootstrap.fromRuntime({required this.runtime});

  final RssEngineRuntime runtime;

  Future<RssEngineActionResult<FeedSource>> registerSource(FeedSource source) =>
      runtime.registerSource(source);

  Future<RssEngineActionResult<bool>> removeSource(FeedSourceId sourceId) =>
      runtime.removeSource(sourceId);

  Future<RssEngineActionResult<List<FeedSource>>> listSources() =>
      runtime.listSources();

  Future<RssEngineActionResult<List<FeedSource>>> dueSources() =>
      runtime.dueSources();

  Future<RssEngineActionResult<RssEngineRefreshSnapshot>> refreshSource(
      FeedSourceId sourceId) {
    return runtime.refreshSource(sourceId);
  }

  Future<RssEngineActionResult<List<RssEngineRefreshSnapshot>>>
      refreshDueSources() => runtime.refreshDueSources();

  Future<void> dispose() => runtime.dispose();
}

RssEngineRuntimeFailureKind _failureKindFor(AcgProviderFailureKind kind) {
  return switch (kind) {
    AcgProviderFailureKind.unavailable =>
      RssEngineRuntimeFailureKind.unavailable,
    AcgProviderFailureKind.unauthenticated =>
      RssEngineRuntimeFailureKind.providerFailure,
    AcgProviderFailureKind.notFound => RssEngineRuntimeFailureKind.unavailable,
    AcgProviderFailureKind.terminal =>
      RssEngineRuntimeFailureKind.parserFailure,
    AcgProviderFailureKind.retryable =>
      RssEngineRuntimeFailureKind.providerFailure,
    AcgProviderFailureKind.throttled =>
      RssEngineRuntimeFailureKind.providerFailure,
    AcgProviderFailureKind.cachedMiss =>
      RssEngineRuntimeFailureKind.providerFailure,
  };
}

RssEngineCursorSnapshot _cursorSnapshotFromRecord(
    StoredFeedCursorRecord record) {
  return RssEngineCursorSnapshot(
    sourceId: FeedSourceId(record.sourceId),
    etag: record.etag,
    lastModified: record.lastModified,
    refreshedAt: record.refreshedAt,
  );
}

FeedSource _feedSourceFromRecord(StoredFeedSourceRecord record) {
  return FeedSource(
    id: FeedSourceId(record.id),
    displayName: record.displayName,
    uri: record.uri,
    format: _feedFormatFromName(record.format),
    refreshInterval: record.refreshInterval,
    defaultHeaders: record.defaultHeaders,
  );
}

FeedFormat _feedFormatFromName(String name) {
  return switch (name) {
    'rss' => FeedFormat.rss,
    'atom' => FeedFormat.atom,
    _ => FeedFormat.rss,
  };
}
