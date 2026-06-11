import '../foundation/cache_invalidation/cache_invalidation_bus.dart';
import '../foundation/storage/storage_contracts.dart';
import 'bt_task_core.dart';

final class VirtualMediaStreamId {
  const VirtualMediaStreamId(this.value)
      : assert(value != '', 'Virtual media stream id must not be empty.');

  final String value;
}

final class VirtualMediaStreamDescriptor {
  const VirtualMediaStreamDescriptor({
    required this.id,
    required this.taskId,
    required this.fileIndex,
    required this.lengthBytes,
    this.contentUri,
    this.mimeType,
  }) : assert(lengthBytes >= 0, 'lengthBytes must not be negative.');

  final VirtualMediaStreamId id;
  final BtTaskId taskId;
  final BtFileIndex fileIndex;
  final int lengthBytes;
  final Uri? contentUri;
  final String? mimeType;
}

final class VirtualByteRangeRequest {
  const VirtualByteRangeRequest({
    required this.streamId,
    required this.range,
    this.timeout,
  });

  final VirtualMediaStreamId streamId;
  final BtByteRange range;
  final Duration? timeout;
}

final class VirtualByteRangeChunk {
  const VirtualByteRangeChunk({required this.range, required this.bytes})
      : assert(bytes.length > 0, 'Virtual byte range chunk must not be empty.');

  final BtByteRange range;
  final List<int> bytes;
}

enum VirtualMediaStreamFailureKind {
  taskUnavailable,
  metadataUnavailable,
  fileUnavailable,
  fileSkipped,
  streamUnavailable,
  rangeUnavailable,
  timeout,
  cancelled,
  unavailable,
  disposed,
  taskFailed,
  streamClosed,
  streamFailed,
}

final class VirtualMediaStreamFailure implements Exception {
  const VirtualMediaStreamFailure({required this.kind, required this.message});

  final VirtualMediaStreamFailureKind kind;
  final String message;
}

enum VirtualMediaStreamLifecycleState {
  active,
  closed,
  failed,
}

final class StreamBufferedRange {
  const StreamBufferedRange({required this.mediaId, required this.range});

  final String mediaId;
  final BufferedRange range;
}

final class VirtualMediaStreamCreateRequest {
  const VirtualMediaStreamCreateRequest({
    required this.taskId,
    required this.fileIndex,
  });

  final BtTaskId taskId;
  final BtFileIndex fileIndex;
}

final class VirtualMediaStreamCreateOutcome {
  const VirtualMediaStreamCreateOutcome._({this.descriptor, this.failure});

  const VirtualMediaStreamCreateOutcome.success(
      {required VirtualMediaStreamDescriptor descriptor})
      : this._(descriptor: descriptor);

  const VirtualMediaStreamCreateOutcome.failure(
      {required VirtualMediaStreamFailure failure})
      : this._(failure: failure);

  final VirtualMediaStreamDescriptor? descriptor;
  final VirtualMediaStreamFailure? failure;

  bool get isSuccess => failure == null;
}

final class VirtualRangeAvailability {
  const VirtualRangeAvailability({
    required this.streamId,
    required this.range,
    required this.available,
  });

  final VirtualMediaStreamId streamId;
  final BtByteRange range;
  final bool available;
}

final class VirtualRangeEnsureOutcome {
  const VirtualRangeEnsureOutcome._({this.availability, this.failure});

  const VirtualRangeEnsureOutcome.success(
      {required VirtualRangeAvailability availability})
      : this._(availability: availability);

  const VirtualRangeEnsureOutcome.failure(
      {required VirtualMediaStreamFailure failure})
      : this._(failure: failure);

  final VirtualRangeAvailability? availability;
  final VirtualMediaStreamFailure? failure;

  bool get isSuccess => failure == null;
}

final class VirtualStreamCommandOutcome {
  const VirtualStreamCommandOutcome._({this.failure});

  const VirtualStreamCommandOutcome.success() : this._();

  const VirtualStreamCommandOutcome.failure(
      {required VirtualMediaStreamFailure failure})
      : this._(failure: failure);

  final VirtualMediaStreamFailure? failure;

  bool get isSuccess => failure == null;
}

abstract interface class VirtualMediaStream {
  VirtualMediaStreamDescriptor get descriptor;

  Future<VirtualRangeEnsureOutcome> ensureRange(
      VirtualByteRangeRequest request);

  Stream<VirtualByteRangeChunk> openRange(VirtualByteRangeRequest request);

  Future<List<StreamBufferedRange>> bufferedRanges();

  Future<VirtualStreamCommandOutcome> close();
}

abstract interface class VirtualMediaStreamRegistry {
  Future<VirtualMediaStreamCreateOutcome> createForFile({
    required BtTaskId taskId,
    required BtFileIndex fileIndex,
  });

  Future<VirtualMediaStream?> streamFor(VirtualMediaStreamId streamId);
}

final class DeterministicVirtualMediaStreamRegistry
    implements VirtualMediaStreamRegistry {
  DeterministicVirtualMediaStreamRegistry({
    required this.btTaskStore,
    required this.streamStore,
    this.cacheInvalidationBus,
    DateTime Function()? clock,
  }) : _clock = clock ?? _defaultClock;

  final BtTaskStore btTaskStore;
  final VirtualMediaStreamStore streamStore;
  final CacheInvalidationBus? cacheInvalidationBus;
  final DateTime Function() _clock;

  @override
  Future<VirtualMediaStreamCreateOutcome> createForFile({
    required BtTaskId taskId,
    required BtFileIndex fileIndex,
  }) async {
    final StoredBtTaskRecord? task =
        await btTaskStore.findTaskById(taskId.value);
    if (task == null) {
      return VirtualMediaStreamCreateOutcome.failure(
          failure: _failure(VirtualMediaStreamFailureKind.taskUnavailable,
              'BT task ${taskId.value} was not found.'));
    }
    if (task.lifecycleState == StoredBtTaskLifecycleState.failed ||
        task.lifecycleState == StoredBtTaskLifecycleState.removed) {
      return VirtualMediaStreamCreateOutcome.failure(
          failure: _failure(VirtualMediaStreamFailureKind.taskFailed,
              'BT task ${taskId.value} is not streamable.'));
    }
    final StoredBtTaskMetadataRecord? metadata =
        await btTaskStore.metadataFor(taskId.value);
    if (metadata == null) {
      return VirtualMediaStreamCreateOutcome.failure(
          failure: _failure(VirtualMediaStreamFailureKind.metadataUnavailable,
              'BT task ${taskId.value} metadata is unavailable.'));
    }
    final List<StoredBtTaskFileRecord> files =
        await btTaskStore.filesFor(taskId.value);
    final StoredBtTaskFileRecord? file = _fileFor(files, fileIndex.value);
    if (file == null) {
      return VirtualMediaStreamCreateOutcome.failure(
          failure: _failure(VirtualMediaStreamFailureKind.fileUnavailable,
               'BT task ${taskId.value} file ${fileIndex.value} is unavailable.'));
    }
    if (file.selectionState == StoredBtFileSelectionState.skipped) {
      return VirtualMediaStreamCreateOutcome.failure(
          failure: _failure(VirtualMediaStreamFailureKind.fileSkipped,
              'BT task ${taskId.value} file ${fileIndex.value} was skipped.'));
    }

    final StoredVirtualMediaStreamRecord? existing =
        await streamStore.findStreamForTaskFile(
            taskId: taskId.value, fileIndex: fileIndex.value);
    if (existing != null &&
        existing.lifecycleState ==
            StoredVirtualMediaStreamLifecycleState.active) {
      return VirtualMediaStreamCreateOutcome.success(
          descriptor: _descriptorFromRecord(existing));
    }

    final StoredVirtualMediaStreamRecord stream =
        StoredVirtualMediaStreamRecord(
      id: _streamId(taskId, fileIndex).value,
      taskId: taskId.value,
      fileIndex: fileIndex.value,
      lengthBytes: file.lengthBytes,
      lifecycleState: StoredVirtualMediaStreamLifecycleState.active,
      createdAt: _clock(),
      updatedAt: _clock(),
      contentUri: _contentUri(_streamId(taskId, fileIndex)),
      mimeType: file.mediaMimeType,
    );
    await streamStore.storeStream(stream);
    await streamStore.recordEvent(StoredVirtualStreamEventRecord(
      streamId: stream.id,
      eventKind: StoredVirtualStreamEventKind.created,
      occurredAt: _clock(),
    ));
    cacheInvalidationBus?.publish(VirtualStreamCreated(
      occurredAt: _clock(),
      streamId: stream.id,
      taskId: taskId.value,
      fileIndex: fileIndex.value,
    ));
    return VirtualMediaStreamCreateOutcome.success(
        descriptor: _descriptorFromRecord(stream));
  }

  @override
  Future<VirtualMediaStream?> streamFor(VirtualMediaStreamId streamId) async {
    final StoredVirtualMediaStreamRecord? stream =
        await streamStore.findStreamById(streamId.value);
    if (stream == null) {
      return null;
    }
    return DeterministicVirtualMediaStream(
      descriptor: _descriptorFromRecord(stream),
      store: streamStore,
      cacheInvalidationBus: cacheInvalidationBus,
      clock: _clock,
    );
  }
}

final class DeterministicVirtualMediaStream implements VirtualMediaStream {
  DeterministicVirtualMediaStream({
    required this.descriptor,
    required this.store,
    this.cacheInvalidationBus,
    DateTime Function()? clock,
  }) : _clock = clock ?? _defaultClock;

  @override
  final VirtualMediaStreamDescriptor descriptor;
  final VirtualMediaStreamStore store;
  final CacheInvalidationBus? cacheInvalidationBus;
  final DateTime Function() _clock;

  @override
  Future<List<StreamBufferedRange>> bufferedRanges() async {
    final List<StoredVirtualStreamBufferedRangeRecord> records =
        await store.bufferedRangesFor(descriptor.id.value);
    return <StreamBufferedRange>[
      for (final StoredVirtualStreamBufferedRangeRecord record in records)
        StreamBufferedRange(
          mediaId: descriptor.id.value,
          range: BufferedRange(
            startByte: record.startByte,
            endByte: record.endByte,
          ),
        ),
    ];
  }

  @override
  Future<VirtualStreamCommandOutcome> close() async {
    final StoredVirtualMediaStreamRecord? stream =
        await store.findStreamById(descriptor.id.value);
    if (stream == null) {
      return VirtualStreamCommandOutcome.failure(
          failure: _failure(VirtualMediaStreamFailureKind.streamUnavailable,
              'Virtual stream ${descriptor.id.value} was not found.'));
    }
    if (stream.lifecycleState ==
        StoredVirtualMediaStreamLifecycleState.closed) {
      return VirtualStreamCommandOutcome.failure(
          failure: _failure(VirtualMediaStreamFailureKind.streamClosed,
              'Virtual stream ${descriptor.id.value} is already closed.'));
    }
    if (stream.lifecycleState ==
        StoredVirtualMediaStreamLifecycleState.failed) {
      return VirtualStreamCommandOutcome.failure(
          failure: _failure(VirtualMediaStreamFailureKind.streamFailed,
              stream.message ?? 'Virtual stream ${descriptor.id.value} failed.'));
    }
    await store.storeStream(stream.copyWith(
      lifecycleState: StoredVirtualMediaStreamLifecycleState.closed,
      updatedAt: _clock(),
    ));
    await store.recordEvent(StoredVirtualStreamEventRecord(
      streamId: descriptor.id.value,
      eventKind: StoredVirtualStreamEventKind.closed,
      occurredAt: _clock(),
    ));
    cacheInvalidationBus?.publish(VirtualStreamClosed(
        occurredAt: _clock(), streamId: descriptor.id.value));
    return const VirtualStreamCommandOutcome.success();
  }

  @override
  Future<VirtualRangeEnsureOutcome> ensureRange(
      VirtualByteRangeRequest request) async {
    if (request.streamId.value != descriptor.id.value) {
      return VirtualRangeEnsureOutcome.failure(
          failure: _failure(VirtualMediaStreamFailureKind.rangeUnavailable,
              'Range request targets a different virtual stream.'));
    }
    final VirtualMediaStreamFailure? unavailable = await _rangeFailure(request);
    if (unavailable != null) {
      await _recordRangeFailure(request, unavailable);
      return VirtualRangeEnsureOutcome.failure(failure: unavailable);
    }
    await store.recordBufferedRange(StoredVirtualStreamBufferedRangeRecord(
      streamId: descriptor.id.value,
      startByte: request.range.start,
      endByte: request.range.endInclusive,
      observedAt: _clock(),
    ));
    await store.recordEvent(StoredVirtualStreamEventRecord(
      streamId: descriptor.id.value,
      eventKind: StoredVirtualStreamEventKind.rangeBuffered,
      occurredAt: _clock(),
      rangeStart: request.range.start,
      rangeEnd: request.range.endInclusive,
    ));
    cacheInvalidationBus?.publish(VirtualStreamRangeBuffered(
      occurredAt: _clock(),
      streamId: descriptor.id.value,
      startByte: request.range.start,
      endByte: request.range.endInclusive,
    ));
    return VirtualRangeEnsureOutcome.success(
      availability: VirtualRangeAvailability(
        streamId: descriptor.id,
        range: request.range,
        available: true,
      ),
    );
  }

  @override
  Stream<VirtualByteRangeChunk> openRange(
      VirtualByteRangeRequest request) async* {
    final VirtualMediaStreamFailure? unavailable = await _rangeFailure(request);
    if (unavailable != null) {
      await _recordRangeFailure(request, unavailable);
      throw unavailable;
    }
  }

  Future<VirtualMediaStreamFailure?> _rangeFailure(
      VirtualByteRangeRequest request) async {
    if (request.streamId.value != descriptor.id.value) {
      return _failure(VirtualMediaStreamFailureKind.rangeUnavailable,
          'Range request targets a different virtual stream.');
    }
    final StoredVirtualMediaStreamRecord? stream =
        await store.findStreamById(descriptor.id.value);
    if (stream == null) {
      return _failure(VirtualMediaStreamFailureKind.streamUnavailable,
          'Virtual stream ${descriptor.id.value} was not found.');
    }
    if (stream.lifecycleState ==
        StoredVirtualMediaStreamLifecycleState.closed) {
      return _failure(VirtualMediaStreamFailureKind.streamClosed,
          'Virtual stream ${descriptor.id.value} is closed.');
    }
    if (stream.lifecycleState ==
        StoredVirtualMediaStreamLifecycleState.failed) {
      return _failure(VirtualMediaStreamFailureKind.streamFailed,
          stream.message ?? 'Virtual stream ${descriptor.id.value} failed.');
    }
    if (request.range.endInclusive >= descriptor.lengthBytes) {
      return _failure(VirtualMediaStreamFailureKind.rangeUnavailable,
          'Requested range exceeds virtual stream length.');
    }
    return null;
  }

  Future<void> _recordRangeFailure(VirtualByteRangeRequest request,
      VirtualMediaStreamFailure failure) async {
    await store.recordEvent(StoredVirtualStreamEventRecord(
      streamId: descriptor.id.value,
      eventKind: StoredVirtualStreamEventKind.rangeFailed,
      occurredAt: _clock(),
      rangeStart: request.range.start,
      rangeEnd: request.range.endInclusive,
      failureKind: failure.kind.name,
      message: failure.message,
    ));
    cacheInvalidationBus?.publish(VirtualStreamRangeFailed(
      occurredAt: _clock(),
      streamId: descriptor.id.value,
      failureKind: failure.kind.name,
      startByte: request.range.start,
      endByte: request.range.endInclusive,
    ));
  }
}

DateTime _defaultClock() => DateTime.now().toUtc();

VirtualMediaStreamFailure _failure(
    VirtualMediaStreamFailureKind kind, String message) {
  return VirtualMediaStreamFailure(kind: kind, message: message);
}

VirtualMediaStreamDescriptor _descriptorFromRecord(
    StoredVirtualMediaStreamRecord record) {
  return VirtualMediaStreamDescriptor(
    id: VirtualMediaStreamId(record.id),
    taskId: BtTaskId(record.taskId),
    fileIndex: BtFileIndex(record.fileIndex),
    lengthBytes: record.lengthBytes,
    contentUri: record.contentUri,
    mimeType: record.mimeType,
  );
}

StoredBtTaskFileRecord? _fileFor(
    Iterable<StoredBtTaskFileRecord> files, int fileIndex) {
  for (final StoredBtTaskFileRecord file in files) {
    if (file.index == fileIndex) {
      return file;
    }
  }
  return null;
}

Uri _contentUri(VirtualMediaStreamId streamId) {
  return Uri.parse(
      'celesteria-virtual-stream://${Uri.encodeComponent(streamId.value)}');
}

VirtualMediaStreamId _streamId(BtTaskId taskId, BtFileIndex fileIndex) {
  return VirtualMediaStreamId('${taskId.value}::${fileIndex.value}');
}
