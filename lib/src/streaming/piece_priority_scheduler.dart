import 'bt_task_core.dart';
import 'virtual_media_stream.dart';

enum DownloadPriority {
  off,
  low,
  normal,
  high,
  critical,
}

final class PieceSpan {
  const PieceSpan({required this.first, required this.last});

  final BtPieceIndex first;
  final BtPieceIndex last;
}

final class FilePieceMap {
  const FilePieceMap({
    required this.fileIndex,
    required this.fileRange,
    required this.pieceSpan,
    required this.pieceLengthBytes,
  }) : assert(pieceLengthBytes > 0, 'pieceLengthBytes must be positive.');

  final BtFileIndex fileIndex;
  final BtByteRange fileRange;
  final PieceSpan pieceSpan;
  final int pieceLengthBytes;
}

final class PlaybackWindow {
  const PlaybackWindow({
    required this.streamId,
    required this.currentByteOffset,
    required this.lookaheadBytes,
  })  : assert(currentByteOffset >= 0, 'currentByteOffset must not be negative.'),
        assert(lookaheadBytes >= 0, 'lookaheadBytes must not be negative.');

  final VirtualMediaStreamId streamId;
  final int currentByteOffset;
  final int lookaheadBytes;
}

final class SeekTarget {
  const SeekTarget({required this.streamId, required this.targetByteOffset, this.deadline})
      : assert(targetByteOffset >= 0, 'targetByteOffset must not be negative.');

  final VirtualMediaStreamId streamId;
  final int targetByteOffset;
  final Duration? deadline;
}

final class PiecePriorityRule {
  const PiecePriorityRule({required this.pieceIndex, required this.priority, this.deadline});

  final BtPieceIndex pieceIndex;
  final DownloadPriority priority;
  final Duration? deadline;
}

final class PiecePriorityPlan {
  const PiecePriorityPlan({required this.taskId, required this.rules});

  final BtTaskId taskId;
  final List<PiecePriorityRule> rules;
}

final class PiecePriorityStrategyProfile {
  const PiecePriorityStrategyProfile({
    required this.id,
    required this.firstPiecePriority,
    required this.tailPiecePriority,
    required this.playbackWindowPriority,
    required this.seekTargetPriority,
    required this.lookaheadBytes,
  })  : assert(id != '', 'Strategy profile id must not be empty.'),
        assert(lookaheadBytes >= 0, 'lookaheadBytes must not be negative.');

  final String id;
  final DownloadPriority firstPiecePriority;
  final DownloadPriority tailPiecePriority;
  final DownloadPriority playbackWindowPriority;
  final DownloadPriority seekTargetPriority;
  final int lookaheadBytes;
}

abstract interface class PiecePriorityScheduler {
  Future<PiecePriorityPlan> plan({
    required BtTaskMetadata metadata,
    required Iterable<FilePieceMap> filePieceMaps,
    required PiecePriorityStrategyProfile profile,
    PlaybackWindow? playbackWindow,
    SeekTarget? seekTarget,
  });
}

abstract interface class PiecePriorityPlanApplier {
  Future<void> apply(PiecePriorityPlan plan);
}
