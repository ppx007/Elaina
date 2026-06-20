import '../../streaming/bt_task_core.dart';
import '../../streaming/bt_task_core_runtime.dart';

abstract interface class DownloadRuntimeObserver {
  void onDownloadRuntimeSnapshot(DownloadRuntimeSnapshot snapshot);
}

final class DownloadRuntimeSnapshot {
  DownloadRuntimeSnapshot({
    required this.status,
    required this.tasks,
  });

  final DownloadRuntimeStatus status;
  final List<DownloadProjection> tasks;
}

enum DownloadRuntimeStatus {
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

DownloadRuntimeStatus _mapStatus(BtTaskCoreRuntimeStatus status) {
  return switch (status) {
    BtTaskCoreRuntimeStatus.idle => DownloadRuntimeStatus.idle,
    BtTaskCoreRuntimeStatus.creating => DownloadRuntimeStatus.creating,
    BtTaskCoreRuntimeStatus.fetchingMetadata =>
      DownloadRuntimeStatus.fetchingMetadata,
    BtTaskCoreRuntimeStatus.selectingFiles =>
      DownloadRuntimeStatus.selectingFiles,
    BtTaskCoreRuntimeStatus.commanding => DownloadRuntimeStatus.commanding,
    BtTaskCoreRuntimeStatus.observing => DownloadRuntimeStatus.observing,
    BtTaskCoreRuntimeStatus.projecting => DownloadRuntimeStatus.projecting,
    BtTaskCoreRuntimeStatus.ready => DownloadRuntimeStatus.ready,
    BtTaskCoreRuntimeStatus.failed => DownloadRuntimeStatus.failed,
    BtTaskCoreRuntimeStatus.disposed => DownloadRuntimeStatus.disposed,
  };
}

final class DownloadProjection {
  const DownloadProjection({
    required this.taskId,
    required this.sourceUri,
    required this.state,
    required this.name,
    required this.progress,
    required this.downloadRateBytesPerSecond,
    required this.connectedPeers,
    required this.totalSizeBytes,
  });

  final DownloadTaskId taskId;
  final String sourceUri;
  final DownloadLifecycleState state;
  final String name;
  final double progress;
  final int downloadRateBytesPerSecond;
  final int connectedPeers;
  final int totalSizeBytes;
}

final class DownloadCreateResult {
  const DownloadCreateResult._({
    this.task,
    this.failureMessage,
    this.warningMessage,
  });

  const DownloadCreateResult.success(DownloadProjection task)
      : this._(task: task);

  const DownloadCreateResult.partial({
    required DownloadProjection task,
    required String warningMessage,
  }) : this._(task: task, warningMessage: warningMessage);

  const DownloadCreateResult.failure(String message)
      : this._(failureMessage: message);

  final DownloadProjection? task;
  final String? failureMessage;
  final String? warningMessage;

  bool get isSuccess => task != null && failureMessage == null;
  bool get hasWarning => warningMessage != null;
}

final class DownloadTaskId {
  const DownloadTaskId(this.value);
  final String value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DownloadTaskId &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;
}

enum DownloadLifecycleState {
  queued,
  fetchingMetadata,
  ready,
  downloading,
  paused,
  completed,
  failed,
}

DownloadLifecycleState _mapLifecycleState(BtTaskLifecycleState state) {
  return switch (state) {
    BtTaskLifecycleState.queued => DownloadLifecycleState.queued,
    BtTaskLifecycleState.fetchingMetadata =>
      DownloadLifecycleState.fetchingMetadata,
    BtTaskLifecycleState.ready => DownloadLifecycleState.ready,
    BtTaskLifecycleState.downloading => DownloadLifecycleState.downloading,
    BtTaskLifecycleState.paused => DownloadLifecycleState.paused,
    BtTaskLifecycleState.completed => DownloadLifecycleState.completed,
    BtTaskLifecycleState.failed => DownloadLifecycleState.failed,
  };
}

abstract interface class DownloadRuntime {
  DownloadRuntimeSnapshot get currentSnapshot;
  void addObserver(DownloadRuntimeObserver observer);
  void removeObserver(DownloadRuntimeObserver observer);
  Future<DownloadCreateResult> createTaskFromUri(String sourceUri);
  Future<void> listTasks();
  Future<void> pause(DownloadTaskId taskId);
  Future<void> resume(DownloadTaskId taskId);
  Future<void> remove(DownloadTaskId taskId);
  void dispose();
}

final class DownloadRuntimeAdapter
    implements DownloadRuntime, BtTaskCoreRuntimeObserver {
  DownloadRuntimeAdapter(this._runtime) {
    _runtime.addObserver(this);
  }

  final BtTaskCoreRuntime _runtime;
  final List<DownloadRuntimeObserver> _observers = <DownloadRuntimeObserver>[];

  @override
  void dispose() {
    _runtime.removeObserver(this);
    _observers.clear();
  }

  @override
  DownloadRuntimeSnapshot get currentSnapshot =>
      _wrapSnapshot(_runtime.currentSnapshot);

  @override
  void addObserver(DownloadRuntimeObserver observer) {
    if (!_observers.contains(observer)) {
      _observers.add(observer);
    }
  }

  @override
  void removeObserver(DownloadRuntimeObserver observer) {
    _observers.remove(observer);
  }

  @override
  void onBtTaskCoreRuntimeSnapshot(BtTaskCoreRuntimeSnapshot snapshot) {
    final wrapped = _wrapSnapshot(snapshot);
    for (final observer in List<DownloadRuntimeObserver>.of(_observers)) {
      observer.onDownloadRuntimeSnapshot(wrapped);
    }
  }

  @override
  Future<DownloadCreateResult> createTaskFromUri(String sourceUri) async {
    final String trimmed = sourceUri.trim();
    if (trimmed.isEmpty) {
      return const DownloadCreateResult.failure(
          'Download source URI is empty.');
    }

    final BtTaskSource source;
    if (trimmed.startsWith('magnet:?')) {
      source = MagnetBtTaskSource(uri: trimmed);
    } else {
      final Uri? parsed = Uri.tryParse(trimmed);
      if (parsed == null ||
          !(parsed.isScheme('file') ||
              parsed.isScheme('http') ||
              parsed.isScheme('https'))) {
        return const DownloadCreateResult.failure(
          'Download source must be a magnet link, torrent file URI, or HTTP(S) torrent URL.',
        );
      }
      source = TorrentDataBtTaskSource(uri: parsed);
    }

    final BtTaskCoreRuntimeActionResult<BtTaskProjection> created =
        await _runtime.createTask(BtTaskCreateRequest(source: source));
    if (!created.isSuccess || created.value == null) {
      return DownloadCreateResult.failure(
        created.failure?.message ?? 'Download task creation failed.',
      );
    }

    BtTaskProjection projection = created.value!;
    final BtTaskCoreRuntimeActionResult<BtTaskProjection> metadata =
        await _runtime.ensureMetadata(projection.taskId);
    if (!metadata.isSuccess || metadata.value == null) {
      await _runtime.listTasks();
      return DownloadCreateResult.partial(
        task: _wrapProjection(projection),
        warningMessage:
            metadata.failure?.message ?? 'Download metadata is not available.',
      );
    }

    projection = metadata.value!;
    if (projection.files.isNotEmpty) {
      final Iterable<BtFileIndex> allFiles =
          projection.files.map((BtTaskFileProjection file) => file.index);
      final BtTaskCoreRuntimeActionResult<BtTaskProjection> selected =
          await _runtime.selectFiles(projection.taskId, allFiles);
      if (!selected.isSuccess || selected.value == null) {
        await _runtime.listTasks();
        return DownloadCreateResult.partial(
          task: _wrapProjection(projection),
          warningMessage:
              selected.failure?.message ?? 'Download file selection failed.',
        );
      }
      projection = selected.value!;
    }

    await _runtime.listTasks();
    return DownloadCreateResult.success(_wrapProjection(projection));
  }

  @override
  Future<void> listTasks() async {
    await _runtime.listTasks();
  }

  @override
  Future<void> pause(DownloadTaskId taskId) async {
    await _runtime.pause(BtTaskId(taskId.value));
  }

  @override
  Future<void> resume(DownloadTaskId taskId) async {
    await _runtime.resume(BtTaskId(taskId.value));
  }

  @override
  Future<void> remove(DownloadTaskId taskId) async {
    await _runtime.remove(BtTaskId(taskId.value));
  }

  DownloadRuntimeSnapshot _wrapSnapshot(BtTaskCoreRuntimeSnapshot snapshot) {
    return DownloadRuntimeSnapshot(
      status: _mapStatus(snapshot.status),
      tasks: <DownloadProjection>[
        for (final task in snapshot.tasks) _wrapProjection(task),
      ],
    );
  }

  DownloadProjection _wrapProjection(BtTaskProjection task) {
    return DownloadProjection(
      taskId: DownloadTaskId(task.taskId.value),
      sourceUri: task.sourceUri,
      state: _mapLifecycleState(task.state),
      name: task.metadata?.name ?? task.sourceUri,
      progress: task.latestTransferSnapshot?.progress ?? 0.0,
      downloadRateBytesPerSecond:
          task.latestTransferSnapshot?.downloadRateBytesPerSecond ?? 0,
      connectedPeers: task.latestTransferSnapshot?.connectedPeers ?? 0,
      totalSizeBytes: task.metadata?.totalSizeBytes ?? 0,
    );
  }
}
