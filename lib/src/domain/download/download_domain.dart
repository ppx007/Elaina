import '../../foundation/storage/storage_contracts.dart';
import '../../playback/player_adapter.dart';
import '../../playback/virtual_stream_playback_source.dart';
import '../../streaming/bt_task_core.dart';
import '../../streaming/bt_task_core_runtime.dart';
import '../../streaming/virtual_media_stream.dart';
import '../../streaming/virtual_media_stream_runtime.dart';

// UI-facing download contract.
//
// DownloadRuntime deliberately hides BT adapter/source details behind stable
// projections so the downloads page can evolve without depending on libtorrent
// records or core runtime persistence details.
abstract interface class DownloadRuntimeObserver {
  void onDownloadRuntimeSnapshot(DownloadRuntimeSnapshot snapshot);
}

final class DownloadRuntimeSnapshot {
  DownloadRuntimeSnapshot({
    required this.status,
    required this.tasks,
    this.capabilities = DownloadCapabilityProjection.unsupported,
  });

  final DownloadRuntimeStatus status;
  final List<DownloadProjection> tasks;
  final DownloadCapabilityProjection capabilities;
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

enum DownloadTaskSourceKind {
  magnet,
  torrentFile,
  unknown,
}

enum DownloadCreateMode {
  quick,
  advanced,
}

enum DownloadFileSelectionState {
  skipped,
  selected,
  streamingTarget,
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

final class DownloadCapabilityProjection {
  const DownloadCapabilityProjection({
    required this.taskManagementAvailable,
    required this.metadataFetchingAvailable,
    required this.backgroundDownloadAvailable,
    required this.virtualStreamAvailable,
    this.taskManagementReason,
    this.metadataFetchingReason,
    this.backgroundDownloadReason,
    this.virtualStreamReason,
  });

  static const DownloadCapabilityProjection unsupported =
      DownloadCapabilityProjection(
    taskManagementAvailable: false,
    metadataFetchingAvailable: false,
    backgroundDownloadAvailable: false,
    virtualStreamAvailable: false,
  );

  final bool taskManagementAvailable;
  final bool metadataFetchingAvailable;
  final bool backgroundDownloadAvailable;
  final bool virtualStreamAvailable;
  final String? taskManagementReason;
  final String? metadataFetchingReason;
  final String? backgroundDownloadReason;
  final String? virtualStreamReason;

  bool get canCreateTasks => taskManagementAvailable;
}

final class DownloadFileIndex {
  const DownloadFileIndex(this.value)
      : assert(value >= 0, 'Download file index must not be negative.');

  final int value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DownloadFileIndex &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;
}

final class DownloadFileProjection {
  const DownloadFileProjection({
    required this.index,
    required this.name,
    required this.path,
    required this.sizeBytes,
    required this.selectionState,
    this.streamable = false,
    this.playbackAvailableReason,
    this.mediaMimeType,
  });

  final DownloadFileIndex index;
  final String name;
  final String path;
  final int sizeBytes;
  final DownloadFileSelectionState selectionState;
  final bool streamable;
  final String? playbackAvailableReason;
  final String? mediaMimeType;

  bool get isSelected =>
      selectionState == DownloadFileSelectionState.selected ||
      selectionState == DownloadFileSelectionState.streamingTarget;
}

enum DownloadPlaybackPrepareFailureKind {
  capabilityUnsupported,
  taskNotFound,
  fileNotFound,
  fileNotSelected,
  fileNotStreamable,
  streamFailed,
}

final class DownloadPlaybackPrepareResult {
  const DownloadPlaybackPrepareResult._({
    this.source,
    this.failureKind,
    this.failureMessage,
  });

  const DownloadPlaybackPrepareResult.success(PlaybackSource source)
      : this._(source: source);

  const DownloadPlaybackPrepareResult.failure({
    required DownloadPlaybackPrepareFailureKind kind,
    required String message,
  }) : this._(failureKind: kind, failureMessage: message);

  final PlaybackSource? source;
  final DownloadPlaybackPrepareFailureKind? failureKind;
  final String? failureMessage;

  bool get isSuccess => source != null;
}

abstract interface class DownloadTorrentUrlResolver {
  Future<DownloadTorrentUrlResolution> resolveTorrentUrl(Uri torrentUri);
}

final class DownloadTorrentUrlResolution {
  const DownloadTorrentUrlResolution._({this.fileUri, this.failureMessage});

  const DownloadTorrentUrlResolution.success(Uri fileUri)
      : this._(fileUri: fileUri);

  const DownloadTorrentUrlResolution.failure(String message)
      : this._(failureMessage: message);

  final Uri? fileUri;
  final String? failureMessage;

  bool get isSuccess => fileUri != null;
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
    this.sourceKind = DownloadTaskSourceKind.unknown,
    this.uploadRateBytesPerSecond = 0,
    this.message,
    this.latestEvent,
    this.createdAt,
    this.updatedAt,
    this.infoHash,
    this.pieceLengthBytes,
    this.files = const <DownloadFileProjection>[],
  });

  final DownloadTaskId taskId;
  final String sourceUri;
  final DownloadTaskSourceKind sourceKind;
  final DownloadLifecycleState state;
  final String name;
  final double progress;
  final int downloadRateBytesPerSecond;
  final int uploadRateBytesPerSecond;
  final int connectedPeers;
  final int totalSizeBytes;
  final String? message;
  final String? latestEvent;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? infoHash;
  final int? pieceLengthBytes;
  final List<DownloadFileProjection> files;

  int get selectedFileCount =>
      files.where((DownloadFileProjection file) => file.isSelected).length;
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

final class DownloadCommandResult {
  const DownloadCommandResult._({
    required this.isSuccess,
    this.task,
    this.failureMessage,
  });

  const DownloadCommandResult.success([DownloadProjection? task])
      : this._(isSuccess: true, task: task);

  const DownloadCommandResult.failure(String message)
      : this._(isSuccess: false, failureMessage: message);

  final bool isSuccess;
  final DownloadProjection? task;
  final String? failureMessage;
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
  Future<DownloadCreateResult> createTaskFromUri(
    String sourceUri, {
    DownloadCreateMode mode,
  });
  Future<DownloadCommandResult> selectFiles(
    DownloadTaskId taskId,
    Iterable<DownloadFileIndex> files,
  );
  Future<void> listTasks();
  Future<DownloadCommandResult> pause(DownloadTaskId taskId);
  Future<DownloadCommandResult> resume(DownloadTaskId taskId);
  Future<DownloadCommandResult> remove(DownloadTaskId taskId);
  Future<DownloadCommandResult> pauseAll();
  Future<DownloadCommandResult> resumeAll();
  Future<DownloadPlaybackPrepareResult> preparePlayback(
    DownloadTaskId taskId,
    DownloadFileIndex fileIndex,
  );
  void dispose();
}

final class DownloadRuntimeAdapter
    implements DownloadRuntime, BtTaskCoreRuntimeObserver {
  DownloadRuntimeAdapter(
    this._runtime, {
    VirtualMediaStreamRuntime? virtualStreamRuntime,
    DownloadTorrentUrlResolver? torrentUrlResolver,
    DownloadCapabilityProjection? capabilityOverride,
  })  : _virtualStreamRuntime = virtualStreamRuntime,
        _torrentUrlResolver = torrentUrlResolver,
        _capabilityOverride = capabilityOverride {
    _runtime.addObserver(this);
  }

  final BtTaskCoreRuntime _runtime;
  final VirtualMediaStreamRuntime? _virtualStreamRuntime;
  final DownloadTorrentUrlResolver? _torrentUrlResolver;
  final DownloadCapabilityProjection? _capabilityOverride;
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
  Future<DownloadCreateResult> createTaskFromUri(
    String sourceUri, {
    DownloadCreateMode mode = DownloadCreateMode.quick,
  }) async {
    final String trimmed = sourceUri.trim();
    if (trimmed.isEmpty) {
      return const DownloadCreateResult.failure(
        '下载来源不能为空。',
      );
    }

    final BtTaskSource? source;
    try {
      source = await _sourceFromUri(trimmed);
    } on StateError catch (error) {
      return DownloadCreateResult.failure(error.message);
    } on Object catch (error) {
      return DownloadCreateResult.failure(error.toString());
    }
    if (source == null) {
      return const DownloadCreateResult.failure(
        '仅支持 magnet 链接或本地 .torrent 文件 URI。',
      );
    }

    final BtTaskCoreRuntimeActionResult<BtTaskProjection> created =
        await _runtime.createTask(BtTaskCreateRequest(source: source));
    if (!created.isSuccess || created.value == null) {
      return DownloadCreateResult.failure(
        created.failure?.message ?? '下载任务创建失败。',
      );
    }

    BtTaskProjection projection = created.value!;
    if (mode == DownloadCreateMode.advanced) {
      final DownloadCreateResult? pauseResult =
          await _pauseCreatedTask(projection);
      if (pauseResult != null) return pauseResult;
    }

    final BtTaskCoreRuntimeActionResult<BtTaskProjection> metadata =
        await _runtime.ensureMetadata(projection.taskId);
    if (!metadata.isSuccess || metadata.value == null) {
      await _runtime.listTasks();
      return DownloadCreateResult.partial(
        task: _wrapProjection(projection),
        warningMessage: metadata.failure?.message ?? '下载元数据暂不可用。',
      );
    }

    projection = metadata.value!;
    if (mode == DownloadCreateMode.quick && projection.files.isNotEmpty) {
      final Iterable<BtFileIndex> allFiles =
          projection.files.map((BtTaskFileProjection file) => file.index);
      final BtTaskCoreRuntimeActionResult<BtTaskProjection> selected =
          await _runtime.selectFiles(projection.taskId, allFiles);
      if (!selected.isSuccess || selected.value == null) {
        await _runtime.listTasks();
        return DownloadCreateResult.partial(
          task: _wrapProjection(projection),
          warningMessage: selected.failure?.message ?? '下载文件选择失败。',
        );
      }
      projection = selected.value!;
    }

    await _runtime.listTasks();
    return DownloadCreateResult.success(_wrapProjection(projection));
  }

  Future<DownloadCreateResult?> _pauseCreatedTask(
    BtTaskProjection projection,
  ) async {
    final BtTaskCoreRuntimeActionResult<BtTaskProjection> paused =
        await _runtime.pause(projection.taskId);
    if (paused.isSuccess && paused.value != null) return null;
    await _runtime.listTasks();
    return DownloadCreateResult.partial(
      task: _wrapProjection(projection),
      warningMessage: paused.failure?.message ?? '高级添加任务已创建，但暂停失败。',
    );
  }

  @override
  Future<DownloadCommandResult> selectFiles(
    DownloadTaskId taskId,
    Iterable<DownloadFileIndex> files,
  ) async {
    final List<DownloadFileIndex> selectedFiles =
        List<DownloadFileIndex>.unmodifiable(files);
    if (selectedFiles.isEmpty) {
      return const DownloadCommandResult.failure('至少选择一个文件。');
    }
    final BtTaskCoreRuntimeActionResult<BtTaskProjection> selected =
        await _runtime.selectFiles(
      BtTaskId(taskId.value),
      selectedFiles.map((DownloadFileIndex file) => BtFileIndex(file.value)),
    );
    return _commandResult(selected, fallbackMessage: '下载文件选择失败。');
  }

  @override
  Future<void> listTasks() async {
    await _runtime.listTasks();
  }

  @override
  Future<DownloadCommandResult> pause(DownloadTaskId taskId) async {
    final BtTaskCoreRuntimeActionResult<BtTaskProjection> paused =
        await _runtime.pause(BtTaskId(taskId.value));
    return _commandResult(paused, fallbackMessage: '暂停下载任务失败。');
  }

  @override
  Future<DownloadCommandResult> resume(DownloadTaskId taskId) async {
    final BtTaskCoreRuntimeActionResult<BtTaskProjection> resumed =
        await _runtime.resume(BtTaskId(taskId.value));
    return _commandResult(resumed, fallbackMessage: '恢复下载任务失败。');
  }

  @override
  Future<DownloadCommandResult> remove(DownloadTaskId taskId) async {
    final BtTaskCoreRuntimeActionResult<BtTaskProjection> removed =
        await _runtime.remove(BtTaskId(taskId.value));
    return _commandResult(removed, fallbackMessage: '删除下载任务失败。');
  }

  @override
  Future<DownloadCommandResult> pauseAll() async {
    return _runBatchCommand(
      currentSnapshot.tasks.where(_canPause),
      pause,
    );
  }

  @override
  Future<DownloadCommandResult> resumeAll() async {
    return _runBatchCommand(
      currentSnapshot.tasks.where(_canResume),
      resume,
    );
  }

  Future<DownloadCommandResult> _runBatchCommand(
    Iterable<DownloadProjection> tasks,
    Future<DownloadCommandResult> Function(DownloadTaskId taskId) command,
  ) async {
    final List<DownloadProjection> actionable =
        List<DownloadProjection>.unmodifiable(tasks);
    if (actionable.isEmpty) {
      await _runtime.listTasks();
      return DownloadCommandResult.success();
    }
    for (final DownloadProjection task in actionable) {
      final DownloadCommandResult result = await command(task.taskId);
      if (!result.isSuccess) return result;
    }
    await _runtime.listTasks();
    return DownloadCommandResult.success();
  }

  Future<BtTaskSource?> _sourceFromUri(String sourceUri) async {
    if (sourceUri.startsWith('magnet:?')) {
      return MagnetBtTaskSource(uri: sourceUri);
    }
    final Uri? parsed = Uri.tryParse(sourceUri);
    if (parsed == null) return null;
    if (parsed.isScheme('file')) {
      return TorrentDataBtTaskSource(uri: parsed);
    }
    if (parsed.isScheme('http') || parsed.isScheme('https')) {
      final DownloadTorrentUrlResolver? resolver = _torrentUrlResolver;
      if (resolver == null) return null;
      final DownloadTorrentUrlResolution resolved =
          await resolver.resolveTorrentUrl(parsed);
      if (!resolved.isSuccess || resolved.fileUri == null) {
        throw StateError(
          resolved.failureMessage ?? '远程 torrent 文件解析失败。',
        );
      }
      return TorrentDataBtTaskSource(uri: resolved.fileUri!);
    }
    return null;
  }

  @override
  Future<DownloadPlaybackPrepareResult> preparePlayback(
    DownloadTaskId taskId,
    DownloadFileIndex fileIndex,
  ) async {
    final DownloadCapabilityProjection capabilities =
        currentSnapshot.capabilities;
    if (!capabilities.virtualStreamAvailable) {
      return DownloadPlaybackPrepareResult.failure(
        kind: DownloadPlaybackPrepareFailureKind.capabilityUnsupported,
        message: capabilities.virtualStreamReason ?? '虚拟流播放能力不可用。',
      );
    }
    final VirtualMediaStreamRuntime? streamRuntime = _virtualStreamRuntime;
    if (streamRuntime == null) {
      return const DownloadPlaybackPrepareResult.failure(
        kind: DownloadPlaybackPrepareFailureKind.capabilityUnsupported,
        message: '虚拟流运行时未配置。',
      );
    }

    await _runtime.taskById(BtTaskId(taskId.value));
    final DownloadProjection? task = _taskById(taskId);
    if (task == null) {
      return const DownloadPlaybackPrepareResult.failure(
        kind: DownloadPlaybackPrepareFailureKind.taskNotFound,
        message: '下载任务不存在。',
      );
    }
    DownloadFileProjection? file;
    for (final DownloadFileProjection candidate in task.files) {
      if (candidate.index == fileIndex) {
        file = candidate;
        break;
      }
    }
    if (file == null) {
      return const DownloadPlaybackPrepareResult.failure(
        kind: DownloadPlaybackPrepareFailureKind.fileNotFound,
        message: '下载文件不存在。',
      );
    }
    if (!file.isSelected) {
      return const DownloadPlaybackPrepareResult.failure(
        kind: DownloadPlaybackPrepareFailureKind.fileNotSelected,
        message: '请先选择该文件。',
      );
    }
    if (!file.streamable) {
      return DownloadPlaybackPrepareResult.failure(
        kind: DownloadPlaybackPrepareFailureKind.fileNotStreamable,
        message: file.playbackAvailableReason ?? '该文件不可边下边播。',
      );
    }

    final VirtualMediaStreamRuntimeActionResult<VirtualMediaStreamSnapshot>
        result = await streamRuntime.createStream(
      VirtualMediaStreamCreateRequest(
        taskId: BtTaskId(taskId.value),
        fileIndex: BtFileIndex(fileIndex.value),
      ),
    );
    if (!result.isSuccess || result.value == null) {
      return DownloadPlaybackPrepareResult.failure(
        kind: DownloadPlaybackPrepareFailureKind.streamFailed,
        message: result.failure?.message ?? '虚拟流创建失败。',
      );
    }
    final VirtualMediaStreamDescriptor descriptor = result.value!.descriptor;
    return DownloadPlaybackPrepareResult.success(
      VirtualStreamPlaybackSource.fromValues(
        streamId: descriptor.id.value,
        contentUri: descriptor.contentUri,
      ),
    );
  }

  DownloadProjection? _taskById(DownloadTaskId taskId) {
    for (final DownloadProjection task in currentSnapshot.tasks) {
      if (task.taskId == taskId) return task;
    }
    return null;
  }

  DownloadCommandResult _commandResult(
    BtTaskCoreRuntimeActionResult<BtTaskProjection> result, {
    required String fallbackMessage,
  }) {
    if (!result.isSuccess || result.value == null) {
      return DownloadCommandResult.failure(
        result.failure?.message ?? fallbackMessage,
      );
    }
    return DownloadCommandResult.success(_wrapProjection(result.value!));
  }

  DownloadRuntimeSnapshot _wrapSnapshot(BtTaskCoreRuntimeSnapshot snapshot) {
    return DownloadRuntimeSnapshot(
      status: _mapStatus(snapshot.status),
      capabilities: _capabilityOverride ?? _wrapCapabilities(snapshot.capabilities),
      tasks: <DownloadProjection>[
        for (final task in snapshot.tasks) _wrapProjection(task),
      ],
    );
  }

  DownloadProjection _wrapProjection(BtTaskProjection task) {
    return DownloadProjection(
      taskId: DownloadTaskId(task.taskId.value),
      sourceUri: task.sourceUri,
      sourceKind: _mapSourceKind(task.sourceKind),
      state: _mapLifecycleState(task.state),
      name: task.metadata?.name ?? task.sourceUri,
      progress: task.latestTransferSnapshot?.progress ?? 0.0,
      downloadRateBytesPerSecond:
          task.latestTransferSnapshot?.downloadRateBytesPerSecond ?? 0,
      uploadRateBytesPerSecond:
          task.latestTransferSnapshot?.uploadRateBytesPerSecond ?? 0,
      connectedPeers: task.latestTransferSnapshot?.connectedPeers ?? 0,
      totalSizeBytes: task.metadata?.totalSizeBytes ?? 0,
      message: task.message ?? task.latestTransferSnapshot?.message,
      latestEvent: _eventMessage(task.latestEvent),
      createdAt: task.createdAt,
      updatedAt: task.updatedAt,
      infoHash: task.infoHash?.value ?? task.metadata?.infoHash?.value,
      pieceLengthBytes: task.metadata?.pieceLengthBytes,
      files: <DownloadFileProjection>[
        for (final BtTaskFileProjection file in task.files)
          DownloadFileProjection(
            index: DownloadFileIndex(file.index.value),
            name: _fileName(file.path),
            path: file.path,
            sizeBytes: file.lengthBytes,
            selectionState: _mapFileSelectionState(file.selectionState),
            streamable: _isStreamableFile(file),
            playbackAvailableReason: _playbackAvailabilityReason(file),
            mediaMimeType: file.mediaMimeType,
          ),
      ],
    );
  }
}

bool _canPause(DownloadProjection task) {
  return switch (task.state) {
    DownloadLifecycleState.queued ||
    DownloadLifecycleState.fetchingMetadata ||
    DownloadLifecycleState.ready ||
    DownloadLifecycleState.downloading =>
      true,
    DownloadLifecycleState.paused ||
    DownloadLifecycleState.completed ||
    DownloadLifecycleState.failed =>
      false,
  };
}

bool _canResume(DownloadProjection task) {
  return switch (task.state) {
    DownloadLifecycleState.queued ||
    DownloadLifecycleState.ready ||
    DownloadLifecycleState.paused =>
      true,
    DownloadLifecycleState.fetchingMetadata ||
    DownloadLifecycleState.downloading ||
    DownloadLifecycleState.completed ||
    DownloadLifecycleState.failed =>
      false,
  };
}

bool _isStreamableFile(BtTaskFileProjection file) {
  return file.isStreamable && file.lengthBytes > 0;
}

String? _playbackAvailabilityReason(BtTaskFileProjection file) {
  if (file.lengthBytes <= 0) return '文件大小无效，无法播放。';
  if (!file.isStreamable) return '底层下载引擎未声明该文件可流式播放。';
  return null;
}

DownloadCapabilityProjection _wrapCapabilities(BtCapabilityMatrix matrix) {
  final BtCapabilityStatus taskManagement =
      matrix.statusOf(BtStreamingCapability.taskManagement);
  final BtCapabilityStatus metadataFetching =
      matrix.statusOf(BtStreamingCapability.metadataFetching);
  final BtCapabilityStatus backgroundDownload =
      matrix.statusOf(BtStreamingCapability.longBackgroundDownload);
  final BtCapabilityStatus virtualStream =
      matrix.statusOf(BtStreamingCapability.virtualMediaStream);
  return DownloadCapabilityProjection(
    taskManagementAvailable: taskManagement.supported,
    metadataFetchingAvailable: metadataFetching.supported,
    backgroundDownloadAvailable: backgroundDownload.supported,
    virtualStreamAvailable: virtualStream.supported,
    taskManagementReason: taskManagement.reason,
    metadataFetchingReason: metadataFetching.reason,
    backgroundDownloadReason: backgroundDownload.reason,
    virtualStreamReason: virtualStream.reason,
  );
}

DownloadTaskSourceKind _mapSourceKind(StoredBtTaskSourceKind sourceKind) {
  return switch (sourceKind) {
    StoredBtTaskSourceKind.magnet => DownloadTaskSourceKind.magnet,
    StoredBtTaskSourceKind.torrentData => DownloadTaskSourceKind.torrentFile,
  };
}

DownloadFileSelectionState _mapFileSelectionState(BtFileSelectionState state) {
  return switch (state) {
    BtFileSelectionState.skipped => DownloadFileSelectionState.skipped,
    BtFileSelectionState.selected => DownloadFileSelectionState.selected,
    BtFileSelectionState.streamingTarget =>
      DownloadFileSelectionState.streamingTarget,
  };
}

String _fileName(String path) {
  final int slash = path.lastIndexOf('/');
  final int backslash = path.lastIndexOf('\\');
  final int separator = slash > backslash ? slash : backslash;
  if (separator < 0 || separator + 1 >= path.length) return path;
  return path.substring(separator + 1);
}

String? _eventMessage(BtTaskEventProjection? event) {
  if (event == null) return null;
  if (event.message != null && event.message!.isNotEmpty) {
    return event.message;
  }
  return switch (event.eventKind) {
    StoredBtTaskEventKind.created => '任务已创建',
    StoredBtTaskEventKind.metadataUpdated => '元数据已更新',
    StoredBtTaskEventKind.fileSelectionChanged => '文件选择已更新',
    StoredBtTaskEventKind.lifecycleChanged => '任务状态已更新',
    StoredBtTaskEventKind.pieceCompleted => '分片已完成',
    StoredBtTaskEventKind.failed => '任务失败',
    StoredBtTaskEventKind.removed => '任务已删除',
  };
}
