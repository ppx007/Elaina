import 'dart:async';

import '../../foundation/storage/storage_contracts.dart';
import '../../provider/provider_result.dart';
import '../../provider/rss/feed_contracts.dart';
import '../../provider/rss/rss_auto_download_policy.dart';
import '../../provider/rss/rss_auto_download_runtime.dart';
import '../download/download_domain.dart';
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
  autoDownloadFailure,
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

const int rssAutoDownloadDefaultRulePriority = 100;
const String rssAutoDownloadDefaultPolicyLabel = '默认 RSS 自动下载规则';

const String _rssAutoDownloadRuleIdPrefix = 'rss-rule';
const String _rssAutoDownloadEnqueueIdPrefix = 'enqueue';

final class RssAutoDownloadRuleDraft {
  const RssAutoDownloadRuleDraft({
    this.ruleId,
    required this.sourceId,
    required this.label,
    this.enabled = true,
    this.priority = rssAutoDownloadDefaultRulePriority,
    this.titleContains = '',
    this.titleRegex = '',
    this.excludeTitleContains = '',
    this.categoryContains = '',
    this.requireDownloadSource = true,
  });

  final String? ruleId;
  final String sourceId;
  final String label;
  final bool enabled;
  final int priority;
  final String titleContains;
  final String titleRegex;
  final String excludeTitleContains;
  final String categoryContains;
  final bool requireDownloadSource;
}

final class RssAutoDownloadRuleProjection {
  const RssAutoDownloadRuleProjection({
    required this.ruleId,
    required this.sourceId,
    required this.label,
    required this.enabled,
    required this.priority,
    required this.titleContains,
    required this.titleRegex,
    required this.excludeTitleContains,
    required this.categoryContains,
    required this.requireDownloadSource,
  });

  final String ruleId;
  final String sourceId;
  final String label;
  final bool enabled;
  final int priority;
  final String titleContains;
  final String titleRegex;
  final String excludeTitleContains;
  final String categoryContains;
  final bool requireDownloadSource;

  RssAutoDownloadRuleDraft toDraft() {
    return RssAutoDownloadRuleDraft(
      ruleId: ruleId,
      sourceId: sourceId,
      label: label,
      enabled: enabled,
      priority: priority,
      titleContains: titleContains,
      titleRegex: titleRegex,
      excludeTitleContains: excludeTitleContains,
      categoryContains: categoryContains,
      requireDownloadSource: requireDownloadSource,
    );
  }
}

final class RssAutoDownloadRulePreview {
  RssAutoDownloadRulePreview({
    required this.ruleId,
    required Iterable<FeedItemId> matchedItemIds,
    required Iterable<FeedItemId> rejectedItemIds,
    required Iterable<FeedItemId> duplicateItemIds,
  })  : matchedItemIds = List<FeedItemId>.unmodifiable(matchedItemIds),
        rejectedItemIds = List<FeedItemId>.unmodifiable(rejectedItemIds),
        duplicateItemIds = List<FeedItemId>.unmodifiable(duplicateItemIds);

  final String ruleId;
  final List<FeedItemId> matchedItemIds;
  final List<FeedItemId> rejectedItemIds;
  final List<FeedItemId> duplicateItemIds;

  int get matchedCount => matchedItemIds.length;
  int get rejectedCount => rejectedItemIds.length;
  int get duplicateCount => duplicateItemIds.length;
}

final class RssAutoDownloadExecutionReport {
  RssAutoDownloadExecutionReport({
    required Iterable<RssAutoDownloadRulePreview> previews,
    required Iterable<RssAutoDownloadEnqueueResult> enqueueResults,
  })  : previews = List<RssAutoDownloadRulePreview>.unmodifiable(previews),
        enqueueResults =
            List<RssAutoDownloadEnqueueResult>.unmodifiable(enqueueResults);

  final List<RssAutoDownloadRulePreview> previews;
  final List<RssAutoDownloadEnqueueResult> enqueueResults;

  int get acceptedCount => enqueueResults
      .where((RssAutoDownloadEnqueueResult result) => result.isSuccess)
      .length;
}

final class RssTorrentUrlResolution {
  const RssTorrentUrlResolution._({this.fileUri, this.failureMessage});

  const RssTorrentUrlResolution.success(Uri fileUri) : this._(fileUri: fileUri);

  const RssTorrentUrlResolution.failure(String message)
      : this._(failureMessage: message);

  final Uri? fileUri;
  final String? failureMessage;

  bool get isSuccess => fileUri != null;
}

abstract interface class RssTorrentUrlResolver {
  Future<RssTorrentUrlResolution> resolve(Uri torrentUri);
}

final class RssAutoDownloadEnqueueResult {
  const RssAutoDownloadEnqueueResult({
    required this.candidate,
    required this.state,
    required this.message,
    this.taskId,
  });

  final RssDownloadCandidate candidate;
  final StoredRssAutoDownloadEnqueueState state;
  final String message;
  final String? taskId;

  bool get isSuccess => state == StoredRssAutoDownloadEnqueueState.accepted;
}

abstract interface class RssDownloadTaskEnqueuer {
  Future<RssAutoDownloadEnqueueResult> enqueue(RssDownloadCandidate candidate);
}

final class DownloadRuntimeRssTaskEnqueuer implements RssDownloadTaskEnqueuer {
  const DownloadRuntimeRssTaskEnqueuer({
    required DownloadRuntime downloadRuntime,
    RssTorrentUrlResolver? torrentResolver,
  })  : _downloadRuntime = downloadRuntime,
        _torrentResolver = torrentResolver;

  final DownloadRuntime _downloadRuntime;
  final RssTorrentUrlResolver? _torrentResolver;

  @override
  Future<RssAutoDownloadEnqueueResult> enqueue(
      RssDownloadCandidate candidate) async {
    final _RssResolvedDownloadSource resolved =
        await _sourceUriFor(candidate.source);
    if (!resolved.isSuccess) {
      return RssAutoDownloadEnqueueResult(
        candidate: candidate,
        state: StoredRssAutoDownloadEnqueueState.adapterUnavailable,
        message: resolved.failureMessage!,
      );
    }

    final DownloadCreateResult result = await _downloadRuntime
        .createTaskFromUri(resolved.sourceUri!, mode: DownloadCreateMode.quick);
    final DownloadProjection? task = result.task;
    if (task == null || result.failureMessage != null) {
      return RssAutoDownloadEnqueueResult(
        candidate: candidate,
        state: StoredRssAutoDownloadEnqueueState.rejected,
        message: result.failureMessage ?? '下载任务创建失败。',
      );
    }
    return RssAutoDownloadEnqueueResult(
      candidate: candidate,
      state: StoredRssAutoDownloadEnqueueState.accepted,
      message: result.warningMessage ?? '下载任务已创建。',
      taskId: task.taskId.value,
    );
  }

  Future<_RssResolvedDownloadSource> _sourceUriFor(
      RssDownloadSource source) async {
    return switch (source) {
      MagnetRssDownloadSource(uri: final String uri) =>
        _RssResolvedDownloadSource.success(uri),
      TorrentRssDownloadSource(uri: final Uri uri) => await _torrentUriFor(uri),
    };
  }

  Future<_RssResolvedDownloadSource> _torrentUriFor(Uri uri) async {
    if (uri.isScheme('file')) {
      return _RssResolvedDownloadSource.success(uri.toString());
    }
    final bool remoteTorrent = uri.isScheme('http') || uri.isScheme('https');
    if (!remoteTorrent) {
      return const _RssResolvedDownloadSource.failure('RSS torrent 来源协议暂不支持。');
    }
    final RssTorrentUrlResolver? resolver = _torrentResolver;
    if (resolver == null) {
      return const _RssResolvedDownloadSource.failure(
          'RSS torrent URL 解析器不可用。');
    }
    final RssTorrentUrlResolution resolved = await resolver.resolve(uri);
    if (!resolved.isSuccess) {
      return _RssResolvedDownloadSource.failure(
        resolved.failureMessage ?? 'RSS torrent URL 解析失败。',
      );
    }
    return _RssResolvedDownloadSource.success(resolved.fileUri!.toString());
  }
}

final class _RssResolvedDownloadSource {
  const _RssResolvedDownloadSource._({this.sourceUri, this.failureMessage});

  const _RssResolvedDownloadSource.success(String sourceUri)
      : this._(sourceUri: sourceUri);

  const _RssResolvedDownloadSource.failure(String message)
      : this._(failureMessage: message);

  final String? sourceUri;
  final String? failureMessage;

  bool get isSuccess => sourceUri != null;
}

final class RssEngineRuntime {
  RssEngineRuntime({
    required RssEngineContract engine,
    required RssFeedStore store,
    required FeedScheduler scheduler,
    RssAutoDownloadPolicyStore? policyStore,
    RssDownloadTaskEnqueuer? downloadTaskEnqueuer,
    DateTime Function()? clock,
  })  : _engine = engine,
        _store = store,
        _scheduler = scheduler,
        _policyStore = policyStore,
        _downloadTaskEnqueuer = downloadTaskEnqueuer,
        _clock = clock,
        _updates = StreamController<FeedItem>.broadcast(sync: true) {
    _engineUpdates = _engine.updates
        .listen(_recordAcceptedUpdate, onError: _recordUpdateFailure);
  }

  final RssEngineContract _engine;
  final RssFeedStore _store;
  final FeedScheduler _scheduler;
  final RssAutoDownloadPolicyStore? _policyStore;
  final RssDownloadTaskEnqueuer? _downloadTaskEnqueuer;
  final DateTime Function()? _clock;
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

  DateTime _now() => (_clock ?? DateTime.now)().toUtc();

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
        updatedAt: _now(),
      ),
    );
  }

  Future<RssEngineActionResult<List<RssAutoDownloadRuleProjection>>>
      autoDownloadRulesForSource(String sourceId) async {
    if (_disposed) return _disposedResult();
    final RssAutoDownloadPolicyStore? policyStore = _policyStore;
    if (policyStore == null) {
      return const RssEngineActionResult<List<RssAutoDownloadRuleProjection>>
          .success(<RssAutoDownloadRuleProjection>[]);
    }
    try {
      final List<StoredRssAutoDownloadRuleRecord> records =
          await policyStore.rulesForPolicy(defaultRssAutoDownloadPolicyId);
      return RssEngineActionResult<List<RssAutoDownloadRuleProjection>>.success(
        List<RssAutoDownloadRuleProjection>.unmodifiable(
          records
              .where((StoredRssAutoDownloadRuleRecord record) =>
                  record.scopedSourceIds.contains(sourceId))
              .map(_ruleProjectionFromRecord),
        ),
      );
    } on Object catch (error) {
      return _failedResult(
          RssEngineRuntimeFailureKind.storageFailure, error.toString());
    }
  }

  Future<RssEngineActionResult<RssAutoDownloadRuleProjection>>
      saveAutoDownloadRule(RssAutoDownloadRuleDraft draft) async {
    if (_disposed) return _disposedResult();
    final RssAutoDownloadPolicyStore? policyStore = _policyStore;
    if (policyStore == null) {
      return _unavailableResult('RSS 自动下载策略存储不可用。');
    }
    final RssEngineRuntimeFailure? validation = _validateRuleDraft(draft);
    if (validation != null) {
      return RssEngineActionResult<RssAutoDownloadRuleProjection>.failed(
          validation);
    }

    try {
      await _ensureDefaultAutoDownloadPolicy(policyStore);
      final String ruleId = _ruleIdForDraft(draft);
      final StoredRssAutoDownloadRuleRecord record =
          _ruleRecordFromDraft(draft, ruleId: ruleId);
      final List<StoredRssAutoDownloadRuleRecord> current =
          await policyStore.rulesForPolicy(defaultRssAutoDownloadPolicyId);
      final List<StoredRssAutoDownloadRuleRecord> next =
          <StoredRssAutoDownloadRuleRecord>[
        for (final StoredRssAutoDownloadRuleRecord existing in current)
          if (existing.id != ruleId) existing,
        record,
      ]..sort((StoredRssAutoDownloadRuleRecord left,
                  StoredRssAutoDownloadRuleRecord right) =>
              left.priority.compareTo(right.priority));
      await policyStore.storeRules(
        policyId: defaultRssAutoDownloadPolicyId,
        rules: next,
      );
      return RssEngineActionResult<RssAutoDownloadRuleProjection>.success(
        _ruleProjectionFromRecord(record),
      );
    } on Object catch (error) {
      return _failedResult(
          RssEngineRuntimeFailureKind.storageFailure, error.toString());
    }
  }

  Future<RssEngineActionResult<bool>> removeAutoDownloadRule(
      String ruleId) async {
    if (_disposed) return _disposedResult();
    final RssAutoDownloadPolicyStore? policyStore = _policyStore;
    if (policyStore == null) {
      return _unavailableResult('RSS 自动下载策略存储不可用。');
    }
    try {
      final List<StoredRssAutoDownloadRuleRecord> current =
          await policyStore.rulesForPolicy(defaultRssAutoDownloadPolicyId);
      final List<StoredRssAutoDownloadRuleRecord> next =
          <StoredRssAutoDownloadRuleRecord>[
        for (final StoredRssAutoDownloadRuleRecord record in current)
          if (record.id != ruleId) record,
      ];
      await policyStore.storeRules(
        policyId: defaultRssAutoDownloadPolicyId,
        rules: next,
      );
      return RssEngineActionResult<bool>.success(next.length != current.length);
    } on Object catch (error) {
      return _failedResult(
          RssEngineRuntimeFailureKind.storageFailure, error.toString());
    }
  }

  Future<RssEngineActionResult<RssAutoDownloadRulePreview>>
      previewAutoDownloadRule(RssAutoDownloadRuleDraft draft) async {
    if (_disposed) return _disposedResult();
    final RssAutoDownloadPolicyStore? policyStore = _policyStore;
    if (policyStore == null) {
      return _unavailableResult('RSS 自动下载策略存储不可用。');
    }
    final RssEngineRuntimeFailure? validation = _validateRuleDraft(draft);
    if (validation != null) {
      return RssEngineActionResult<RssAutoDownloadRulePreview>.failed(
          validation);
    }
    try {
      final String ruleId = draft.ruleId?.trim().isNotEmpty == true
          ? draft.ruleId!.trim()
          : _rssAutoDownloadRuleIdPrefix;
      final RssAutoDownloadRule rule =
          _ruleFromRecord(_ruleRecordFromDraft(draft, ruleId: ruleId));
      final List<FeedItem> items = <FeedItem>[
        for (final FeedItem item in _acceptedItems)
          if (item.sourceId.value == draft.sourceId) item,
      ];
      final RssAutomationEvaluationOutcome outcome =
          await const DeterministicRssAutoDownloadPolicyEvaluator()
              .evaluateTyped(
        policy: RssAutoDownloadPolicy(
          id: const RssAutoDownloadPolicyId(defaultRssAutoDownloadPolicyId),
          label: rssAutoDownloadDefaultPolicyLabel,
          rules: <RssAutoDownloadRule>[rule],
        ),
        items: items,
        history: await _historyStoreFromPolicyStore(policyStore),
      );
      if (!outcome.isSuccess) {
        return _failedResult(RssEngineRuntimeFailureKind.autoDownloadFailure,
            outcome.failure!.message);
      }
      return RssEngineActionResult<RssAutoDownloadRulePreview>.success(
        _previewFromDecisions(ruleId, outcome.decisions),
      );
    } on Object catch (error) {
      return _failedResult(
          RssEngineRuntimeFailureKind.autoDownloadFailure, error.toString());
    }
  }

  Future<RssEngineActionResult<Set<String>>> autoDownloadMatchedItemIds({
    String? sourceId,
  }) async {
    if (_disposed) return _disposedResult();
    final RssAutoDownloadPolicyStore? policyStore = _policyStore;
    if (policyStore == null) {
      return const RssEngineActionResult<Set<String>>.success(<String>{});
    }
    try {
      final Set<String> matched = <String>{};
      final Map<String, List<StoredRssAutoDownloadRuleRecord>> recordsBySource =
          await _enabledRuleRecordsBySource(policyStore);
      for (final MapEntry<String, List<StoredRssAutoDownloadRuleRecord>> entry
          in recordsBySource.entries) {
        if (sourceId != null && entry.key != sourceId) continue;
        if (!await isAutoDownloadEnabled(entry.key)) continue;
        final RssAutomationEvaluationOutcome outcome =
            await const DeterministicRssAutoDownloadPolicyEvaluator()
                .evaluateTyped(
          policy: _policyFromRecords(entry.value),
          items: _acceptedItems
              .where((FeedItem item) => item.sourceId.value == entry.key),
          history: await _historyStoreFromPolicyStore(policyStore),
        );
        if (!outcome.isSuccess) continue;
        for (final RssAutomationDecision decision in outcome.decisions) {
          switch (decision) {
            case RssAutomationAccepted():
              matched.add(decision.item.id.value);
            case RssAutomationDeduplicated():
              matched.add(decision.item.id.value);
            case RssAutomationRejected():
            case RssAutomationDisabled():
              break;
          }
        }
      }
      return RssEngineActionResult<Set<String>>.success(
          Set<String>.unmodifiable(matched));
    } on Object catch (error) {
      return _failedResult(
          RssEngineRuntimeFailureKind.autoDownloadFailure, error.toString());
    }
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
      if (outcome.isSuccess && outcome.newItems.isNotEmpty) {
        await _executeAutoDownloadsForItems(sourceId, outcome.newItems);
      }
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

  Future<RssAutoDownloadExecutionReport> _executeAutoDownloadsForItems(
    FeedSourceId sourceId,
    Iterable<FeedItem> items,
  ) async {
    final RssAutoDownloadPolicyStore? policyStore = _policyStore;
    final RssDownloadTaskEnqueuer? enqueuer = _downloadTaskEnqueuer;
    if (policyStore == null || enqueuer == null) {
      return RssAutoDownloadExecutionReport(
        previews: const <RssAutoDownloadRulePreview>[],
        enqueueResults: const <RssAutoDownloadEnqueueResult>[],
      );
    }
    if (!await isAutoDownloadEnabled(sourceId.value)) {
      return RssAutoDownloadExecutionReport(
        previews: const <RssAutoDownloadRulePreview>[],
        enqueueResults: const <RssAutoDownloadEnqueueResult>[],
      );
    }

    final List<StoredRssAutoDownloadRuleRecord> rules =
        (await policyStore.rulesForPolicy(defaultRssAutoDownloadPolicyId))
            .where((StoredRssAutoDownloadRuleRecord rule) =>
                rule.enabled && rule.scopedSourceIds.contains(sourceId.value))
            .toList(growable: false);
    if (rules.isEmpty) {
      return RssAutoDownloadExecutionReport(
        previews: const <RssAutoDownloadRulePreview>[],
        enqueueResults: const <RssAutoDownloadEnqueueResult>[],
      );
    }

    await _ensureDefaultAutoDownloadPolicy(policyStore);
    final RssAutoDownloadPolicy policy = _policyFromRecords(rules);
    final String scopeId = sourceId.value;
    final RssAutoDownloadPolicyRuntime runtime =
        RssAutoDownloadPolicyRuntimeBootstrap(
      policyStore: policyStore,
      evaluatorByScope: <String, DeterministicRssAutoDownloadPolicyEvaluator>{
        scopeId: const DeterministicRssAutoDownloadPolicyEvaluator(),
      },
      capabilitiesByScope: <String, RssAutomationCapabilityMatrix>{
        scopeId: _supportedRssAutomationCapabilities(),
      },
      historyStore: await _historyStoreFromPolicyStore(policyStore),
      clock: _now,
    ).createRuntime();

    final RssAutoDownloadPolicyRuntimeActionResult<
            RssAutoDownloadPolicyRuntimeProjection> evaluated =
        await runtime.evaluate(scopeId, policy, items);
    if (!evaluated.isSuccess ||
        evaluated.value?.latestEvaluationOutcome == null) {
      return RssAutoDownloadExecutionReport(
        previews: const <RssAutoDownloadRulePreview>[],
        enqueueResults: const <RssAutoDownloadEnqueueResult>[],
      );
    }

    final List<RssAutoDownloadRulePreview> previews =
        <RssAutoDownloadRulePreview>[];
    final List<RssAutoDownloadEnqueueResult> enqueueResults =
        <RssAutoDownloadEnqueueResult>[];
    final List<RssAutomationDecision> decisions =
        evaluated.value!.latestEvaluationOutcome!.decisions;
    for (final StoredRssAutoDownloadRuleRecord rule in rules) {
      previews.add(_previewFromDecisions(rule.id, decisions));
    }
    for (final RssAutomationAccepted accepted
        in decisions.whereType<RssAutomationAccepted>()) {
      final RssAutoDownloadPolicyRuntimeActionResult<
              RssAutoDownloadPolicyRuntimeProjection> handedOff =
          await runtime.handoff(scopeId, accepted.candidate);
      if (!handedOff.isSuccess) continue;
      final RssAutoDownloadEnqueueResult enqueued =
          await enqueuer.enqueue(accepted.candidate);
      await _recordEnqueueResult(policyStore, enqueued);
      enqueueResults.add(enqueued);
    }

    return RssAutoDownloadExecutionReport(
      previews: previews,
      enqueueResults: enqueueResults,
    );
  }

  RssEngineRuntimeFailure? _validateRuleDraft(RssAutoDownloadRuleDraft draft) {
    if (draft.sourceId.trim().isEmpty) {
      return const RssEngineRuntimeFailure(
        kind: RssEngineRuntimeFailureKind.autoDownloadFailure,
        message: '请选择订阅源。',
      );
    }
    if (draft.label.trim().isEmpty) {
      return const RssEngineRuntimeFailure(
        kind: RssEngineRuntimeFailureKind.autoDownloadFailure,
        message: '规则名称不能为空。',
      );
    }
    if (_includePredicatesForDraft(draft).isEmpty) {
      return const RssEngineRuntimeFailure(
        kind: RssEngineRuntimeFailureKind.autoDownloadFailure,
        message: '至少配置一个自动下载筛选条件。',
      );
    }
    final String regex = draft.titleRegex.trim();
    if (regex.isNotEmpty) {
      try {
        RegExp(regex);
      } on FormatException catch (error) {
        return RssEngineRuntimeFailure(
          kind: RssEngineRuntimeFailureKind.autoDownloadFailure,
          message: '标题正则无效：${error.message}',
        );
      }
    }
    return null;
  }

  String _ruleIdForDraft(RssAutoDownloadRuleDraft draft) {
    final String? existing = draft.ruleId?.trim();
    if (existing != null && existing.isNotEmpty) return existing;
    return '$_rssAutoDownloadRuleIdPrefix-'
        '${Uri.encodeComponent(draft.sourceId)}-${_now().microsecondsSinceEpoch}';
  }

  Future<void> _ensureDefaultAutoDownloadPolicy(
      RssAutoDownloadPolicyStore policyStore) async {
    final StoredRssAutoDownloadPolicyRecord? existing =
        await policyStore.policyById(defaultRssAutoDownloadPolicyId);
    if (existing != null) return;
    await policyStore.storePolicy(
      StoredRssAutoDownloadPolicyRecord(
        id: defaultRssAutoDownloadPolicyId,
        label: rssAutoDownloadDefaultPolicyLabel,
        enabled: true,
        createdAt: _now(),
        updatedAt: _now(),
      ),
    );
  }

  Future<DeterministicRssAutomationHistoryStore> _historyStoreFromPolicyStore(
    RssAutoDownloadPolicyStore policyStore,
  ) async {
    final List<StoredRssAutoDownloadDedupeRecord> records =
        await policyStore.dedupeKeysForPolicy(defaultRssAutoDownloadPolicyId);
    return DeterministicRssAutomationHistoryStore(
      seedAcceptedKeys: <FeedDedupeKey>[
        for (final StoredRssAutoDownloadDedupeRecord record in records)
          FeedDedupeKey(record.itemDedupeKey),
      ],
    );
  }

  Future<Map<String, List<StoredRssAutoDownloadRuleRecord>>>
      _enabledRuleRecordsBySource(
          RssAutoDownloadPolicyStore policyStore) async {
    final Map<String, List<StoredRssAutoDownloadRuleRecord>> grouped =
        <String, List<StoredRssAutoDownloadRuleRecord>>{};
    for (final StoredRssAutoDownloadRuleRecord record
        in await policyStore.rulesForPolicy(defaultRssAutoDownloadPolicyId)) {
      if (!record.enabled) continue;
      for (final String sourceId in record.scopedSourceIds) {
        grouped.putIfAbsent(
            sourceId, () => <StoredRssAutoDownloadRuleRecord>[]);
        grouped[sourceId]!.add(record);
      }
    }
    return grouped;
  }

  Future<void> _recordEnqueueResult(
    RssAutoDownloadPolicyStore policyStore,
    RssAutoDownloadEnqueueResult result,
  ) async {
    await policyStore.recordEnqueueOutcome(
      StoredRssAutoDownloadEnqueueOutcomeRecord(
        id: '$_rssAutoDownloadEnqueueIdPrefix-'
            '${result.candidate.item.id.value}',
        candidateId: result.candidate.item.id.value,
        policyId: result.candidate.policyId.value,
        state: result.state,
        message: result.message,
        recordedAt: _now(),
        taskId: result.taskId,
      ),
    );
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
    RssDownloadTaskEnqueuer? downloadTaskEnqueuer,
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
          downloadTaskEnqueuer: downloadTaskEnqueuer,
          clock: clock,
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

const String _rssAutoDownloadDraftTokenPattern = r'[,，\r\n]+';
const String _rssAutoDownloadTokenJoiner = ', ';

StoredRssAutoDownloadRuleRecord _ruleRecordFromDraft(
  RssAutoDownloadRuleDraft draft, {
  required String ruleId,
}) {
  return StoredRssAutoDownloadRuleRecord(
    id: ruleId,
    policyId: defaultRssAutoDownloadPolicyId,
    label: draft.label.trim(),
    priority: draft.priority,
    enabled: draft.enabled,
    scopedSourceIds: <String>[draft.sourceId.trim()],
    includeMatcher: StoredRssAutoDownloadMatcherRecord(
      ruleId: ruleId,
      logic: StoredRssAutoDownloadMatcherLogic.all,
      predicates: _includePredicatesForDraft(draft),
    ),
    excludeMatcher: _excludePredicatesForDraft(draft).isEmpty
        ? null
        : StoredRssAutoDownloadMatcherRecord(
            ruleId: ruleId,
            logic: StoredRssAutoDownloadMatcherLogic.any,
            predicates: _excludePredicatesForDraft(draft),
          ),
  );
}

List<StoredRssAutoDownloadMatcherPredicateRecord> _includePredicatesForDraft(
  RssAutoDownloadRuleDraft draft,
) {
  return <StoredRssAutoDownloadMatcherPredicateRecord>[
    if (draft.titleContains.trim().isNotEmpty)
      StoredRssAutoDownloadMatcherPredicateRecord(
        field: StoredRssAutoDownloadMatcherField.title,
        operator: StoredRssAutoDownloadMatcherOperator.contains,
        value: draft.titleContains.trim(),
      ),
    if (draft.titleRegex.trim().isNotEmpty)
      StoredRssAutoDownloadMatcherPredicateRecord(
        field: StoredRssAutoDownloadMatcherField.title,
        operator: StoredRssAutoDownloadMatcherOperator.regex,
        value: draft.titleRegex.trim(),
      ),
    if (draft.categoryContains.trim().isNotEmpty)
      StoredRssAutoDownloadMatcherPredicateRecord(
        field: StoredRssAutoDownloadMatcherField.category,
        operator: StoredRssAutoDownloadMatcherOperator.contains,
        value: draft.categoryContains.trim(),
      ),
    if (draft.requireDownloadSource)
      const StoredRssAutoDownloadMatcherPredicateRecord(
        field: StoredRssAutoDownloadMatcherField.downloadSource,
        operator: StoredRssAutoDownloadMatcherOperator.exists,
      ),
  ];
}

List<StoredRssAutoDownloadMatcherPredicateRecord> _excludePredicatesForDraft(
  RssAutoDownloadRuleDraft draft,
) {
  return <StoredRssAutoDownloadMatcherPredicateRecord>[
    for (final String token in _splitDraftTokens(draft.excludeTitleContains))
      StoredRssAutoDownloadMatcherPredicateRecord(
        field: StoredRssAutoDownloadMatcherField.title,
        operator: StoredRssAutoDownloadMatcherOperator.contains,
        value: token,
      ),
  ];
}

List<String> _splitDraftTokens(String value) {
  return value
      .split(RegExp(_rssAutoDownloadDraftTokenPattern))
      .map((String token) => token.trim())
      .where((String token) => token.isNotEmpty)
      .toList(growable: false);
}

RssAutoDownloadRuleProjection _ruleProjectionFromRecord(
  StoredRssAutoDownloadRuleRecord record,
) {
  String titleContains = '';
  String titleRegex = '';
  String categoryContains = '';
  bool requireDownloadSource = false;
  for (final StoredRssAutoDownloadMatcherPredicateRecord predicate
      in record.includeMatcher.predicates) {
    if (predicate.field == StoredRssAutoDownloadMatcherField.title &&
        predicate.operator == StoredRssAutoDownloadMatcherOperator.contains) {
      titleContains = predicate.value ?? '';
    }
    if (predicate.field == StoredRssAutoDownloadMatcherField.title &&
        predicate.operator == StoredRssAutoDownloadMatcherOperator.regex) {
      titleRegex = predicate.value ?? '';
    }
    if (predicate.field == StoredRssAutoDownloadMatcherField.category &&
        predicate.operator == StoredRssAutoDownloadMatcherOperator.contains) {
      categoryContains = predicate.value ?? '';
    }
    if (predicate.field == StoredRssAutoDownloadMatcherField.downloadSource &&
        predicate.operator == StoredRssAutoDownloadMatcherOperator.exists) {
      requireDownloadSource = true;
    }
  }
  final List<String> excludes = <String>[
    for (final StoredRssAutoDownloadMatcherPredicateRecord predicate
        in record.excludeMatcher?.predicates ??
            const <StoredRssAutoDownloadMatcherPredicateRecord>[])
      if (predicate.field == StoredRssAutoDownloadMatcherField.title &&
          predicate.operator == StoredRssAutoDownloadMatcherOperator.contains &&
          predicate.value != null)
        predicate.value!,
  ];
  return RssAutoDownloadRuleProjection(
    ruleId: record.id,
    sourceId: record.scopedSourceIds.single,
    label: record.label,
    enabled: record.enabled,
    priority: record.priority,
    titleContains: titleContains,
    titleRegex: titleRegex,
    excludeTitleContains: excludes.join(_rssAutoDownloadTokenJoiner),
    categoryContains: categoryContains,
    requireDownloadSource: requireDownloadSource,
  );
}

RssAutoDownloadPolicy _policyFromRecords(
  Iterable<StoredRssAutoDownloadRuleRecord> records,
) {
  return RssAutoDownloadPolicy(
    id: const RssAutoDownloadPolicyId(defaultRssAutoDownloadPolicyId),
    label: rssAutoDownloadDefaultPolicyLabel,
    rules: <RssAutoDownloadRule>[
      for (final StoredRssAutoDownloadRuleRecord record in records)
        _ruleFromRecord(record),
    ],
  );
}

RssAutoDownloadRule _ruleFromRecord(StoredRssAutoDownloadRuleRecord record) {
  return RssAutoDownloadRule(
    id: RssAutoDownloadRuleId(record.id),
    label: record.label,
    priority: record.priority,
    enabled: record.enabled,
    scopedSources: <FeedSourceId>[
      for (final String sourceId in record.scopedSourceIds)
        FeedSourceId(sourceId),
    ],
    include: _matcherFromRecord(record.includeMatcher),
    exclude: record.excludeMatcher == null
        ? null
        : _matcherFromRecord(record.excludeMatcher!),
  );
}

RssMatcherExpression _matcherFromRecord(
    StoredRssAutoDownloadMatcherRecord record) {
  return RssMatcherExpression(
    logic: _matcherLogicFromStored(record.logic),
    predicates: <RssMatcherPredicate>[
      for (final StoredRssAutoDownloadMatcherPredicateRecord predicate
          in record.predicates)
        RssMatcherPredicate(
          field: _matcherFieldFromStored(predicate.field),
          operator: _matcherOperatorFromStored(predicate.operator),
          value: predicate.value,
          metadataKey: predicate.metadataKey,
          caseSensitive: predicate.caseSensitive,
          negated: predicate.negated,
        ),
    ],
  );
}

RssAutoDownloadRulePreview _previewFromDecisions(
  String ruleId,
  Iterable<RssAutomationDecision> decisions,
) {
  final List<FeedItemId> matched = <FeedItemId>[];
  final List<FeedItemId> rejected = <FeedItemId>[];
  final List<FeedItemId> duplicate = <FeedItemId>[];
  for (final RssAutomationDecision decision in decisions) {
    switch (decision) {
      case RssAutomationAccepted():
        if (decision.candidate.ruleId.value == ruleId) {
          matched.add(decision.item.id);
        }
      case RssAutomationRejected():
        rejected.add(decision.item.id);
      case RssAutomationDeduplicated():
        duplicate.add(decision.item.id);
      case RssAutomationDisabled():
        rejected.add(decision.item.id);
    }
  }
  return RssAutoDownloadRulePreview(
    ruleId: ruleId,
    matchedItemIds: matched,
    rejectedItemIds: rejected,
    duplicateItemIds: duplicate,
  );
}

RssAutomationCapabilityMatrix _supportedRssAutomationCapabilities() {
  return RssAutomationCapabilityMatrix(
    capabilities: <RssAutomationCapability, RssAutomationCapabilityStatus>{
      for (final RssAutomationCapability capability
          in RssAutomationCapability.values)
        capability: const RssAutomationCapabilityStatus.supported(),
    },
  );
}

RssMatcherField _matcherFieldFromStored(
  StoredRssAutoDownloadMatcherField field,
) {
  return switch (field) {
    StoredRssAutoDownloadMatcherField.title => RssMatcherField.title,
    StoredRssAutoDownloadMatcherField.releaseGroup =>
      RssMatcherField.releaseGroup,
    StoredRssAutoDownloadMatcherField.episode => RssMatcherField.episode,
    StoredRssAutoDownloadMatcherField.season => RssMatcherField.season,
    StoredRssAutoDownloadMatcherField.resolution => RssMatcherField.resolution,
    StoredRssAutoDownloadMatcherField.sizeBytes => RssMatcherField.sizeBytes,
    StoredRssAutoDownloadMatcherField.category => RssMatcherField.category,
    StoredRssAutoDownloadMatcherField.sourceId => RssMatcherField.sourceId,
    StoredRssAutoDownloadMatcherField.downloadSource =>
      RssMatcherField.downloadSource,
    StoredRssAutoDownloadMatcherField.metadata => RssMatcherField.metadata,
  };
}

RssMatcherOperator _matcherOperatorFromStored(
  StoredRssAutoDownloadMatcherOperator operator,
) {
  return switch (operator) {
    StoredRssAutoDownloadMatcherOperator.contains =>
      RssMatcherOperator.contains,
    StoredRssAutoDownloadMatcherOperator.equals => RssMatcherOperator.equals,
    StoredRssAutoDownloadMatcherOperator.regex => RssMatcherOperator.regex,
    StoredRssAutoDownloadMatcherOperator.glob => RssMatcherOperator.glob,
    StoredRssAutoDownloadMatcherOperator.greaterThanOrEqual =>
      RssMatcherOperator.greaterThanOrEqual,
    StoredRssAutoDownloadMatcherOperator.lessThanOrEqual =>
      RssMatcherOperator.lessThanOrEqual,
    StoredRssAutoDownloadMatcherOperator.exists => RssMatcherOperator.exists,
  };
}

RssMatcherLogic _matcherLogicFromStored(
  StoredRssAutoDownloadMatcherLogic logic,
) {
  return switch (logic) {
    StoredRssAutoDownloadMatcherLogic.all => RssMatcherLogic.all,
    StoredRssAutoDownloadMatcherLogic.any => RssMatcherLogic.any,
  };
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
