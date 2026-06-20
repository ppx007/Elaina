import '../foundation/baseline_defaults.dart';
import '../foundation/cache_invalidation/cache_invalidation_bus.dart';
import '../foundation/storage/storage_contracts.dart';
import 'bt_task_core.dart';
import 'virtual_media_stream.dart';

enum VirtualMediaStreamRuntimeStatus {
  idle,
  ready,
  unavailable,
  disposed,
}

enum VirtualMediaStreamRuntimeFailureKind {
  disposed,
  unavailable,
  streamUnavailable,
  taskUnavailable,
  taskFailed,
  metadataUnavailable,
  fileUnavailable,
  fileSkipped,
  streamClosed,
  streamFailed,
  rangeUnavailable,
}

final class VirtualMediaStreamRuntimeFailure {
  const VirtualMediaStreamRuntimeFailure({
    required this.kind,
    required this.message,
  }) : assert(message != '',
            'Virtual media stream runtime failure message must not be empty.');

  final VirtualMediaStreamRuntimeFailureKind kind;
  final String message;
}

enum VirtualMediaStreamRuntimeActionResultKind {
  success,
  unavailable,
  failed,
  disposed,
}

final class VirtualMediaStreamRuntimeActionResult<T> {
  const VirtualMediaStreamRuntimeActionResult._({
    required this.kind,
    this.value,
    this.failure,
  });

  const VirtualMediaStreamRuntimeActionResult.success([T? value])
      : this._(
          kind: VirtualMediaStreamRuntimeActionResultKind.success,
          value: value,
        );

  const VirtualMediaStreamRuntimeActionResult.unavailable(
    VirtualMediaStreamRuntimeFailure failure,
  ) : this._(
          kind: VirtualMediaStreamRuntimeActionResultKind.unavailable,
          failure: failure,
        );

  const VirtualMediaStreamRuntimeActionResult.failed(
    VirtualMediaStreamRuntimeFailure failure,
  ) : this._(
          kind: VirtualMediaStreamRuntimeActionResultKind.failed,
          failure: failure,
        );

  const VirtualMediaStreamRuntimeActionResult.disposed(
    VirtualMediaStreamRuntimeFailure failure,
  ) : this._(
          kind: VirtualMediaStreamRuntimeActionResultKind.disposed,
          failure: failure,
        );

  final VirtualMediaStreamRuntimeActionResultKind kind;
  final T? value;
  final VirtualMediaStreamRuntimeFailure? failure;

  bool get isSuccess =>
      kind == VirtualMediaStreamRuntimeActionResultKind.success;
}

final class VirtualBufferedRangeProjection {
  const VirtualBufferedRangeProjection({
    required this.range,
    required this.observedAt,
  });

  final BufferedRange range;
  final DateTime observedAt;
}

enum VirtualStreamRestartDisposition {
  active,
  closed,
  failed,
  incomplete,
  missingTask,
  rangeFailed,
}

final class VirtualStreamRestartProjection {
  const VirtualStreamRestartProjection({
    required this.streamId,
    required this.disposition,
    required this.requiresTaskReconciliation,
    this.reason,
  });

  final VirtualMediaStreamId streamId;
  final VirtualStreamRestartDisposition disposition;
  final bool requiresTaskReconciliation;
  final String? reason;
}

final class VirtualMediaStreamSnapshot {
  VirtualMediaStreamSnapshot({
    required this.descriptor,
    required this.lifecycleState,
    required this.createdAt,
    required this.updatedAt,
    required this.restart,
    Iterable<VirtualBufferedRangeProjection> bufferedRanges =
        const <VirtualBufferedRangeProjection>[],
    this.latestEventKind,
    this.latestFailure,
  }) : bufferedRanges =
            List<VirtualBufferedRangeProjection>.unmodifiable(bufferedRanges);

  final VirtualMediaStreamDescriptor descriptor;
  final StoredVirtualMediaStreamLifecycleState lifecycleState;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<VirtualBufferedRangeProjection> bufferedRanges;
  final StoredVirtualStreamEventKind? latestEventKind;
  final VirtualMediaStreamRuntimeFailure? latestFailure;
  final VirtualStreamRestartProjection restart;
}

final class VirtualMediaStreamRuntimeSnapshot {
  VirtualMediaStreamRuntimeSnapshot({
    required this.status,
    Iterable<VirtualMediaStreamSnapshot> streams =
        const <VirtualMediaStreamSnapshot>[],
    Iterable<VirtualMediaStreamRuntimeFailure> failures =
        const <VirtualMediaStreamRuntimeFailure>[],
  })  : streams = List<VirtualMediaStreamSnapshot>.unmodifiable(streams),
        failures =
            List<VirtualMediaStreamRuntimeFailure>.unmodifiable(failures);

  VirtualMediaStreamRuntimeSnapshot.idle()
      : this(status: VirtualMediaStreamRuntimeStatus.idle);

  final VirtualMediaStreamRuntimeStatus status;
  final List<VirtualMediaStreamSnapshot> streams;
  final List<VirtualMediaStreamRuntimeFailure> failures;
}

final class VirtualMediaStreamBootstrap {
  VirtualMediaStreamBootstrap({
    required BtTaskStore btTaskStore,
    required VirtualMediaStreamStore streamStore,
    CacheInvalidationBus? cacheInvalidationBus,
    VirtualStreamContentUriResolver? contentUriResolver,
    VirtualByteRangeSource? byteSource,
    DateTime Function()? clock,
  }) : runtime = VirtualMediaStreamRuntime.withDependencies(
          btTaskStore: btTaskStore,
          streamStore: streamStore,
          cacheInvalidationBus: cacheInvalidationBus,
          contentUriResolver: contentUriResolver,
          byteSource: byteSource,
          clock: clock,
        );

  VirtualMediaStreamBootstrap.withRuntime({required this.runtime});

  final VirtualMediaStreamRuntime runtime;
}

final class VirtualMediaStreamRuntime {
  VirtualMediaStreamRuntime.withDependencies({
    required BtTaskStore btTaskStore,
    required VirtualMediaStreamStore streamStore,
    CacheInvalidationBus? cacheInvalidationBus,
    VirtualStreamContentUriResolver? contentUriResolver,
    VirtualByteRangeSource? byteSource,
    DateTime Function()? clock,
  }) : this(
          registry: DeterministicVirtualMediaStreamRegistry(
            btTaskStore: btTaskStore,
            streamStore: streamStore,
            cacheInvalidationBus: cacheInvalidationBus,
            contentUriResolver: contentUriResolver,
            byteSource: byteSource,
            clock: clock,
          ),
          btTaskStore: btTaskStore,
          streamStore: streamStore,
          cacheInvalidationBus: cacheInvalidationBus,
          clock: clock,
        );

  VirtualMediaStreamRuntime({
    required VirtualMediaStreamRegistry registry,
    required BtTaskStore btTaskStore,
    required VirtualMediaStreamStore streamStore,
    CacheInvalidationBus? cacheInvalidationBus,
    DateTime Function()? clock,
  })  : _registry = registry,
        _btTaskStore = btTaskStore,
        _streamStore = streamStore,
        _cacheInvalidationBus = cacheInvalidationBus,
        _clock = clock ?? _defaultVirtualStreamRuntimeClock,
        _unavailableReason = null,
        _snapshot = VirtualMediaStreamRuntimeSnapshot.idle();

  VirtualMediaStreamRuntime.unavailable({required String reason})
      : _registry = null,
        _btTaskStore = DeterministicBtTaskStore(),
        _streamStore = DeterministicVirtualMediaStreamStore(),
        _cacheInvalidationBus = null,
        _clock = _defaultVirtualStreamRuntimeClock,
        _unavailableReason = reason,
        _snapshot = VirtualMediaStreamRuntimeSnapshot(
          status: VirtualMediaStreamRuntimeStatus.unavailable,
          failures: <VirtualMediaStreamRuntimeFailure>[
            VirtualMediaStreamRuntimeFailure(
              kind: VirtualMediaStreamRuntimeFailureKind.unavailable,
              message: reason,
            ),
          ],
        );

  final VirtualMediaStreamRegistry? _registry;
  final BtTaskStore _btTaskStore;
  final VirtualMediaStreamStore _streamStore;
  final CacheInvalidationBus? _cacheInvalidationBus;
  final DateTime Function() _clock;
  final String? _unavailableReason;
  VirtualMediaStreamRuntimeSnapshot _snapshot;
  bool _disposed = false;

  bool get isDisposed => _disposed;

  VirtualMediaStreamRuntimeSnapshot get currentSnapshot => _snapshot;

  Future<VirtualMediaStreamRuntimeActionResult<VirtualMediaStreamSnapshot>>
      createStream(VirtualMediaStreamCreateRequest request) async {
    final VirtualMediaStreamRuntimeActionResult<VirtualMediaStreamSnapshot>?
        gate = _gate<VirtualMediaStreamSnapshot>();
    if (gate != null) return gate;

    final VirtualMediaStreamCreateOutcome outcome =
        await _registry!.createForFile(
      taskId: request.taskId,
      fileIndex: request.fileIndex,
    );
    if (!outcome.isSuccess) {
      return _failed<VirtualMediaStreamSnapshot>(_mapFailure(outcome.failure!));
    }

    final VirtualMediaStreamSnapshot snapshot =
        await _snapshotForId(outcome.descriptor!.id.value);
    await _publishSnapshot();
    return VirtualMediaStreamRuntimeActionResult<
        VirtualMediaStreamSnapshot>.success(snapshot);
  }

  Future<VirtualMediaStreamRuntimeActionResult<VirtualMediaStreamSnapshot?>>
      streamById(VirtualMediaStreamId streamId) async {
    final VirtualMediaStreamRuntimeActionResult<VirtualMediaStreamSnapshot?>?
        gate = _gate<VirtualMediaStreamSnapshot?>();
    if (gate != null) return gate;

    final StoredVirtualMediaStreamRecord? record =
        await _streamStore.findStreamById(streamId.value);
    if (record == null) {
      return _failed<VirtualMediaStreamSnapshot?>(
        VirtualMediaStreamRuntimeFailure(
          kind: VirtualMediaStreamRuntimeFailureKind.streamUnavailable,
          message: 'Virtual stream ${streamId.value} was not found.',
        ),
      );
    }

    final VirtualMediaStreamSnapshot snapshot =
        await _snapshotFromRecord(record);
    await _publishSnapshot();
    return VirtualMediaStreamRuntimeActionResult<
        VirtualMediaStreamSnapshot?>.success(snapshot);
  }

  Future<
      VirtualMediaStreamRuntimeActionResult<
          List<VirtualMediaStreamSnapshot>>> listStreams(
      {int offset = 0, int limit = defaultListPageLimit}) async {
    final VirtualMediaStreamRuntimeActionResult<
            List<VirtualMediaStreamSnapshot>>? gate =
        _gate<List<VirtualMediaStreamSnapshot>>();
    if (gate != null) return gate;

    final List<StoredVirtualMediaStreamRecord> records =
        await _streamStore.listStreams(offset: offset, limit: limit);
    final List<VirtualMediaStreamSnapshot> snapshots =
        await _snapshotsFromRecords(records);
    _snapshot = VirtualMediaStreamRuntimeSnapshot(
      status: VirtualMediaStreamRuntimeStatus.ready,
      streams: snapshots,
      failures: _snapshot.failures,
    );
    return VirtualMediaStreamRuntimeActionResult<
            List<VirtualMediaStreamSnapshot>>.success(
        List<VirtualMediaStreamSnapshot>.unmodifiable(snapshots));
  }

  Future<VirtualMediaStreamRuntimeActionResult<VirtualMediaStreamSnapshot>>
      ensureRange(VirtualByteRangeRequest request) async {
    final VirtualMediaStreamRuntimeActionResult<VirtualMediaStreamSnapshot>?
        gate = _gate<VirtualMediaStreamSnapshot>();
    if (gate != null) return gate;

    final VirtualMediaStreamRuntimeActionResult<VirtualMediaStream>
        streamResult = await _runtimeStream(request.streamId);
    if (!streamResult.isSuccess) {
      return _forwardFailure<VirtualMediaStream, VirtualMediaStreamSnapshot>(
          streamResult);
    }

    final VirtualRangeEnsureOutcome outcome =
        await streamResult.value!.ensureRange(request);
    if (!outcome.isSuccess) {
      return _failed<VirtualMediaStreamSnapshot>(_mapFailure(outcome.failure!));
    }

    final VirtualMediaStreamSnapshot snapshot =
        await _snapshotForId(request.streamId.value);
    await _publishSnapshot();
    return VirtualMediaStreamRuntimeActionResult<
        VirtualMediaStreamSnapshot>.success(snapshot);
  }

  Future<VirtualMediaStreamRuntimeActionResult<Stream<VirtualByteRangeChunk>>>
      openRange(VirtualByteRangeRequest request) async {
    final VirtualMediaStreamRuntimeActionResult<Stream<VirtualByteRangeChunk>>?
        gate = _gate<Stream<VirtualByteRangeChunk>>();
    if (gate != null) return gate;

    final VirtualMediaStreamRuntimeActionResult<VirtualMediaStream>
        streamResult = await _runtimeStream(request.streamId);
    if (!streamResult.isSuccess) {
      return _forwardFailure<VirtualMediaStream, Stream<VirtualByteRangeChunk>>(
          streamResult);
    }

    return VirtualMediaStreamRuntimeActionResult<
        Stream<VirtualByteRangeChunk>>.success(
      streamResult.value!.openRange(request),
    );
  }

  Future<VirtualMediaStreamRuntimeActionResult<VirtualMediaStreamSnapshot>>
      closeStream(VirtualMediaStreamId streamId) async {
    final VirtualMediaStreamRuntimeActionResult<VirtualMediaStreamSnapshot>?
        gate = _gate<VirtualMediaStreamSnapshot>();
    if (gate != null) return gate;

    final StoredVirtualMediaStreamRecord? record =
        await _streamStore.findStreamById(streamId.value);
    if (record == null) {
      return _failed<VirtualMediaStreamSnapshot>(
        VirtualMediaStreamRuntimeFailure(
          kind: VirtualMediaStreamRuntimeFailureKind.streamUnavailable,
          message: 'Virtual stream ${streamId.value} was not found.',
        ),
      );
    }
    final VirtualMediaStreamRuntimeFailure? lifecycleFailure =
        _lifecycleMutationFailure(record);
    if (lifecycleFailure != null) {
      return _failed<VirtualMediaStreamSnapshot>(lifecycleFailure);
    }

    final VirtualMediaStreamRuntimeActionResult<VirtualMediaStream>
        streamResult = await _runtimeStream(streamId);
    if (!streamResult.isSuccess) {
      return _forwardFailure<VirtualMediaStream, VirtualMediaStreamSnapshot>(
          streamResult);
    }

    final VirtualStreamCommandOutcome outcome =
        await streamResult.value!.close();
    if (!outcome.isSuccess) {
      return _failed<VirtualMediaStreamSnapshot>(_mapFailure(outcome.failure!));
    }

    final VirtualMediaStreamSnapshot snapshot =
        await _snapshotForId(streamId.value);
    await _publishSnapshot();
    return VirtualMediaStreamRuntimeActionResult<
        VirtualMediaStreamSnapshot>.success(snapshot);
  }

  Future<VirtualMediaStreamRuntimeActionResult<VirtualMediaStreamSnapshot>>
      failStream(
    VirtualMediaStreamId streamId, {
    required String message,
  }) async {
    final VirtualMediaStreamRuntimeActionResult<VirtualMediaStreamSnapshot>?
        gate = _gate<VirtualMediaStreamSnapshot>();
    if (gate != null) return gate;

    final StoredVirtualMediaStreamRecord? record =
        await _streamStore.findStreamById(streamId.value);
    if (record == null) {
      return _failed<VirtualMediaStreamSnapshot>(
        VirtualMediaStreamRuntimeFailure(
          kind: VirtualMediaStreamRuntimeFailureKind.streamUnavailable,
          message: 'Virtual stream ${streamId.value} was not found.',
        ),
      );
    }
    final VirtualMediaStreamRuntimeFailure? lifecycleFailure =
        _lifecycleMutationFailure(record);
    if (lifecycleFailure != null) {
      return _failed<VirtualMediaStreamSnapshot>(lifecycleFailure);
    }

    await _streamStore.storeStream(record.copyWith(
      lifecycleState: StoredVirtualMediaStreamLifecycleState.failed,
      updatedAt: _clock(),
      message: message,
    ));
    await _streamStore.recordEvent(StoredVirtualStreamEventRecord(
      streamId: streamId.value,
      eventKind: StoredVirtualStreamEventKind.failed,
      occurredAt: _clock(),
      failureKind: VirtualMediaStreamFailureKind.streamFailed.name,
      message: message,
    ));
    _cacheInvalidationBus?.publish(VirtualStreamFailed(
      occurredAt: _clock(),
      streamId: streamId.value,
      taskId: record.taskId,
      fileIndex: record.fileIndex,
      failureKind: VirtualMediaStreamFailureKind.streamFailed.name,
      message: message,
    ));

    final VirtualMediaStreamSnapshot snapshot =
        await _snapshotForId(streamId.value);
    await _publishSnapshot();
    return VirtualMediaStreamRuntimeActionResult<
        VirtualMediaStreamSnapshot>.success(snapshot);
  }

  Future<
      VirtualMediaStreamRuntimeActionResult<
          List<VirtualStreamRestartProjection>>> restartReconciliation() async {
    final VirtualMediaStreamRuntimeActionResult<
            List<VirtualStreamRestartProjection>>? gate =
        _gate<List<VirtualStreamRestartProjection>>();
    if (gate != null) return gate;

    final List<StoredVirtualMediaStreamRecord> records = await _listAllStreams();
    final List<VirtualStreamRestartProjection> projections =
        <VirtualStreamRestartProjection>[];
    for (final StoredVirtualMediaStreamRecord record in records) {
      projections.add(await _restartProjection(record));
    }

    await _publishSnapshot();
    return VirtualMediaStreamRuntimeActionResult<
        List<VirtualStreamRestartProjection>>.success(
      List<VirtualStreamRestartProjection>.unmodifiable(projections),
    );
  }

  Future<void> dispose() async {
    _disposed = true;
    _snapshot = VirtualMediaStreamRuntimeSnapshot(
      status: VirtualMediaStreamRuntimeStatus.disposed,
      streams: _snapshot.streams,
      failures: <VirtualMediaStreamRuntimeFailure>[
        ..._snapshot.failures,
        const VirtualMediaStreamRuntimeFailure(
          kind: VirtualMediaStreamRuntimeFailureKind.disposed,
          message: 'Virtual media stream runtime has been disposed.',
        ),
      ],
    );
  }

  VirtualMediaStreamRuntimeActionResult<T>? _gate<T>() {
    if (_disposed) {
      return VirtualMediaStreamRuntimeActionResult<T>.disposed(
        const VirtualMediaStreamRuntimeFailure(
          kind: VirtualMediaStreamRuntimeFailureKind.disposed,
          message: 'Virtual media stream runtime has been disposed.',
        ),
      );
    }
    if (_registry == null) {
      return VirtualMediaStreamRuntimeActionResult<T>.unavailable(
        VirtualMediaStreamRuntimeFailure(
          kind: VirtualMediaStreamRuntimeFailureKind.unavailable,
          message: _unavailableReason ??
              'Virtual media stream runtime is unavailable.',
        ),
      );
    }
    return null;
  }

  Future<VirtualMediaStreamRuntimeActionResult<VirtualMediaStream>>
      _runtimeStream(VirtualMediaStreamId streamId) async {
    final VirtualMediaStream? stream = await _registry!.streamFor(streamId);
    if (stream == null) {
      return VirtualMediaStreamRuntimeActionResult<VirtualMediaStream>.failed(
        VirtualMediaStreamRuntimeFailure(
          kind: VirtualMediaStreamRuntimeFailureKind.streamUnavailable,
          message: 'Virtual stream ${streamId.value} was not found.',
        ),
      );
    }
    return VirtualMediaStreamRuntimeActionResult<VirtualMediaStream>.success(
        stream);
  }

  VirtualMediaStreamRuntimeActionResult<T> _failed<T>(
    VirtualMediaStreamRuntimeFailure failure,
  ) {
    _snapshot = VirtualMediaStreamRuntimeSnapshot(
      status: _snapshot.status == VirtualMediaStreamRuntimeStatus.idle
          ? VirtualMediaStreamRuntimeStatus.ready
          : _snapshot.status,
      streams: _snapshot.streams,
      failures: <VirtualMediaStreamRuntimeFailure>[
        ..._snapshot.failures,
        failure,
      ],
    );
    return VirtualMediaStreamRuntimeActionResult<T>.failed(failure);
  }

  VirtualMediaStreamRuntimeActionResult<TTo> _forwardFailure<TFrom, TTo>(
    VirtualMediaStreamRuntimeActionResult<TFrom> result,
  ) {
    return switch (result.kind) {
      VirtualMediaStreamRuntimeActionResultKind.disposed =>
        VirtualMediaStreamRuntimeActionResult<TTo>.disposed(result.failure!),
      VirtualMediaStreamRuntimeActionResultKind.unavailable =>
        VirtualMediaStreamRuntimeActionResult<TTo>.unavailable(result.failure!),
      VirtualMediaStreamRuntimeActionResultKind.failed =>
        VirtualMediaStreamRuntimeActionResult<TTo>.failed(result.failure!),
      VirtualMediaStreamRuntimeActionResultKind.success =>
        throw StateError('Expected runtime action failure.'),
    };
  }

  /// Pages through every persisted stream record so reconciliation and
  /// snapshots are not silently truncated at a fixed ceiling.
  Future<List<StoredVirtualMediaStreamRecord>> _listAllStreams() async {
    final List<StoredVirtualMediaStreamRecord> all =
        <StoredVirtualMediaStreamRecord>[];
    var offset = 0;
    while (true) {
      final List<StoredVirtualMediaStreamRecord> page =
          await _streamStore.listStreams(
        offset: offset,
        limit: defaultListPageLimit,
      );
      all.addAll(page);
      if (page.length < defaultListPageLimit) {
        break;
      }
      offset += page.length;
    }
    return all;
  }

  Future<void> _publishSnapshot() async {
    final List<StoredVirtualMediaStreamRecord> records = await _listAllStreams();
    _snapshot = VirtualMediaStreamRuntimeSnapshot(
      status: _disposed
          ? VirtualMediaStreamRuntimeStatus.disposed
          : _registry == null
              ? VirtualMediaStreamRuntimeStatus.unavailable
              : VirtualMediaStreamRuntimeStatus.ready,
      streams: await _snapshotsFromRecords(records),
      failures: _snapshot.failures,
    );
  }

  Future<List<VirtualMediaStreamSnapshot>> _snapshotsFromRecords(
    List<StoredVirtualMediaStreamRecord> records,
  ) async {
    final List<VirtualMediaStreamSnapshot> snapshots =
        <VirtualMediaStreamSnapshot>[];
    for (final StoredVirtualMediaStreamRecord record in records) {
      snapshots.add(await _snapshotFromRecord(record));
    }
    return snapshots;
  }

  Future<VirtualMediaStreamSnapshot> _snapshotForId(String streamId) async {
    final StoredVirtualMediaStreamRecord? record =
        await _streamStore.findStreamById(streamId);
    if (record == null) {
      throw StateError('Persisted virtual stream $streamId was not found.');
    }
    return _snapshotFromRecord(record);
  }

  Future<VirtualMediaStreamSnapshot> _snapshotFromRecord(
    StoredVirtualMediaStreamRecord record,
  ) async {
    final List<StoredVirtualStreamBufferedRangeRecord> rangeRecords =
        await _streamStore.bufferedRangesFor(record.id);
    final StoredVirtualStreamEventRecord? latestEvent =
        await _streamStore.latestEvent(record.id);
    final VirtualMediaStreamRuntimeFailure? latestFailure =
        _latestFailure(record, latestEvent);

    return VirtualMediaStreamSnapshot(
      descriptor: VirtualMediaStreamDescriptor(
        id: VirtualMediaStreamId(record.id),
        taskId: BtTaskId(record.taskId),
        fileIndex: BtFileIndex(record.fileIndex),
        lengthBytes: record.lengthBytes,
        contentUri: record.contentUri,
        mimeType: record.mimeType,
      ),
      lifecycleState: record.lifecycleState,
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
      bufferedRanges: <VirtualBufferedRangeProjection>[
        for (final StoredVirtualStreamBufferedRangeRecord range in rangeRecords)
          VirtualBufferedRangeProjection(
            range: BufferedRange(
              startByte: range.startByte,
              endByte: range.endByte,
            ),
            observedAt: range.observedAt,
          ),
      ],
      latestEventKind: latestEvent?.eventKind,
      latestFailure: latestFailure,
      restart:
          await _restartProjection(record, latestEventOverride: latestEvent),
    );
  }

  Future<VirtualStreamRestartProjection> _restartProjection(
    StoredVirtualMediaStreamRecord record, {
    StoredVirtualStreamEventRecord? latestEventOverride,
  }) async {
    final StoredVirtualStreamEventRecord? latestEvent =
        latestEventOverride ?? await _streamStore.latestEvent(record.id);

    if (record.lifecycleState ==
        StoredVirtualMediaStreamLifecycleState.failed) {
      return VirtualStreamRestartProjection(
        streamId: VirtualMediaStreamId(record.id),
        disposition: VirtualStreamRestartDisposition.failed,
        requiresTaskReconciliation: false,
        reason: record.message ?? latestEvent?.message,
      );
    }
    if (record.lifecycleState ==
        StoredVirtualMediaStreamLifecycleState.closed) {
      return VirtualStreamRestartProjection(
        streamId: VirtualMediaStreamId(record.id),
        disposition: VirtualStreamRestartDisposition.closed,
        requiresTaskReconciliation: false,
      );
    }

    final StoredBtTaskRecord? task =
        await _btTaskStore.findTaskById(record.taskId);
    if (task == null ||
        task.lifecycleState == StoredBtTaskLifecycleState.removed) {
      return VirtualStreamRestartProjection(
        streamId: VirtualMediaStreamId(record.id),
        disposition: VirtualStreamRestartDisposition.missingTask,
        requiresTaskReconciliation: true,
        reason: 'BT task ${record.taskId} is unavailable for restart.',
      );
    }

    final StoredBtTaskMetadataRecord? metadata =
        await _btTaskStore.metadataFor(record.taskId);
    final StoredBtTaskFileRecord? file = _runtimeFileFor(
      await _btTaskStore.filesFor(record.taskId),
      record.fileIndex,
    );
    if (metadata == null ||
        file == null ||
        file.selectionState == StoredBtFileSelectionState.skipped) {
      return VirtualStreamRestartProjection(
        streamId: VirtualMediaStreamId(record.id),
        disposition: VirtualStreamRestartDisposition.incomplete,
        requiresTaskReconciliation: true,
        reason: 'Persisted BT task data is incomplete for ${record.id}.',
      );
    }

    if (latestEvent?.eventKind == StoredVirtualStreamEventKind.rangeFailed) {
      return VirtualStreamRestartProjection(
        streamId: VirtualMediaStreamId(record.id),
        disposition: VirtualStreamRestartDisposition.rangeFailed,
        requiresTaskReconciliation: true,
        reason: latestEvent?.message,
      );
    }

    return VirtualStreamRestartProjection(
      streamId: VirtualMediaStreamId(record.id),
      disposition: VirtualStreamRestartDisposition.active,
      requiresTaskReconciliation: true,
    );
  }

  VirtualMediaStreamRuntimeFailure? _lifecycleMutationFailure(
    StoredVirtualMediaStreamRecord record,
  ) {
    return switch (record.lifecycleState) {
      StoredVirtualMediaStreamLifecycleState.closed =>
        const VirtualMediaStreamRuntimeFailure(
          kind: VirtualMediaStreamRuntimeFailureKind.streamClosed,
          message: 'Virtual stream is already closed.',
        ),
      StoredVirtualMediaStreamLifecycleState.failed =>
        VirtualMediaStreamRuntimeFailure(
          kind: VirtualMediaStreamRuntimeFailureKind.streamFailed,
          message: record.message ?? 'Virtual stream has already failed.',
        ),
      StoredVirtualMediaStreamLifecycleState.active => null,
    };
  }

  VirtualMediaStreamRuntimeFailure? _latestFailure(
    StoredVirtualMediaStreamRecord record,
    StoredVirtualStreamEventRecord? latestEvent,
  ) {
    if (record.lifecycleState ==
        StoredVirtualMediaStreamLifecycleState.failed) {
      return VirtualMediaStreamRuntimeFailure(
        kind: VirtualMediaStreamRuntimeFailureKind.streamFailed,
        message:
            record.message ?? latestEvent?.message ?? 'Virtual stream failed.',
      );
    }
    if (latestEvent?.eventKind == StoredVirtualStreamEventKind.rangeFailed) {
      return VirtualMediaStreamRuntimeFailure(
        kind: VirtualMediaStreamRuntimeFailureKind.rangeUnavailable,
        message: latestEvent?.message ?? 'Virtual stream range is unavailable.',
      );
    }
    return null;
  }

  VirtualMediaStreamRuntimeFailure _mapFailure(
      VirtualMediaStreamFailure failure) {
    return VirtualMediaStreamRuntimeFailure(
      kind: switch (failure.kind) {
        VirtualMediaStreamFailureKind.taskUnavailable =>
          VirtualMediaStreamRuntimeFailureKind.taskUnavailable,
        VirtualMediaStreamFailureKind.metadataUnavailable =>
          VirtualMediaStreamRuntimeFailureKind.metadataUnavailable,
        VirtualMediaStreamFailureKind.fileUnavailable =>
          VirtualMediaStreamRuntimeFailureKind.fileUnavailable,
        VirtualMediaStreamFailureKind.fileSkipped =>
          VirtualMediaStreamRuntimeFailureKind.fileSkipped,
        VirtualMediaStreamFailureKind.rangeUnavailable =>
          VirtualMediaStreamRuntimeFailureKind.rangeUnavailable,
        VirtualMediaStreamFailureKind.timeout =>
          VirtualMediaStreamRuntimeFailureKind.unavailable,
        VirtualMediaStreamFailureKind.cancelled =>
          VirtualMediaStreamRuntimeFailureKind.unavailable,
        VirtualMediaStreamFailureKind.taskFailed =>
          VirtualMediaStreamRuntimeFailureKind.taskFailed,
        VirtualMediaStreamFailureKind.streamClosed =>
          VirtualMediaStreamRuntimeFailureKind.streamClosed,
        VirtualMediaStreamFailureKind.streamFailed =>
          VirtualMediaStreamRuntimeFailureKind.streamFailed,
        VirtualMediaStreamFailureKind.streamUnavailable =>
          VirtualMediaStreamRuntimeFailureKind.streamUnavailable,
        VirtualMediaStreamFailureKind.unavailable =>
          VirtualMediaStreamRuntimeFailureKind.unavailable,
        VirtualMediaStreamFailureKind.disposed =>
          VirtualMediaStreamRuntimeFailureKind.disposed,
      },
      message: failure.message,
    );
  }
}

DateTime _defaultVirtualStreamRuntimeClock() => DateTime.now().toUtc();

StoredBtTaskFileRecord? _runtimeFileFor(
  Iterable<StoredBtTaskFileRecord> files,
  int fileIndex,
) {
  for (final StoredBtTaskFileRecord file in files) {
    if (file.index == fileIndex) return file;
  }
  return null;
}
