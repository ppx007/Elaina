import '../foundation/extension_points.dart';

final class BtTaskId {
  const BtTaskId(this.value) : assert(value != '', 'BT task id must not be empty.');

  final String value;
}

final class InfoHash {
  const InfoHash(this.value) : assert(value != '', 'Info hash must not be empty.');

  final String value;
}

sealed class BtTaskSource {
  const BtTaskSource();
}

final class MagnetBtTaskSource extends BtTaskSource {
  const MagnetBtTaskSource({required this.uri}) : assert(uri != '', 'Magnet URI must not be empty.');

  final String uri;
}

final class TorrentDataBtTaskSource extends BtTaskSource {
  const TorrentDataBtTaskSource({required this.uri});

  final Uri uri;
}

final class BtFileIndex {
  const BtFileIndex(this.value) : assert(value >= 0, 'BT file index must not be negative.');

  final int value;
}

final class BtPieceIndex {
  const BtPieceIndex(this.value) : assert(value >= 0, 'BT piece index must not be negative.');

  final int value;
}

final class BtByteRange {
  const BtByteRange({required this.start, required this.endInclusive})
      : assert(start >= 0, 'Range start must not be negative.'),
        assert(endInclusive >= start, 'Range end must be greater than or equal to start.');

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
    this.mediaMimeType,
  })  : assert(path != '', 'BT file path must not be empty.'),
        assert(lengthBytes >= 0, 'lengthBytes must not be negative.'),
        assert(offsetBytes >= 0, 'offsetBytes must not be negative.');

  final BtFileIndex index;
  final String path;
  final int lengthBytes;
  final int offsetBytes;
  final BtFileSelectionState selectionState;
  final String? mediaMimeType;
}

final class BtTaskMetadata {
  const BtTaskMetadata({
    required this.infoHash,
    required this.name,
    required this.totalSizeBytes,
    required this.pieceLengthBytes,
    required this.files,
  })  : assert(name != '', 'BT metadata name must not be empty.'),
        assert(totalSizeBytes >= 0, 'totalSizeBytes must not be negative.'),
        assert(pieceLengthBytes > 0, 'pieceLengthBytes must be positive.');

  final InfoHash infoHash;
  final String name;
  final int totalSizeBytes;
  final int pieceLengthBytes;
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
  })  : assert(progress >= 0 && progress <= 1, 'progress must be between 0 and 1.'),
        assert(downloadRateBytesPerSecond >= 0, 'download rate must not be negative.'),
        assert(uploadRateBytesPerSecond >= 0, 'upload rate must not be negative.'),
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
  const BtCapabilityMatrix({required Map<BtStreamingCapability, BtCapabilityStatus> capabilities})
      : _capabilities = capabilities;

  factory BtCapabilityMatrix.unsupported({required String reason}) {
    return BtCapabilityMatrix(
      capabilities: <BtStreamingCapability, BtCapabilityStatus>{
        for (final BtStreamingCapability capability in BtStreamingCapability.values)
          capability: BtCapabilityStatus.unsupported(reason),
      },
    );
  }

  final Map<BtStreamingCapability, BtCapabilityStatus> _capabilities;

  BtCapabilityStatus statusOf(BtStreamingCapability capability) {
    return _capabilities[capability] ?? const BtCapabilityStatus.unsupported('Capability is not declared.');
  }
}

final class BtTaskCreateRequest {
  const BtTaskCreateRequest({required this.source, this.initialFileSelections = const <BtFileIndex>[]});

  final BtTaskSource source;
  final List<BtFileIndex> initialFileSelections;
}

abstract interface class DownloadEngineAdapter implements CelesteriaAdapter {
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
