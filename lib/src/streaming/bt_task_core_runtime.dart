import 'dart:async';

import '../foundation/baseline_defaults.dart';
import '../foundation/cache_invalidation/cache_invalidation_bus.dart';
import '../foundation/storage/storage_contracts.dart';
import 'bt_task_core.dart';

enum BtTaskCoreRuntimeStatus {
  idle,
  creating,
  fetchingMetadata,
  selectingFiles,
  commanding,
  observing,
  projecting,
  ready,
  failed,
  disposed,
}

enum BtTaskCoreRuntimeFailureKind {
  disposed,
  unavailable,
  ignored,
  capabilityUnsupported,
  taskNotFound,
  adapterFailure,
  storageFailure,
  observationFailure,
}

final class BtTaskCoreRuntimeFailure {
  const BtTaskCoreRuntimeFailure({required this.kind, required this.message})
      : assert(message != '',
            'BT task core runtime failure message must not be empty.');

  final BtTaskCoreRuntimeFailureKind kind;
  final String message;
}

enum BtTaskCoreRuntimeActionResultKind {
  success,
  ignored,
  unavailable,
  failed,
  disposed,
}

final class BtTaskCoreRuntimeActionResult<T> {
  const BtTaskCoreRuntimeActionResult._({
    required this.kind,
    this.value,
    this.failure,
  });

  const BtTaskCoreRuntimeActionResult.success([T? value])
      : this._(kind: BtTaskCoreRuntimeActionResultKind.success, value: value);

  const BtTaskCoreRuntimeActionResult.ignored(BtTaskCoreRuntimeFailure failure)
      : this._(
          kind: BtTaskCoreRuntimeActionResultKind.ignored,
          failure: failure,
        );

  const BtTaskCoreRuntimeActionResult.unavailable(
      BtTaskCoreRuntimeFailure failure)
      : this._(
          kind: BtTaskCoreRuntimeActionResultKind.unavailable,
          failure: failure,
        );

  const BtTaskCoreRuntimeActionResult.failed(BtTaskCoreRuntimeFailure failure)
      : this._(
          kind: BtTaskCoreRuntimeActionResultKind.failed,
          failure: failure,
        );

  const BtTaskCoreRuntimeActionResult.disposed(BtTaskCoreRuntimeFailure failure)
      : this._(
          kind: BtTaskCoreRuntimeActionResultKind.disposed,
          failure: failure,
        );

  final BtTaskCoreRuntimeActionResultKind kind;
  final T? value;
  final BtTaskCoreRuntimeFailure? failure;

  bool get isSuccess => kind == BtTaskCoreRuntimeActionResultKind.success;
}

final class BtTaskMetadataProjection {
  const BtTaskMetadataProjection({
    required this.taskId,
    required this.infoHash,
    required this.name,
    required this.totalSizeBytes,
    required this.pieceLengthBytes,
  });

  final BtTaskId taskId;
  final InfoHash infoHash;
  final String name;
  final int totalSizeBytes;
  final int pieceLengthBytes;
}

final class BtTaskFileProjection {
  const BtTaskFileProjection({
    required this.taskId,
    required this.index,
    required this.path,
    required this.lengthBytes,
    required this.offsetBytes,
    required this.selectionState,
    this.mediaMimeType,
  });

  final BtTaskId taskId;
  final BtFileIndex index;
  final String path;
  final int lengthBytes;
  final int offsetBytes;
  final BtFileSelectionState selectionState;
  final String? mediaMimeType;
}

final class BtTaskTransferSnapshotProjection {
  const BtTaskTransferSnapshotProjection({
    required this.taskId,
    required this.lifecycleState,
    required this.progress,
    required this.downloadRateBytesPerSecond,
    required this.uploadRateBytesPerSecond,
    required this.connectedPeers,
    required this.observedAt,
    this.message,
  });

  final BtTaskId taskId;
  final BtTaskLifecycleState lifecycleState;
  final double progress;
  final int downloadRateBytesPerSecond;
  final int uploadRateBytesPerSecond;
  final int connectedPeers;
  final DateTime observedAt;
  final String? message;
}

final class BtTaskEventProjection {
  const BtTaskEventProjection({
    required this.taskId,
    required this.eventKind,
    required this.occurredAt,
    this.pieceIndex,
    this.message,
  });

  final BtTaskId taskId;
  final StoredBtTaskEventKind eventKind;
  final DateTime occurredAt;
  final BtPieceIndex? pieceIndex;
  final String? message;
}

enum BtRuntimeRestartDisposition {
  resumable,
  paused,
  terminal,
  failed,
  removed,
  incomplete,
}

final class BtTaskRestartProjection {
  const BtTaskRestartProjection({
    required this.taskId,
    required this.disposition,
    required this.requiresAdapterReconciliation,
    this.reason,
  });

  final BtTaskId taskId;
  final BtRuntimeRestartDisposition disposition;
  final bool requiresAdapterReconciliation;
  final String? reason;
}

final class BtTaskProjection {
  BtTaskProjection({
    required this.taskId,
    required this.sourceKind,
    required this.sourceUri,
    required this.lifecycleState,
    required this.createdAt,
    required this.updatedAt,
    this.infoHash,
    this.message,
    this.metadata,
    Iterable<BtTaskFileProjection> files = const <BtTaskFileProjection>[],
    this.latestTransferSnapshot,
    this.latestEvent,
    this.restart,
  }) : files = List<BtTaskFileProjection>.unmodifiable(files);

  final BtTaskId taskId;
  final StoredBtTaskSourceKind sourceKind;
  final String sourceUri;
  final StoredBtTaskLifecycleState lifecycleState;
  final DateTime createdAt;
  final DateTime updatedAt;
  final InfoHash? infoHash;
  final String? message;
  final BtTaskMetadataProjection? metadata;
  final List<BtTaskFileProjection> files;
  final BtTaskTransferSnapshotProjection? latestTransferSnapshot;
  final BtTaskEventProjection? latestEvent;
  final BtTaskRestartProjection? restart;
}

final class BtTaskRuntimeObservation<T> {
  const BtTaskRuntimeObservation({required this.values});

  final Stream<T> values;
}

final class BtTaskCoreRuntimeSnapshot {
  BtTaskCoreRuntimeSnapshot({
    required this.status,
    required this.capabilities,
    Iterable<BtTaskProjection> tasks = const <BtTaskProjection>[],
    Iterable<BtTaskCoreRuntimeFailure> failures =
        const <BtTaskCoreRuntimeFailure>[],
  })  : tasks = List<BtTaskProjection>.unmodifiable(tasks),
        failures = List<BtTaskCoreRuntimeFailure>.unmodifiable(failures);

  BtTaskCoreRuntimeSnapshot.idle({required BtCapabilityMatrix capabilities})
      : this(status: BtTaskCoreRuntimeStatus.idle, capabilities: capabilities);

  final BtTaskCoreRuntimeStatus status;
  final BtCapabilityMatrix capabilities;
  final List<BtTaskProjection> tasks;
  final List<BtTaskCoreRuntimeFailure> failures;
}

abstract interface class BtTaskCoreRuntimeObserver {
  void onBtTaskCoreRuntimeSnapshot(BtTaskCoreRuntimeSnapshot snapshot);
}

final class BtTaskCoreBootstrap {
  BtTaskCoreBootstrap({
    required DownloadEngineAdapter adapter,
    required BtTaskStore store,
    CacheInvalidationBus? cacheInvalidationBus,
    DateTime Function()? clock,
  }) : runtime = BtTaskCoreRuntime.withDependencies(
          adapter: adapter,
          store: store,
          cacheInvalidationBus: cacheInvalidationBus,
          clock: clock,
        );

  BtTaskCoreBootstrap.withRuntime({required this.runtime});

  final BtTaskCoreRuntime runtime;
}

final class BtTaskCoreRuntime {
  BtTaskCoreRuntime.withDependencies({
    required DownloadEngineAdapter adapter,
    required BtTaskStore store,
    CacheInvalidationBus? cacheInvalidationBus,
    DateTime Function()? clock,
  }) : this._(
          core: DeterministicBtTaskCore(
            adapter: adapter,
            store: store,
            cacheInvalidationBus: cacheInvalidationBus,
            clock: clock,
          ),
          store: store,
          capabilities: adapter.capabilities,
        );

  BtTaskCoreRuntime({
    required BtTaskCoreContract core,
    required BtTaskStore store,
    required BtCapabilityMatrix capabilities,
  }) : this._(core: core, store: store, capabilities: capabilities);

  BtTaskCoreRuntime.unavailable({required String reason})
      : this._(
          core: _UnavailableBtTaskCore(reason),
          store: DeterministicBtTaskStore(),
          capabilities: BtCapabilityMatrix.unsupported(reason: reason),
        );

  BtTaskCoreRuntime._({
    required BtTaskCoreContract core,
    required BtTaskStore store,
    required BtCapabilityMatrix capabilities,
  })  : _core = core,
        _store = store,
        _capabilities = capabilities,
        _snapshot = BtTaskCoreRuntimeSnapshot.idle(capabilities: capabilities);

  final BtTaskCoreContract _core;
  final BtTaskStore _store;
  final BtCapabilityMatrix _capabilities;
  final List<BtTaskCoreRuntimeObserver> _observers =
      <BtTaskCoreRuntimeObserver>[];
  BtTaskCoreRuntimeSnapshot _snapshot;
  bool _disposed = false;

  bool get isDisposed => _disposed;

  BtTaskCoreRuntimeSnapshot get currentSnapshot => _snapshot;

  void addObserver(BtTaskCoreRuntimeObserver observer) {
    if (_disposed) throw StateError('BtTaskCoreRuntime has been disposed.');
    if (!_observers.contains(observer)) _observers.add(observer);
  }

  void removeObserver(BtTaskCoreRuntimeObserver observer) {
    _observers.remove(observer);
  }

  Future<BtTaskCoreRuntimeActionResult<BtTaskProjection>> createTask(
    BtTaskCreateRequest request,
  ) async {
    if (_disposed) return _disposedResult();
    _publish(status: BtTaskCoreRuntimeStatus.creating);
    try {
      final BtTaskCreateOutcome outcome = await _core.createTask(request);
      if (!outcome.isSuccess) return _failureFromBtFailure(outcome.failure!);
      final BtTaskProjection? projection =
          await _taskProjection(outcome.taskId!);
      await _refreshSnapshot(status: BtTaskCoreRuntimeStatus.ready);
      return BtTaskCoreRuntimeActionResult<BtTaskProjection>.success(
        projection,
      );
    } on Object catch (error) {
      return _failedResult(
        BtTaskCoreRuntimeFailureKind.adapterFailure,
        error.toString(),
      );
    }
  }

  Future<BtTaskCoreRuntimeActionResult<BtTaskProjection>> ensureMetadata(
    BtTaskId taskId,
  ) async {
    if (_disposed) return _disposedResult();
    _publish(status: BtTaskCoreRuntimeStatus.fetchingMetadata);
    try {
      final BtTaskMetadataOutcome outcome = await _core.ensureMetadata(taskId);
      if (!outcome.isSuccess) return _failureFromBtFailure(outcome.failure!);
      final BtTaskProjection? projection = await _taskProjection(taskId);
      await _refreshSnapshot(status: BtTaskCoreRuntimeStatus.ready);
      if (projection == null) return _taskNotFound(taskId);
      return BtTaskCoreRuntimeActionResult<BtTaskProjection>.success(
        projection,
      );
    } on Object catch (error) {
      return _failedResult(
        BtTaskCoreRuntimeFailureKind.adapterFailure,
        error.toString(),
      );
    }
  }

  Future<BtTaskCoreRuntimeActionResult<BtTaskProjection>> selectFiles(
    BtTaskId taskId,
    Iterable<BtFileIndex> files,
  ) {
    return _runCommand(
      status: BtTaskCoreRuntimeStatus.selectingFiles,
      taskId: taskId,
      command: () => _core.selectFiles(taskId, files),
    );
  }

  Future<BtTaskCoreRuntimeActionResult<BtTaskProjection>> pause(
    BtTaskId taskId,
  ) {
    return _runCommand(
      status: BtTaskCoreRuntimeStatus.commanding,
      taskId: taskId,
      command: () => _core.pause(taskId),
    );
  }

  Future<BtTaskCoreRuntimeActionResult<BtTaskProjection>> resume(
    BtTaskId taskId,
  ) {
    return _runCommand(
      status: BtTaskCoreRuntimeStatus.commanding,
      taskId: taskId,
      command: () => _core.resume(taskId),
    );
  }

  Future<BtTaskCoreRuntimeActionResult<BtTaskProjection>> remove(
    BtTaskId taskId,
  ) {
    return _runCommand(
      status: BtTaskCoreRuntimeStatus.commanding,
      taskId: taskId,
      command: () => _core.remove(taskId),
    );
  }

  Future<BtTaskCoreRuntimeActionResult<List<BtTaskProjection>>> listTasks({
    int offset = 0,
    int limit = defaultListPageLimit,
  }) async {
    if (_disposed) return _disposedResult();
    _publish(status: BtTaskCoreRuntimeStatus.projecting);
    try {
      final List<BtTaskProjection> projections = await _taskProjections(
        offset: offset,
        limit: limit,
      );
      _publish(status: BtTaskCoreRuntimeStatus.ready, tasks: projections);
      return BtTaskCoreRuntimeActionResult<List<BtTaskProjection>>.success(
        List<BtTaskProjection>.unmodifiable(projections),
      );
    } on Object catch (error) {
      return _failedResult(
        BtTaskCoreRuntimeFailureKind.storageFailure,
        error.toString(),
      );
    }
  }

  Future<BtTaskCoreRuntimeActionResult<BtTaskProjection?>> taskById(
    BtTaskId taskId,
  ) async {
    if (_disposed) return _disposedResult();
    _publish(status: BtTaskCoreRuntimeStatus.projecting);
    try {
      final BtTaskProjection? projection = await _taskProjection(taskId);
      _publish(
        status: BtTaskCoreRuntimeStatus.ready,
        tasks: projection == null ? null : <BtTaskProjection>[projection],
      );
      return BtTaskCoreRuntimeActionResult<BtTaskProjection?>.success(
        projection,
      );
    } on Object catch (error) {
      return _failedResult(
        BtTaskCoreRuntimeFailureKind.storageFailure,
        error.toString(),
      );
    }
  }

  Future<BtTaskCoreRuntimeActionResult<List<BtTaskRestartProjection>>>
      restartReconciliation() async {
    if (_disposed) return _disposedResult();
    _publish(status: BtTaskCoreRuntimeStatus.projecting);
    try {
      final List<BtTaskProjection> tasks = await _taskProjections();
      final List<BtTaskRestartProjection> reconciliation =
          <BtTaskRestartProjection>[
        for (final BtTaskProjection task in tasks) task.restart!,
      ];
      _publish(status: BtTaskCoreRuntimeStatus.ready, tasks: tasks);
      return BtTaskCoreRuntimeActionResult<
              List<BtTaskRestartProjection>>.success(
          List<BtTaskRestartProjection>.unmodifiable(reconciliation));
    } on Object catch (error) {
      return _failedResult(
        BtTaskCoreRuntimeFailureKind.storageFailure,
        error.toString(),
      );
    }
  }

  BtTaskCoreRuntimeActionResult<BtTaskRuntimeObservation<BtTaskStatus>>
      observeStatus(BtTaskId taskId) {
    if (_disposed) return _disposedResult();
    _publish(status: BtTaskCoreRuntimeStatus.observing);
    return BtTaskCoreRuntimeActionResult<
        BtTaskRuntimeObservation<BtTaskStatus>>.success(
      BtTaskRuntimeObservation<BtTaskStatus>(
        values: _core.watchStatus(taskId).transform(
          StreamTransformer<BtTaskStatus, BtTaskStatus>.fromHandlers(
            handleData: (BtTaskStatus status, EventSink<BtTaskStatus> sink) {
              _refreshSnapshot(status: BtTaskCoreRuntimeStatus.ready);
              sink.add(status);
            },
          ),
        ),
      ),
    );
  }

  BtTaskCoreRuntimeActionResult<BtTaskRuntimeObservation<BtTaskEvent>>
      observeEvents(BtTaskId taskId) {
    if (_disposed) return _disposedResult();
    _publish(status: BtTaskCoreRuntimeStatus.observing);
    return BtTaskCoreRuntimeActionResult<
        BtTaskRuntimeObservation<BtTaskEvent>>.success(
      BtTaskRuntimeObservation<BtTaskEvent>(
        values: _core.watchEvents(taskId).transform(
          StreamTransformer<BtTaskEvent, BtTaskEvent>.fromHandlers(
            handleData: (BtTaskEvent event, EventSink<BtTaskEvent> sink) {
              _refreshSnapshot(status: BtTaskCoreRuntimeStatus.ready);
              sink.add(event);
            },
          ),
        ),
      ),
    );
  }

  Future<BtTaskCoreRuntimeActionResult<bool>> dispose() async {
    if (_disposed) return _disposedResult();
    _disposed = true;
    _publish(
      status: BtTaskCoreRuntimeStatus.disposed,
      failures: const <BtTaskCoreRuntimeFailure>[
        BtTaskCoreRuntimeFailure(
          kind: BtTaskCoreRuntimeFailureKind.disposed,
          message: 'BtTaskCoreRuntime has been disposed.',
        ),
      ],
    );
    _observers.clear();
    return const BtTaskCoreRuntimeActionResult<bool>.success(true);
  }

  Future<BtTaskCoreRuntimeActionResult<BtTaskProjection>> _runCommand({
    required BtTaskCoreRuntimeStatus status,
    required BtTaskId taskId,
    required Future<BtTaskCommandOutcome> Function() command,
  }) async {
    if (_disposed) return _disposedResult();
    _publish(status: status);
    try {
      final BtTaskCommandOutcome outcome = await command();
      if (!outcome.isSuccess) return _failureFromBtFailure(outcome.failure!);
      final BtTaskProjection? projection = await _taskProjection(taskId);
      await _refreshSnapshot(status: BtTaskCoreRuntimeStatus.ready);
      if (projection == null) return _taskNotFound(taskId);
      return BtTaskCoreRuntimeActionResult<BtTaskProjection>.success(
        projection,
      );
    } on Object catch (error) {
      return _failedResult(
        BtTaskCoreRuntimeFailureKind.adapterFailure,
        error.toString(),
      );
    }
  }

  Future<void> _refreshSnapshot(
      {required BtTaskCoreRuntimeStatus status}) async {
    _publish(status: status, tasks: await _taskProjections());
  }

  Future<List<BtTaskProjection>> _taskProjections({
    int offset = 0,
    int limit = defaultListPageLimit,
  }) async {
    return <BtTaskProjection>[
      for (final StoredBtTaskRecord record
          in await _store.listTasks(offset: offset, limit: limit))
        await _projectionFromRecord(record),
    ];
  }

  Future<BtTaskProjection?> _taskProjection(BtTaskId taskId) async {
    final StoredBtTaskRecord? task = await _store.findTaskById(taskId.value);
    if (task == null) return null;
    return _projectionFromRecord(task);
  }

  Future<BtTaskProjection> _projectionFromRecord(
    StoredBtTaskRecord task,
  ) async {
    final StoredBtTaskMetadataRecord? metadata =
        await _store.metadataFor(task.id);
    final List<StoredBtTaskFileRecord> files = await _store.filesFor(task.id);
    final StoredBtTaskTransferSnapshotRecord? transfer =
        await _store.latestTransferSnapshot(task.id);
    final StoredBtTaskEventRecord? event = await _store.latestEvent(task.id);
    return BtTaskProjection(
      taskId: BtTaskId(task.id),
      sourceKind: task.sourceKind,
      sourceUri: task.sourceUri,
      lifecycleState: task.lifecycleState,
      createdAt: task.createdAt,
      updatedAt: task.updatedAt,
      infoHash: task.infoHash == null ? null : InfoHash(task.infoHash!),
      message: task.message,
      metadata: metadata == null ? null : _metadataProjection(metadata),
      files: <BtTaskFileProjection>[
        for (final StoredBtTaskFileRecord file in files) _fileProjection(file),
      ],
      latestTransferSnapshot:
          transfer == null ? null : _transferProjection(transfer),
      latestEvent: event == null ? null : _eventProjection(event),
      restart: _restartProjection(task, metadata),
    );
  }

  void _publish({
    required BtTaskCoreRuntimeStatus status,
    Iterable<BtTaskProjection>? tasks,
    Iterable<BtTaskCoreRuntimeFailure>? failures,
  }) {
    _snapshot = BtTaskCoreRuntimeSnapshot(
      status: status,
      capabilities: _capabilities,
      tasks: tasks ?? _snapshot.tasks,
      failures: failures ?? const <BtTaskCoreRuntimeFailure>[],
    );
    for (final BtTaskCoreRuntimeObserver observer
        in List<BtTaskCoreRuntimeObserver>.of(_observers)) {
      observer.onBtTaskCoreRuntimeSnapshot(_snapshot);
    }
  }

  BtTaskCoreRuntimeActionResult<T> _failureFromBtFailure<T>(
    BtTaskFailure failure,
  ) {
    return switch (failure.kind) {
      BtTaskFailureKind.capabilityUnsupported => _failedResult<T>(
          BtTaskCoreRuntimeFailureKind.capabilityUnsupported,
          failure.message,
        ),
      BtTaskFailureKind.taskNotFound => _failedResult<T>(
          BtTaskCoreRuntimeFailureKind.taskNotFound,
          failure.message,
        ),
      BtTaskFailureKind.adapterUnavailable =>
        _unavailableResult<T>(failure.message),
      BtTaskFailureKind.engineError => _failedResult<T>(
          BtTaskCoreRuntimeFailureKind.adapterFailure,
          failure.message,
        ),
    };
  }

  BtTaskCoreRuntimeActionResult<T> _taskNotFound<T>(BtTaskId taskId) {
    return _failedResult<T>(
      BtTaskCoreRuntimeFailureKind.taskNotFound,
      'BT task ${taskId.value} was not found.',
    );
  }

  BtTaskCoreRuntimeActionResult<T> _unavailableResult<T>(String message) {
    final BtTaskCoreRuntimeFailure failure = BtTaskCoreRuntimeFailure(
      kind: BtTaskCoreRuntimeFailureKind.unavailable,
      message: message,
    );
    _publish(
      status: BtTaskCoreRuntimeStatus.failed,
      failures: <BtTaskCoreRuntimeFailure>[failure],
    );
    return BtTaskCoreRuntimeActionResult<T>.unavailable(failure);
  }

  BtTaskCoreRuntimeActionResult<T> _failedResult<T>(
    BtTaskCoreRuntimeFailureKind kind,
    String message,
  ) {
    final BtTaskCoreRuntimeFailure failure =
        BtTaskCoreRuntimeFailure(kind: kind, message: message);
    _publish(
      status: BtTaskCoreRuntimeStatus.failed,
      failures: <BtTaskCoreRuntimeFailure>[failure],
    );
    return BtTaskCoreRuntimeActionResult<T>.failed(failure);
  }

  BtTaskCoreRuntimeActionResult<T> _disposedResult<T>() {
    return BtTaskCoreRuntimeActionResult<T>.disposed(
      const BtTaskCoreRuntimeFailure(
        kind: BtTaskCoreRuntimeFailureKind.disposed,
        message: 'BtTaskCoreRuntime has been disposed.',
      ),
    );
  }
}

BtTaskMetadataProjection _metadataProjection(
  StoredBtTaskMetadataRecord metadata,
) {
  return BtTaskMetadataProjection(
    taskId: BtTaskId(metadata.taskId),
    infoHash: InfoHash(metadata.infoHash),
    name: metadata.name,
    totalSizeBytes: metadata.totalSizeBytes,
    pieceLengthBytes: metadata.pieceLengthBytes,
  );
}

BtTaskFileProjection _fileProjection(StoredBtTaskFileRecord file) {
  return BtTaskFileProjection(
    taskId: BtTaskId(file.taskId),
    index: BtFileIndex(file.index),
    path: file.path,
    lengthBytes: file.lengthBytes,
    offsetBytes: file.offsetBytes,
    selectionState: _fileSelectionState(file.selectionState),
    mediaMimeType: file.mediaMimeType,
  );
}

BtTaskTransferSnapshotProjection _transferProjection(
  StoredBtTaskTransferSnapshotRecord snapshot,
) {
  return BtTaskTransferSnapshotProjection(
    taskId: BtTaskId(snapshot.taskId),
    lifecycleState: _lifecycleState(snapshot.lifecycleState),
    progress: snapshot.progress,
    downloadRateBytesPerSecond: snapshot.downloadRateBytesPerSecond,
    uploadRateBytesPerSecond: snapshot.uploadRateBytesPerSecond,
    connectedPeers: snapshot.connectedPeers,
    observedAt: snapshot.observedAt,
    message: snapshot.message,
  );
}

BtTaskEventProjection _eventProjection(StoredBtTaskEventRecord event) {
  return BtTaskEventProjection(
    taskId: BtTaskId(event.taskId),
    eventKind: event.eventKind,
    occurredAt: event.occurredAt,
    pieceIndex:
        event.pieceIndex == null ? null : BtPieceIndex(event.pieceIndex!),
    message: event.message,
  );
}

BtTaskRestartProjection _restartProjection(
  StoredBtTaskRecord task,
  StoredBtTaskMetadataRecord? metadata,
) {
  final BtRuntimeRestartDisposition disposition = switch (task.lifecycleState) {
    StoredBtTaskLifecycleState.queued ||
    StoredBtTaskLifecycleState.fetchingMetadata =>
      metadata == null
          ? BtRuntimeRestartDisposition.incomplete
          : BtRuntimeRestartDisposition.resumable,
    StoredBtTaskLifecycleState.ready ||
    StoredBtTaskLifecycleState.downloading =>
      BtRuntimeRestartDisposition.resumable,
    StoredBtTaskLifecycleState.paused => BtRuntimeRestartDisposition.paused,
    StoredBtTaskLifecycleState.completed =>
      BtRuntimeRestartDisposition.terminal,
    StoredBtTaskLifecycleState.failed => BtRuntimeRestartDisposition.failed,
    StoredBtTaskLifecycleState.removed => BtRuntimeRestartDisposition.removed,
  };
  return BtTaskRestartProjection(
    taskId: BtTaskId(task.id),
    disposition: disposition,
    requiresAdapterReconciliation:
        disposition == BtRuntimeRestartDisposition.resumable ||
            disposition == BtRuntimeRestartDisposition.paused ||
            disposition == BtRuntimeRestartDisposition.incomplete,
    reason: disposition == BtRuntimeRestartDisposition.incomplete
        ? 'Task metadata is not available after restart.'
        : null,
  );
}

BtFileSelectionState _fileSelectionState(StoredBtFileSelectionState state) {
  return switch (state) {
    StoredBtFileSelectionState.skipped => BtFileSelectionState.skipped,
    StoredBtFileSelectionState.selected => BtFileSelectionState.selected,
    StoredBtFileSelectionState.streamingTarget =>
      BtFileSelectionState.streamingTarget,
  };
}

BtTaskLifecycleState _lifecycleState(StoredBtTaskLifecycleState state) {
  return switch (state) {
    StoredBtTaskLifecycleState.queued => BtTaskLifecycleState.queued,
    StoredBtTaskLifecycleState.fetchingMetadata =>
      BtTaskLifecycleState.fetchingMetadata,
    StoredBtTaskLifecycleState.ready => BtTaskLifecycleState.ready,
    StoredBtTaskLifecycleState.downloading => BtTaskLifecycleState.downloading,
    StoredBtTaskLifecycleState.paused => BtTaskLifecycleState.paused,
    StoredBtTaskLifecycleState.completed => BtTaskLifecycleState.completed,
    StoredBtTaskLifecycleState.failed => BtTaskLifecycleState.failed,
    StoredBtTaskLifecycleState.removed => BtTaskLifecycleState.completed,
  };
}

final class _UnavailableBtTaskCore implements BtTaskCoreContract {
  const _UnavailableBtTaskCore(this.reason);

  final String reason;

  @override
  Future<BtTaskCreateOutcome> createTask(BtTaskCreateRequest request) {
    return Future<BtTaskCreateOutcome>.value(
      BtTaskCreateOutcome.failure(failure: _failure()),
    );
  }

  @override
  Future<BtTaskMetadataOutcome> ensureMetadata(BtTaskId taskId) {
    return Future<BtTaskMetadataOutcome>.value(
      BtTaskMetadataOutcome.failure(failure: _failure()),
    );
  }

  @override
  Future<BtTaskCommandOutcome> pause(BtTaskId taskId) => _commandFailure();

  @override
  Future<BtTaskCommandOutcome> remove(BtTaskId taskId) => _commandFailure();

  @override
  Future<BtTaskCommandOutcome> resume(BtTaskId taskId) => _commandFailure();

  @override
  Future<BtTaskCommandOutcome> selectFiles(
    BtTaskId taskId,
    Iterable<BtFileIndex> files,
  ) =>
      _commandFailure();

  @override
  Stream<BtTaskEvent> watchEvents(BtTaskId taskId) => const Stream.empty();

  @override
  Stream<BtTaskStatus> watchStatus(BtTaskId taskId) => const Stream.empty();

  Future<BtTaskCommandOutcome> _commandFailure() {
    return Future<BtTaskCommandOutcome>.value(
      BtTaskCommandOutcome.failure(failure: _failure()),
    );
  }

  BtTaskFailure _failure() {
    return BtTaskFailure(
      kind: BtTaskFailureKind.adapterUnavailable,
      message: reason,
    );
  }
}
