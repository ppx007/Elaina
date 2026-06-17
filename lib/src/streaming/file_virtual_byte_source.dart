import 'dart:io';

import '../foundation/storage/storage_contracts.dart';
import 'bt_task_core.dart';
import 'virtual_media_stream.dart';

const int defaultVirtualFileByteChunkSizeBytes = 64 * 1024;

final class FileVirtualByteSource implements VirtualByteRangeSource {
  const FileVirtualByteSource({
    this.chunkSizeBytes = defaultVirtualFileByteChunkSizeBytes,
  }) : assert(chunkSizeBytes > 0, 'chunkSizeBytes must be positive.');

  final int chunkSizeBytes;

  @override
  Future<VirtualRangeEnsureOutcome> ensureRange({
    required VirtualMediaStreamDescriptor descriptor,
    required VirtualByteRangeRequest request,
  }) async {
    final File? file = _fileFor(descriptor);
    if (file == null) {
      return VirtualRangeEnsureOutcome.failure(
        failure: _failure(
          VirtualMediaStreamFailureKind.fileUnavailable,
          'Virtual stream ${descriptor.id.value} does not point to a file URI.',
        ),
      );
    }
    try {
      if (!await file.exists()) {
        return VirtualRangeEnsureOutcome.failure(
          failure: _failure(
            VirtualMediaStreamFailureKind.fileUnavailable,
            'Virtual stream file is unavailable.',
          ),
        );
      }
      final int lengthBytes = await file.length();
      if (request.range.endInclusive >= lengthBytes) {
        return VirtualRangeEnsureOutcome.failure(
          failure: _failure(
            VirtualMediaStreamFailureKind.rangeUnavailable,
            'Requested range exceeds virtual stream file length.',
          ),
        );
      }
      return VirtualRangeEnsureOutcome.success(
        availability: VirtualRangeAvailability(
          streamId: request.streamId,
          range: request.range,
          available: true,
        ),
      );
    } on FileSystemException {
      return VirtualRangeEnsureOutcome.failure(
        failure: _failure(
          VirtualMediaStreamFailureKind.fileUnavailable,
          'Virtual stream file is unavailable.',
        ),
      );
    }
  }

  @override
  Stream<VirtualByteRangeChunk> openRange({
    required VirtualMediaStreamDescriptor descriptor,
    required VirtualByteRangeRequest request,
  }) async* {
    final VirtualRangeEnsureOutcome ensured =
        await ensureRange(descriptor: descriptor, request: request);
    if (!ensured.isSuccess) throw ensured.failure!;

    final File file = _fileFor(descriptor)!;
    RandomAccessFile? handle;
    try {
      handle = await file.open();
      await handle.setPosition(request.range.start);
      var nextByte = request.range.start;
      var remainingBytes = request.range.length;
      while (remainingBytes > 0) {
        final int bytesToRead =
            remainingBytes < chunkSizeBytes ? remainingBytes : chunkSizeBytes;
        final List<int> bytes = await handle.read(bytesToRead);
        if (bytes.isEmpty) {
          throw _failure(
            VirtualMediaStreamFailureKind.rangeUnavailable,
            'Virtual stream file ended before the requested range.',
          );
        }
        final int chunkStart = nextByte;
        nextByte += bytes.length;
        remainingBytes -= bytes.length;
        yield VirtualByteRangeChunk(
          range: BtByteRange(
            start: chunkStart,
            endInclusive: nextByte - 1,
          ),
          bytes: bytes,
        );
      }
    } on FileSystemException {
      throw _failure(
        VirtualMediaStreamFailureKind.fileUnavailable,
        'Virtual stream file is unavailable.',
      );
    } finally {
      await handle?.close();
    }
  }

  File? _fileFor(VirtualMediaStreamDescriptor descriptor) {
    final Uri? uri = descriptor.contentUri;
    if (uri == null || !uri.isScheme('file')) return null;
    return File(uri.toFilePath());
  }
}

Uri? fileVirtualStreamContentUriResolver({
  required VirtualMediaStreamId streamId,
  required BtTaskId taskId,
  required BtFileIndex fileIndex,
  required StoredBtTaskFileRecord file,
}) {
  final Uri? uri = Uri.tryParse(file.path);
  if (uri == null || !uri.isScheme('file')) return null;
  return uri;
}

VirtualMediaStreamFailure _failure(
  VirtualMediaStreamFailureKind kind,
  String message,
) {
  return VirtualMediaStreamFailure(kind: kind, message: message);
}
