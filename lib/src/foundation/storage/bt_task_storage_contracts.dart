enum StoredBtTaskSourceKind {
  magnet,
  torrentData,
}

enum StoredBtTaskLifecycleState {
  queued,
  fetchingMetadata,
  ready,
  downloading,
  paused,
  completed,
  failed,
  removed,
}

enum StoredBtFileSelectionState {
  skipped,
  selected,
  streamingTarget,
}

enum StoredBtTaskEventKind {
  created,
  metadataUpdated,
  lifecycleChanged,
  fileSelectionChanged,
  pieceCompleted,
  failed,
  removed,
}

final class StoredBtTaskRecord {
  const StoredBtTaskRecord({
    required this.id,
    required this.sourceKind,
    required this.sourceUri,
    required this.lifecycleState,
    required this.createdAt,
    required this.updatedAt,
    this.infoHash,
    this.message,
  })  : assert(id != '', 'BT task id must not be empty.'),
        assert(sourceUri != '', 'BT task source URI must not be empty.');

  final String id;
  final StoredBtTaskSourceKind sourceKind;
  final String sourceUri;
  final StoredBtTaskLifecycleState lifecycleState;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? infoHash;
  final String? message;

  StoredBtTaskRecord copyWith({
    StoredBtTaskLifecycleState? lifecycleState,
    DateTime? updatedAt,
    String? infoHash,
    String? message,
  }) {
    return StoredBtTaskRecord(
      id: id,
      sourceKind: sourceKind,
      sourceUri: sourceUri,
      lifecycleState: lifecycleState ?? this.lifecycleState,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      infoHash: infoHash ?? this.infoHash,
      message: message ?? this.message,
    );
  }
}

final class StoredBtTaskMetadataRecord {
  const StoredBtTaskMetadataRecord({
    required this.taskId,
    required this.infoHash,
    required this.name,
    required this.totalSizeBytes,
    required this.pieceLengthBytes,
  })  : assert(taskId != '', 'BT task id must not be empty.'),
        assert(infoHash != '', 'Info hash must not be empty.'),
        assert(name != '', 'BT metadata name must not be empty.'),
        assert(totalSizeBytes >= 0, 'totalSizeBytes must not be negative.'),
        assert(pieceLengthBytes > 0, 'pieceLengthBytes must be positive.');

  final String taskId;
  final String infoHash;
  final String name;
  final int totalSizeBytes;
  final int pieceLengthBytes;
}

final class StoredBtTaskFileRecord {
  const StoredBtTaskFileRecord({
    required this.taskId,
    required this.index,
    required this.path,
    required this.lengthBytes,
    required this.offsetBytes,
    required this.selectionState,
    this.mediaMimeType,
  })  : assert(taskId != '', 'BT task id must not be empty.'),
        assert(index >= 0, 'BT file index must not be negative.'),
        assert(path != '', 'BT file path must not be empty.'),
        assert(lengthBytes >= 0, 'lengthBytes must not be negative.'),
        assert(offsetBytes >= 0, 'offsetBytes must not be negative.');

  final String taskId;
  final int index;
  final String path;
  final int lengthBytes;
  final int offsetBytes;
  final StoredBtFileSelectionState selectionState;
  final String? mediaMimeType;

  StoredBtTaskFileRecord copyWith({
    StoredBtFileSelectionState? selectionState,
  }) {
    return StoredBtTaskFileRecord(
      taskId: taskId,
      index: index,
      path: path,
      lengthBytes: lengthBytes,
      offsetBytes: offsetBytes,
      selectionState: selectionState ?? this.selectionState,
      mediaMimeType: mediaMimeType,
    );
  }
}

final class StoredBtTaskTransferSnapshotRecord {
  const StoredBtTaskTransferSnapshotRecord({
    required this.taskId,
    required this.lifecycleState,
    required this.progress,
    required this.downloadRateBytesPerSecond,
    required this.uploadRateBytesPerSecond,
    required this.connectedPeers,
    required this.observedAt,
    this.message,
  })  : assert(taskId != '', 'BT task id must not be empty.'),
        assert(progress >= 0 && progress <= 1,
            'progress must be between 0 and 1.'),
        assert(downloadRateBytesPerSecond >= 0,
            'download rate must not be negative.'),
        assert(
            uploadRateBytesPerSecond >= 0, 'upload rate must not be negative.'),
        assert(connectedPeers >= 0, 'connectedPeers must not be negative.');

  final String taskId;
  final StoredBtTaskLifecycleState lifecycleState;
  final double progress;
  final int downloadRateBytesPerSecond;
  final int uploadRateBytesPerSecond;
  final int connectedPeers;
  final DateTime observedAt;
  final String? message;
}

final class StoredBtTaskEventRecord {
  const StoredBtTaskEventRecord({
    required this.taskId,
    required this.eventKind,
    required this.occurredAt,
    this.pieceIndex,
    this.message,
  })  : assert(taskId != '', 'BT task id must not be empty.'),
        assert(pieceIndex == null || pieceIndex >= 0,
            'pieceIndex must not be negative.');

  final String taskId;
  final StoredBtTaskEventKind eventKind;
  final DateTime occurredAt;
  final int? pieceIndex;
  final String? message;
}

abstract interface class BtTaskStore {
  Future<StoredBtTaskRecord> storeTask(StoredBtTaskRecord task);

  Future<StoredBtTaskRecord?> findTaskById(String taskId);

  Future<List<StoredBtTaskRecord>> listTasks({int offset = 0, int limit = 50});

  Future<bool> removeTask(String taskId);

  Future<int> count();

  Future<void> storeMetadata(StoredBtTaskMetadataRecord metadata);

  Future<StoredBtTaskMetadataRecord?> metadataFor(String taskId);

  Future<void> storeFiles({
    required String taskId,
    required Iterable<StoredBtTaskFileRecord> files,
  });

  Future<List<StoredBtTaskFileRecord>> filesFor(String taskId);

  Future<void> storeTransferSnapshot(
      StoredBtTaskTransferSnapshotRecord snapshot);

  Future<StoredBtTaskTransferSnapshotRecord?> latestTransferSnapshot(
      String taskId);

  Future<void> recordEvent(StoredBtTaskEventRecord event);

  Future<StoredBtTaskEventRecord?> latestEvent(String taskId);
}

final class DeterministicBtTaskStore implements BtTaskStore {
  DeterministicBtTaskStore({
    Iterable<StoredBtTaskRecord> seedTasks = const <StoredBtTaskRecord>[],
  }) {
    for (final StoredBtTaskRecord task in seedTasks) {
      _tasksById[task.id] = task;
    }
  }

  final Map<String, StoredBtTaskRecord> _tasksById =
      <String, StoredBtTaskRecord>{};
  final Map<String, StoredBtTaskMetadataRecord> _metadataByTaskId =
      <String, StoredBtTaskMetadataRecord>{};
  final Map<String, List<StoredBtTaskFileRecord>> _filesByTaskId =
      <String, List<StoredBtTaskFileRecord>>{};
  final Map<String, StoredBtTaskTransferSnapshotRecord> _snapshotsByTaskId =
      <String, StoredBtTaskTransferSnapshotRecord>{};
  final Map<String, StoredBtTaskEventRecord> _eventsByTaskId =
      <String, StoredBtTaskEventRecord>{};

  @override
  Future<int> count() => Future<int>.value(_tasksById.length);

  @override
  Future<StoredBtTaskRecord?> findTaskById(String taskId) {
    return Future<StoredBtTaskRecord?>.value(_tasksById[taskId]);
  }

  @override
  Future<List<StoredBtTaskFileRecord>> filesFor(String taskId) {
    return Future<List<StoredBtTaskFileRecord>>.value(
        <StoredBtTaskFileRecord>[...?_filesByTaskId[taskId]]);
  }

  @override
  Future<StoredBtTaskTransferSnapshotRecord?> latestTransferSnapshot(
      String taskId) {
    return Future<StoredBtTaskTransferSnapshotRecord?>.value(
        _snapshotsByTaskId[taskId]);
  }

  @override
  Future<StoredBtTaskEventRecord?> latestEvent(String taskId) {
    return Future<StoredBtTaskEventRecord?>.value(_eventsByTaskId[taskId]);
  }

  @override
  Future<List<StoredBtTaskRecord>> listTasks({int offset = 0, int limit = 50}) {
    assert(offset >= 0, 'offset must not be negative.');
    assert(limit > 0, 'limit must be positive.');
    final List<StoredBtTaskRecord> tasks = <StoredBtTaskRecord>[
      ..._tasksById.values,
    ];
    final int start = offset > tasks.length ? tasks.length : offset;
    final int end = start + limit > tasks.length ? tasks.length : start + limit;
    return Future<List<StoredBtTaskRecord>>.value(tasks.sublist(start, end));
  }

  @override
  Future<StoredBtTaskMetadataRecord?> metadataFor(String taskId) {
    return Future<StoredBtTaskMetadataRecord?>.value(_metadataByTaskId[taskId]);
  }

  @override
  Future<void> recordEvent(StoredBtTaskEventRecord event) {
    _eventsByTaskId[event.taskId] = event;
    return Future<void>.value();
  }

  @override
  Future<bool> removeTask(String taskId) {
    final bool removed = _tasksById.remove(taskId) != null;
    _metadataByTaskId.remove(taskId);
    _filesByTaskId.remove(taskId);
    _snapshotsByTaskId.remove(taskId);
    _eventsByTaskId.remove(taskId);
    return Future<bool>.value(removed);
  }

  @override
  Future<void> storeFiles({
    required String taskId,
    required Iterable<StoredBtTaskFileRecord> files,
  }) {
    _filesByTaskId[taskId] = <StoredBtTaskFileRecord>[...files];
    return Future<void>.value();
  }

  @override
  Future<void> storeMetadata(StoredBtTaskMetadataRecord metadata) {
    _metadataByTaskId[metadata.taskId] = metadata;
    return Future<void>.value();
  }

  @override
  Future<StoredBtTaskRecord> storeTask(StoredBtTaskRecord task) {
    _tasksById[task.id] = task;
    return Future<StoredBtTaskRecord>.value(task);
  }

  @override
  Future<void> storeTransferSnapshot(
      StoredBtTaskTransferSnapshotRecord snapshot) {
    _snapshotsByTaskId[snapshot.taskId] = snapshot;
    return Future<void>.value();
  }
}
