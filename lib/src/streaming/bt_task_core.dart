import '../foundation/cache_invalidation/cache_invalidation_bus.dart';
import '../foundation/extension_points.dart';
import '../foundation/storage/storage_contracts.dart';

// Domain contract for BT task control.
//
// This file models tasks, metadata, files, events, and adapter capabilities.
// UI-facing download pages should consume DownloadRuntime/BtTaskCoreRuntime
// projections instead of depending on these adapter-level shapes directly.
final class BtTaskId {
  const BtTaskId(this.value)
      : assert(value != '', 'BT task id must not be empty.');

  final String value;
}

final class InfoHash {
  const InfoHash(this.value)
      : assert(value != '', 'Info hash must not be empty.');

  final String value;
}

sealed class BtTaskSource {
  const BtTaskSource();
}

final class MagnetBtTaskSource extends BtTaskSource {
  const MagnetBtTaskSource({required this.uri})
      : assert(uri != '', 'Magnet URI must not be empty.');

  final String uri;
}

final class TorrentDataBtTaskSource extends BtTaskSource {
  const TorrentDataBtTaskSource({required this.uri});

  final Uri uri;
}

final class BtFileIndex {
  const BtFileIndex(this.value)
      : assert(value >= 0, 'BT file index must not be negative.');

  final int value;
}

final class BtPieceIndex {
  const BtPieceIndex(this.value)
      : assert(value >= 0, 'BT piece index must not be negative.');

  final int value;
}

final class BtByteRange {
  const BtByteRange({required this.start, required this.endInclusive})
      : assert(start >= 0, 'Range start must not be negative.'),
        assert(endInclusive >= start,
            'Range end must be greater than or equal to start.');

  final int start;
  final int endInclusive;

  int get length => endInclusive - start + 1;
}

enum BtTaskLifecycleState {
  queued,
  fetchingMetadata,
  ready,
  downloading,
  paused,
  completed,
  failed,
}

enum BtFileSelectionState {
  skipped,
  selected,
  streamingTarget,
}

final class BtTaskFile {
  const BtTaskFile({
    required this.index,
    required this.path,
    required this.lengthBytes,
    required this.offsetBytes,
    required this.selectionState,
    this.isStreamable = false,
    this.mediaMimeType,
  })  : assert(path != '', 'BT file path must not be empty.'),
        assert(lengthBytes >= 0, 'lengthBytes must not be negative.'),
        assert(offsetBytes >= 0, 'offsetBytes must not be negative.');

  final BtFileIndex index;
  final String path;
  final int lengthBytes;
  final int offsetBytes;
  final BtFileSelectionState selectionState;
  final bool isStreamable;
  final String? mediaMimeType;
}

final class BtTaskMetadata {
  const BtTaskMetadata({
    this.infoHash,
    required this.name,
    required this.totalSizeBytes,
    this.pieceLengthBytes,
    required this.files,
  })  : assert(name != '', 'BT metadata name must not be empty.'),
        assert(totalSizeBytes >= 0, 'totalSizeBytes must not be negative.'),
        assert(pieceLengthBytes == null || pieceLengthBytes > 0,
            'pieceLengthBytes must be positive when provided.');

  final InfoHash? infoHash;
  final String name;
  final int totalSizeBytes;
  final int? pieceLengthBytes;
  final List<BtTaskFile> files;
}

final class BtTaskStatus {
  const BtTaskStatus({
    required this.taskId,
    required this.state,
    required this.progress,
    required this.downloadRateBytesPerSecond,
    required this.uploadRateBytesPerSecond,
    required this.connectedPeers,
    this.metadata,
    this.message,
  })  : assert(progress >= 0 && progress <= 1,
            'progress must be between 0 and 1.'),
        assert(downloadRateBytesPerSecond >= 0,
            'download rate must not be negative.'),
        assert(
            uploadRateBytesPerSecond >= 0, 'upload rate must not be negative.'),
        assert(connectedPeers >= 0, 'connectedPeers must not be negative.');

  final BtTaskId taskId;
  final BtTaskLifecycleState state;
  final double progress;
  final int downloadRateBytesPerSecond;
  final int uploadRateBytesPerSecond;
  final int connectedPeers;
  final BtTaskMetadata? metadata;
  final String? message;
}

sealed class BtTaskEvent {
  const BtTaskEvent({required this.taskId});

  final BtTaskId taskId;
}

final class BtMetadataReceived extends BtTaskEvent {
  const BtMetadataReceived({required super.taskId, required this.metadata});

  final BtTaskMetadata metadata;
}

final class BtPieceCompleted extends BtTaskEvent {
  const BtPieceCompleted({required super.taskId, required this.pieceIndex});

  final BtPieceIndex pieceIndex;
}

final class BtTaskFailed extends BtTaskEvent {
  const BtTaskFailed({required super.taskId, required this.message});

  final String message;
}

enum BtStreamingCapability {
  taskManagement,
  metadataFetching,
  virtualMediaStream,
  piecePriorityScheduling,
  timelineOverlay,
  longBackgroundDownload,
}

final class BtCapabilityStatus {
  const BtCapabilityStatus.supported()
      : supported = true,
        reason = null;

  const BtCapabilityStatus.unsupported(this.reason) : supported = false;

  final bool supported;
  final String? reason;
}

final class BtCapabilityMatrix {
  const BtCapabilityMatrix(
      {required Map<BtStreamingCapability, BtCapabilityStatus> capabilities})
      : _capabilities = capabilities;

  factory BtCapabilityMatrix.unsupported({required String reason}) {
    return BtCapabilityMatrix(
      capabilities: <BtStreamingCapability, BtCapabilityStatus>{
        for (final BtStreamingCapability capability
            in BtStreamingCapability.values)
          capability: BtCapabilityStatus.unsupported(reason),
      },
    );
  }

  final Map<BtStreamingCapability, BtCapabilityStatus> _capabilities;

  BtCapabilityStatus statusOf(BtStreamingCapability capability) {
    return _capabilities[capability] ??
        const BtCapabilityStatus.unsupported('Capability is not declared.');
  }
}

final class BtTaskCreateRequest {
  const BtTaskCreateRequest(
      {required this.source,
      this.initialFileSelections = const <BtFileIndex>[]});

  final BtTaskSource source;
  final List<BtFileIndex> initialFileSelections;
}

abstract interface class DownloadEngineAdapter implements ElainaAdapter {
  BtCapabilityMatrix get capabilities;

  Future<BtTaskId> createTask(BtTaskCreateRequest request);

  Future<BtTaskMetadata> ensureMetadata(BtTaskId taskId);

  Stream<BtTaskStatus> watchStatus(BtTaskId taskId);

  Stream<BtTaskEvent> watchEvents(BtTaskId taskId);

  Future<void> pause(BtTaskId taskId);

  Future<void> resume(BtTaskId taskId);

  Future<void> remove(BtTaskId taskId);

  Future<void> selectFiles(BtTaskId taskId, Iterable<BtFileIndex> files);
}

enum BtTaskFailureKind {
  capabilityUnsupported,
  taskNotFound,
  adapterUnavailable,
  engineError,
}

final class BtTaskFailure {
  const BtTaskFailure({required this.kind, required this.message});

  final BtTaskFailureKind kind;
  final String message;
}

final class BtTaskCreateOutcome {
  const BtTaskCreateOutcome._({this.taskId, this.failure});

  const BtTaskCreateOutcome.success({required BtTaskId taskId})
      : this._(taskId: taskId);

  const BtTaskCreateOutcome.failure({required BtTaskFailure failure})
      : this._(failure: failure);

  final BtTaskId? taskId;
  final BtTaskFailure? failure;

  bool get isSuccess => failure == null;
}

final class BtTaskMetadataOutcome {
  const BtTaskMetadataOutcome._({this.metadata, this.failure});

  const BtTaskMetadataOutcome.success({required BtTaskMetadata metadata})
      : this._(metadata: metadata);

  const BtTaskMetadataOutcome.failure({required BtTaskFailure failure})
      : this._(failure: failure);

  final BtTaskMetadata? metadata;
  final BtTaskFailure? failure;

  bool get isSuccess => failure == null;
}

final class BtTaskCommandOutcome {
  const BtTaskCommandOutcome._({this.failure});

  const BtTaskCommandOutcome.success() : this._();

  const BtTaskCommandOutcome.failure({required BtTaskFailure failure})
      : this._(failure: failure);

  final BtTaskFailure? failure;

  bool get isSuccess => failure == null;
}

abstract interface class BtTaskCoreContract {
  Future<BtTaskCreateOutcome> createTask(BtTaskCreateRequest request);

  Future<BtTaskMetadataOutcome> ensureMetadata(BtTaskId taskId);

  Stream<BtTaskStatus> watchStatus(BtTaskId taskId);

  Stream<BtTaskEvent> watchEvents(BtTaskId taskId);

  Future<BtTaskCommandOutcome> pause(BtTaskId taskId);

  Future<BtTaskCommandOutcome> resume(BtTaskId taskId);

  Future<BtTaskCommandOutcome> remove(BtTaskId taskId);

  Future<BtTaskCommandOutcome> selectFiles(
      BtTaskId taskId, Iterable<BtFileIndex> files);
}

final class DeterministicBtTaskCore implements BtTaskCoreContract {
  DeterministicBtTaskCore({
    required this.adapter,
    required this.store,
    this.cacheInvalidationBus,
    DateTime Function()? clock,
  }) : _clock = clock ?? _defaultClock;

  final DownloadEngineAdapter adapter;
  final BtTaskStore store;
  final CacheInvalidationBus? cacheInvalidationBus;
  final DateTime Function() _clock;

  @override
  Future<BtTaskCreateOutcome> createTask(BtTaskCreateRequest request) async {
    final BtTaskFailure? unsupported =
        _unsupported(BtStreamingCapability.taskManagement);
    if (unsupported != null) {
      return BtTaskCreateOutcome.failure(failure: unsupported);
    }
    try {
      final BtTaskId taskId = await adapter.createTask(request);
      final StoredBtTaskSourceKind sourceKind =
          _storedSourceKind(request.source);
      await store.storeTask(
        StoredBtTaskRecord(
          id: taskId.value,
          sourceKind: sourceKind,
          sourceUri: _sourceUri(request.source),
          lifecycleState: StoredBtTaskLifecycleState.queued,
          createdAt: _clock(),
          updatedAt: _clock(),
        ),
      );
      await store.recordEvent(
        StoredBtTaskEventRecord(
          taskId: taskId.value,
          eventKind: StoredBtTaskEventKind.created,
          occurredAt: _clock(),
        ),
      );
      cacheInvalidationBus?.publish(
        BtTaskCreated(
          occurredAt: _clock(),
          taskId: taskId.value,
          sourceKind: sourceKind.name,
        ),
      );
      return BtTaskCreateOutcome.success(taskId: taskId);
    } on Object catch (error) {
      return BtTaskCreateOutcome.failure(
        failure: BtTaskFailure(
          kind: BtTaskFailureKind.engineError,
          message: error.toString(),
        ),
      );
    }
  }

  @override
  Future<BtTaskMetadataOutcome> ensureMetadata(BtTaskId taskId) async {
    final BtTaskFailure? unsupported =
        _unsupported(BtStreamingCapability.metadataFetching);
    if (unsupported != null) {
      return BtTaskMetadataOutcome.failure(failure: unsupported);
    }
    final StoredBtTaskRecord? task = await store.findTaskById(taskId.value);
    if (task == null) {
      return BtTaskMetadataOutcome.failure(failure: _taskNotFound(taskId));
    }
    try {
      final BtTaskMetadata metadata = await adapter.ensureMetadata(taskId);
      await _storeMetadata(taskId, metadata);
      await store.storeTask(
        task.copyWith(
          lifecycleState: StoredBtTaskLifecycleState.ready,
          updatedAt: _clock(),
          infoHash: metadata.infoHash?.value,
        ),
      );
      await store.recordEvent(
        StoredBtTaskEventRecord(
          taskId: taskId.value,
          eventKind: StoredBtTaskEventKind.metadataUpdated,
          occurredAt: _clock(),
        ),
      );
      cacheInvalidationBus?.publish(
        BtMetadataUpdated(
          occurredAt: _clock(),
          taskId: taskId.value,
          infoHash: metadata.infoHash?.value,
          name: metadata.name,
        ),
      );
      return BtTaskMetadataOutcome.success(metadata: metadata);
    } on Object catch (error) {
      return BtTaskMetadataOutcome.failure(
        failure: BtTaskFailure(
          kind: BtTaskFailureKind.engineError,
          message: error.toString(),
        ),
      );
    }
  }

  @override
  Future<BtTaskCommandOutcome> pause(BtTaskId taskId) async {
    return _runLifecycleCommand(
      taskId: taskId,
      nextState: BtTaskLifecycleState.paused,
      command: () => adapter.pause(taskId),
    );
  }

  @override
  Future<BtTaskCommandOutcome> resume(BtTaskId taskId) async {
    return _runLifecycleCommand(
      taskId: taskId,
      nextState: BtTaskLifecycleState.downloading,
      command: () => adapter.resume(taskId),
    );
  }

  @override
  Future<BtTaskCommandOutcome> remove(BtTaskId taskId) async {
    final BtTaskFailure? unsupported =
        _unsupported(BtStreamingCapability.taskManagement);
    if (unsupported != null) {
      return BtTaskCommandOutcome.failure(failure: unsupported);
    }
    final StoredBtTaskRecord? task = await store.findTaskById(taskId.value);
    if (task == null) {
      return BtTaskCommandOutcome.failure(failure: _taskNotFound(taskId));
    }
    try {
      await adapter.remove(taskId);
      await store.storeTask(
        task.copyWith(
          lifecycleState: StoredBtTaskLifecycleState.removed,
          updatedAt: _clock(),
        ),
      );
      await store.recordEvent(
        StoredBtTaskEventRecord(
          taskId: taskId.value,
          eventKind: StoredBtTaskEventKind.removed,
          occurredAt: _clock(),
        ),
      );
      cacheInvalidationBus?.publish(
        BtTaskRemoved(occurredAt: _clock(), taskId: taskId.value),
      );
      return const BtTaskCommandOutcome.success();
    } on Object catch (error) {
      return BtTaskCommandOutcome.failure(
        failure: BtTaskFailure(
          kind: BtTaskFailureKind.engineError,
          message: error.toString(),
        ),
      );
    }
  }

  @override
  Future<BtTaskCommandOutcome> selectFiles(
      BtTaskId taskId, Iterable<BtFileIndex> files) async {
    final BtTaskFailure? unsupported =
        _unsupported(BtStreamingCapability.taskManagement);
    if (unsupported != null) {
      return BtTaskCommandOutcome.failure(failure: unsupported);
    }
    final StoredBtTaskRecord? task = await store.findTaskById(taskId.value);
    if (task == null) {
      return BtTaskCommandOutcome.failure(failure: _taskNotFound(taskId));
    }
    try {
      final List<BtFileIndex> selectedFiles = <BtFileIndex>[...files];
      final Set<int> selectedIndexes = <int>{
        for (final BtFileIndex file in selectedFiles) file.value,
      };
      await adapter.selectFiles(taskId, selectedFiles);
      final List<StoredBtTaskFileRecord> existingFiles =
          await store.filesFor(taskId.value);
      if (existingFiles.isNotEmpty) {
        await store.storeFiles(
          taskId: taskId.value,
          files: <StoredBtTaskFileRecord>[
            for (final StoredBtTaskFileRecord file in existingFiles)
              file.copyWith(
                selectionState: selectedIndexes.contains(file.index)
                    ? StoredBtFileSelectionState.selected
                    : StoredBtFileSelectionState.skipped,
              ),
          ],
        );
      }
      await store.recordEvent(
        StoredBtTaskEventRecord(
          taskId: taskId.value,
          eventKind: StoredBtTaskEventKind.fileSelectionChanged,
          occurredAt: _clock(),
        ),
      );
      cacheInvalidationBus?.publish(
        BtTaskFileSelectionChanged(occurredAt: _clock(), taskId: taskId.value),
      );
      return const BtTaskCommandOutcome.success();
    } on Object catch (error) {
      return BtTaskCommandOutcome.failure(
        failure: BtTaskFailure(
          kind: BtTaskFailureKind.engineError,
          message: error.toString(),
        ),
      );
    }
  }

  @override
  Stream<BtTaskStatus> watchStatus(BtTaskId taskId) async* {
    final StoredBtTaskRecord? task = await store.findTaskById(taskId.value);
    if (task == null) {
      return;
    }
    await for (final BtTaskStatus status in adapter.watchStatus(taskId)) {
      await _storeStatusSnapshot(status);
      yield status;
    }
  }

  @override
  Stream<BtTaskEvent> watchEvents(BtTaskId taskId) async* {
    final StoredBtTaskRecord? task = await store.findTaskById(taskId.value);
    if (task == null) {
      return;
    }
    await for (final BtTaskEvent event in adapter.watchEvents(taskId)) {
      await _storeEvent(event);
      yield event;
    }
  }

  Future<BtTaskCommandOutcome> _runLifecycleCommand({
    required BtTaskId taskId,
    required BtTaskLifecycleState nextState,
    required Future<void> Function() command,
  }) async {
    final BtTaskFailure? unsupported =
        _unsupported(BtStreamingCapability.taskManagement);
    if (unsupported != null) {
      return BtTaskCommandOutcome.failure(failure: unsupported);
    }
    final StoredBtTaskRecord? task = await store.findTaskById(taskId.value);
    if (task == null) {
      return BtTaskCommandOutcome.failure(failure: _taskNotFound(taskId));
    }
    try {
      await command();
      await store.storeTask(
        task.copyWith(
          lifecycleState: _storedLifecycleState(nextState),
          updatedAt: _clock(),
        ),
      );
      await store.recordEvent(
        StoredBtTaskEventRecord(
          taskId: taskId.value,
          eventKind: StoredBtTaskEventKind.lifecycleChanged,
          occurredAt: _clock(),
        ),
      );
      cacheInvalidationBus?.publish(
        BtTaskLifecycleChanged(
          occurredAt: _clock(),
          taskId: taskId.value,
          previousState: task.lifecycleState.name,
          newState: nextState.name,
        ),
      );
      return const BtTaskCommandOutcome.success();
    } on Object catch (error) {
      return BtTaskCommandOutcome.failure(
        failure: BtTaskFailure(
          kind: BtTaskFailureKind.engineError,
          message: error.toString(),
        ),
      );
    }
  }

  Future<void> _storeMetadata(BtTaskId taskId, BtTaskMetadata metadata) async {
    await store.storeMetadata(
      StoredBtTaskMetadataRecord(
        taskId: taskId.value,
        infoHash: metadata.infoHash?.value,
        name: metadata.name,
        totalSizeBytes: metadata.totalSizeBytes,
        pieceLengthBytes: metadata.pieceLengthBytes,
      ),
    );
    await store.storeFiles(
      taskId: taskId.value,
      files: <StoredBtTaskFileRecord>[
        for (final BtTaskFile file in metadata.files)
          _storedFileRecord(taskId, file),
      ],
    );
  }

  Future<void> _storeStatusSnapshot(BtTaskStatus status) async {
    final StoredBtTaskRecord? task =
        await store.findTaskById(status.taskId.value);
    if (task == null) {
      return;
    }
    if (status.metadata != null) {
      await _storeMetadata(status.taskId, status.metadata!);
    }
    await store.storeTask(
      task.copyWith(
        lifecycleState: _storedLifecycleState(status.state),
        updatedAt: _clock(),
          infoHash: status.metadata?.infoHash?.value,
        message: status.message,
      ),
    );
    await store.storeTransferSnapshot(
      StoredBtTaskTransferSnapshotRecord(
        taskId: status.taskId.value,
        lifecycleState: _storedLifecycleState(status.state),
        progress: status.progress,
        downloadRateBytesPerSecond: status.downloadRateBytesPerSecond,
        uploadRateBytesPerSecond: status.uploadRateBytesPerSecond,
        connectedPeers: status.connectedPeers,
        observedAt: _clock(),
        message: status.message,
      ),
    );
  }

  Future<void> _storeEvent(BtTaskEvent event) async {
    switch (event) {
      case BtMetadataReceived(:final taskId, :final metadata):
        final StoredBtTaskRecord? task = await store.findTaskById(taskId.value);
        await _storeMetadata(taskId, metadata);
        if (task != null) {
          await store.storeTask(
            task.copyWith(
              lifecycleState: StoredBtTaskLifecycleState.ready,
              updatedAt: _clock(),
              infoHash: metadata.infoHash?.value,
            ),
          );
        }
        await store.recordEvent(
          StoredBtTaskEventRecord(
            taskId: taskId.value,
            eventKind: StoredBtTaskEventKind.metadataUpdated,
            occurredAt: _clock(),
          ),
        );
        cacheInvalidationBus?.publish(
          BtMetadataUpdated(
            occurredAt: _clock(),
            taskId: taskId.value,
          infoHash: metadata.infoHash?.value,
            name: metadata.name,
          ),
        );
      case BtPieceCompleted(:final taskId, :final pieceIndex):
        await store.recordEvent(
          StoredBtTaskEventRecord(
            taskId: taskId.value,
            eventKind: StoredBtTaskEventKind.pieceCompleted,
            occurredAt: _clock(),
            pieceIndex: pieceIndex.value,
          ),
        );
      case BtTaskFailed(:final taskId, :final message):
        final StoredBtTaskRecord? task = await store.findTaskById(taskId.value);
        if (task != null) {
          await store.storeTask(
            task.copyWith(
              lifecycleState: StoredBtTaskLifecycleState.failed,
              updatedAt: _clock(),
              message: message,
            ),
          );
        }
        await store.recordEvent(
          StoredBtTaskEventRecord(
            taskId: taskId.value,
            eventKind: StoredBtTaskEventKind.failed,
            occurredAt: _clock(),
            message: message,
          ),
        );
        cacheInvalidationBus?.publish(
          BtTaskLifecycleChanged(
            occurredAt: _clock(),
            taskId: taskId.value,
            previousState: task?.lifecycleState.name ?? 'unknown',
            newState: BtTaskLifecycleState.failed.name,
          ),
        );
    }
  }

  BtTaskFailure? _unsupported(BtStreamingCapability capability) {
    final BtCapabilityStatus status = adapter.capabilities.statusOf(capability);
    if (status.supported) {
      return null;
    }
    return BtTaskFailure(
      kind: BtTaskFailureKind.capabilityUnsupported,
      message: status.reason ?? '${capability.name} is unsupported.',
    );
  }

  BtTaskFailure _taskNotFound(BtTaskId taskId) {
    return BtTaskFailure(
      kind: BtTaskFailureKind.taskNotFound,
      message: 'BT task ${taskId.value} was not found.',
    );
  }
}

DateTime _defaultClock() => DateTime.now().toUtc();

StoredBtTaskSourceKind _storedSourceKind(BtTaskSource source) {
  return switch (source) {
    MagnetBtTaskSource() => StoredBtTaskSourceKind.magnet,
    TorrentDataBtTaskSource() => StoredBtTaskSourceKind.torrentData,
  };
}

String _sourceUri(BtTaskSource source) {
  return switch (source) {
    MagnetBtTaskSource(:final uri) => uri,
    TorrentDataBtTaskSource(:final uri) => uri.toString(),
  };
}

StoredBtTaskLifecycleState _storedLifecycleState(BtTaskLifecycleState state) {
  return switch (state) {
    BtTaskLifecycleState.queued => StoredBtTaskLifecycleState.queued,
    BtTaskLifecycleState.fetchingMetadata =>
      StoredBtTaskLifecycleState.fetchingMetadata,
    BtTaskLifecycleState.ready => StoredBtTaskLifecycleState.ready,
    BtTaskLifecycleState.downloading => StoredBtTaskLifecycleState.downloading,
    BtTaskLifecycleState.paused => StoredBtTaskLifecycleState.paused,
    BtTaskLifecycleState.completed => StoredBtTaskLifecycleState.completed,
    BtTaskLifecycleState.failed => StoredBtTaskLifecycleState.failed,
  };
}

StoredBtFileSelectionState _storedFileSelectionState(
    BtFileSelectionState state) {
  return switch (state) {
    BtFileSelectionState.skipped => StoredBtFileSelectionState.skipped,
    BtFileSelectionState.selected => StoredBtFileSelectionState.selected,
    BtFileSelectionState.streamingTarget =>
      StoredBtFileSelectionState.streamingTarget,
  };
}

StoredBtTaskFileRecord _storedFileRecord(BtTaskId taskId, BtTaskFile file) {
  return StoredBtTaskFileRecord(
    taskId: taskId.value,
    index: file.index.value,
    path: file.path,
    lengthBytes: file.lengthBytes,
    offsetBytes: file.offsetBytes,
    selectionState: _storedFileSelectionState(file.selectionState),
    isStreamable: file.isStreamable,
    mediaMimeType: file.mediaMimeType,
  );
}
