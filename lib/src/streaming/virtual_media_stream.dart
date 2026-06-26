import 'dart:async';

import '../foundation/cache_invalidation/cache_invalidation_bus.dart';
import '../foundation/storage/storage_contracts.dart';
import 'bt_task_core.dart';

/// Private URI scheme used to hand a virtual stream to playback adapters.
///
/// The scheme marks an app-owned byte source, not a network URL. Playback
/// adapters must resolve it through the registry instead of opening it directly.
const String virtualMediaStreamUriScheme = 'elaina-virtual-stream';

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

typedef VirtualStreamContentUriResolver = FutureOr<Uri?> Function({
  required VirtualMediaStreamId streamId,
  required BtTaskId taskId,
  required BtFileIndex fileIndex,
  required StoredBtTaskFileRecord file,
});

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

/// Source of byte ranges for a virtual media stream.
///
/// Implementations may read from files, BT pieces, or future caches; the stream
/// contract only cares whether a requested range is actually available.
abstract interface class VirtualByteRangeSource {
  Future<VirtualRangeEnsureOutcome> ensureRange({
    required VirtualMediaStreamDescriptor descriptor,
    required VirtualByteRangeRequest request,
  });

  Stream<VirtualByteRangeChunk> openRange({
    required VirtualMediaStreamDescriptor descriptor,
    required VirtualByteRangeRequest request,
  });
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
    VirtualStreamContentUriResolver? contentUriResolver,
    this.byteSource,
    DateTime Function()? clock,
  })  : _contentUriResolver = contentUriResolver ?? _defaultContentUri,
        _clock = clock ?? _defaultClock;

  final BtTaskStore btTaskStore;
  final VirtualMediaStreamStore streamStore;
  final CacheInvalidationBus? cacheInvalidationBus;
  final VirtualByteRangeSource? byteSource;
  final VirtualStreamContentUriResolver _contentUriResolver;
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

    final VirtualMediaStreamId streamId = _streamId(taskId, fileIndex);
    final Uri contentUri = await _resolveContentUri(
      streamId: streamId,
      taskId: taskId,
      fileIndex: fileIndex,
      file: file,
    );
    final StoredVirtualMediaStreamRecord stream =
        StoredVirtualMediaStreamRecord(
      id: streamId.value,
      taskId: taskId.value,
      fileIndex: fileIndex.value,
      lengthBytes: file.lengthBytes,
      lifecycleState: StoredVirtualMediaStreamLifecycleState.active,
      createdAt: _clock(),
      updatedAt: _clock(),
      contentUri: contentUri,
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

  Future<Uri> _resolveContentUri({
    required VirtualMediaStreamId streamId,
    required BtTaskId taskId,
    required BtFileIndex fileIndex,
    required StoredBtTaskFileRecord file,
  }) async {
    return await _contentUriResolver(
          streamId: streamId,
          taskId: taskId,
          fileIndex: fileIndex,
          file: file,
        ) ??
        _defaultContentUri(
          streamId: streamId,
          taskId: taskId,
          fileIndex: fileIndex,
          file: file,
        );
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
      byteSource: byteSource,
      clock: _clock,
    );
  }
}

/// Deterministic stream that records lifecycle and buffered ranges.
///
/// It intentionally models byte availability without background networking so
/// scheduler/runtime tests can assert range decisions deterministically.
final class DeterministicVirtualMediaStream implements VirtualMediaStream {
  DeterministicVirtualMediaStream({
    required this.descriptor,
    required this.store,
    this.cacheInvalidationBus,
    this.byteSource,
    DateTime Function()? clock,
  }) : _clock = clock ?? _defaultClock;

  @override
  final VirtualMediaStreamDescriptor descriptor;
  final VirtualMediaStreamStore store;
  final CacheInvalidationBus? cacheInvalidationBus;
  final VirtualByteRangeSource? byteSource;
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
          failure: _failure(
              VirtualMediaStreamFailureKind.streamFailed,
              stream.message ??
                  'Virtual stream ${descriptor.id.value} failed.'));
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
    final VirtualByteRangeSource? source = byteSource;
    if (source != null) {
      final VirtualRangeEnsureOutcome sourceOutcome =
          await source.ensureRange(descriptor: descriptor, request: request);
      if (!sourceOutcome.isSuccess) {
        await _recordRangeFailure(request, sourceOutcome.failure!);
        return sourceOutcome;
      }
    }
    await _recordRangeBuffered(request.range);
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
    final VirtualByteRangeSource? source = byteSource;
    if (source == null) {
      final VirtualMediaStreamFailure failure = _failure(
        VirtualMediaStreamFailureKind.rangeUnavailable,
        'Virtual byte range source is not configured.',
      );
      await _recordRangeFailure(request, failure);
      throw failure;
    }
    try {
      Stream<VirtualByteRangeChunk> chunks =
          source.openRange(descriptor: descriptor, request: request);
      // Honor the request's optional per-chunk timeout: if no chunk arrives
      // within the window, surface the typed `timeout` failure.
      final Duration? timeout = request.timeout;
      if (timeout != null) {
        chunks = chunks.timeout(
          timeout,
          onTimeout: (EventSink<VirtualByteRangeChunk> sink) {
            sink.addError(_failure(
              VirtualMediaStreamFailureKind.timeout,
              'Virtual byte range timed out after ${timeout.inMilliseconds}ms.',
            ));
          },
        );
      }
      await for (final VirtualByteRangeChunk chunk in chunks) {
        yield chunk;
      }
      await _recordRangeBuffered(request.range);
    } on VirtualMediaStreamFailure catch (failure) {
      await _recordRangeFailure(request, failure);
      throw failure;
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

  Future<void> _recordRangeBuffered(BtByteRange range) async {
    await store.recordBufferedRange(StoredVirtualStreamBufferedRangeRecord(
      streamId: descriptor.id.value,
      startByte: range.start,
      endByte: range.endInclusive,
      observedAt: _clock(),
    ));
    await store.recordEvent(StoredVirtualStreamEventRecord(
      streamId: descriptor.id.value,
      eventKind: StoredVirtualStreamEventKind.rangeBuffered,
      occurredAt: _clock(),
      rangeStart: range.start,
      rangeEnd: range.endInclusive,
    ));
    cacheInvalidationBus?.publish(VirtualStreamRangeBuffered(
      occurredAt: _clock(),
      streamId: descriptor.id.value,
      startByte: range.start,
      endByte: range.endInclusive,
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

Uri _defaultContentUri({
  required VirtualMediaStreamId streamId,
  required BtTaskId taskId,
  required BtFileIndex fileIndex,
  required StoredBtTaskFileRecord file,
}) {
  return Uri.parse(
      '$virtualMediaStreamUriScheme://${Uri.encodeComponent(streamId.value)}');
}

VirtualMediaStreamId _streamId(BtTaskId taskId, BtFileIndex fileIndex) {
  return VirtualMediaStreamId('${taskId.value}::${fileIndex.value}');
}
