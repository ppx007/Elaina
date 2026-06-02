import '../foundation/storage/storage_contracts.dart';
import 'bt_task_core.dart';

final class VirtualMediaStreamId {
  const VirtualMediaStreamId(this.value) : assert(value != '', 'Virtual media stream id must not be empty.');

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
  const VirtualByteRangeRequest({required this.streamId, required this.range, this.timeout});

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
  metadataUnavailable,
  rangeUnavailable,
  timeout,
  cancelled,
  taskFailed,
}

final class VirtualMediaStreamFailure implements Exception {
  const VirtualMediaStreamFailure({required this.kind, required this.message});

  final VirtualMediaStreamFailureKind kind;
  final String message;
}

final class StreamBufferedRange {
  const StreamBufferedRange({required this.mediaId, required this.range});

  final String mediaId;
  final BufferedRange range;
}

abstract interface class VirtualMediaStream {
  VirtualMediaStreamDescriptor get descriptor;

  Future<void> ensureRange(VirtualByteRangeRequest request);

  Stream<VirtualByteRangeChunk> openRange(VirtualByteRangeRequest request);

  Future<List<StreamBufferedRange>> bufferedRanges();
}

abstract interface class VirtualMediaStreamRegistry {
  Future<VirtualMediaStreamDescriptor> createForFile({required BtTaskId taskId, required BtFileIndex fileIndex});

  Future<VirtualMediaStream?> streamFor(VirtualMediaStreamId streamId);
}
