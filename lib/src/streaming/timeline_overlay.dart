import 'bt_task_core.dart';
import 'virtual_media_stream.dart';

final class TimelineTimeRange {
  const TimelineTimeRange({required this.start, required this.end})
      : assert(start >= Duration.zero, 'Timeline start must not be negative.'),
        assert(end >= start, 'Timeline end must be greater than or equal to start.');

  final Duration start;
  final Duration end;
}

final class TimelineByteRange {
  const TimelineByteRange({required this.streamId, required this.range});

  final VirtualMediaStreamId streamId;
  final BtByteRange range;
}

enum TimelinePieceState {
  missing,
  requested,
  buffered,
  verified,
}

final class TimelinePieceSegment {
  const TimelinePieceSegment({required this.pieceIndex, required this.state, this.byteRange});

  final BtPieceIndex pieceIndex;
  final TimelinePieceState state;
  final TimelineByteRange? byteRange;
}

enum TimelineOverlayLayerKind {
  playbackProgress,
  bufferedRanges,
  pieceMap,
  marker,
  heat,
}

final class TimelineOverlayLayer {
  const TimelineOverlayLayer({
    required this.id,
    required this.kind,
    required this.visible,
    required this.order,
  })  : assert(id != '', 'Timeline overlay layer id must not be empty.'),
        assert(order >= 0, 'Timeline overlay layer order must not be negative.');

  final String id;
  final TimelineOverlayLayerKind kind;
  final bool visible;
  final int order;
}

final class TimelineMarker {
  const TimelineMarker({required this.id, required this.position, required this.label})
      : assert(id != '', 'Timeline marker id must not be empty.'),
        assert(label != '', 'Timeline marker label must not be empty.');

  final String id;
  final Duration position;
  final String label;
}

final class TimelineOverlaySnapshot {
  const TimelineOverlaySnapshot({
    required this.streamId,
    required this.duration,
    required this.position,
    required this.buffered,
    required this.pieces,
    required this.layers,
    this.markers = const <TimelineMarker>[],
  })  : assert(duration >= Duration.zero, 'Timeline duration must not be negative.'),
        assert(position >= Duration.zero, 'Timeline position must not be negative.');

  final VirtualMediaStreamId streamId;
  final Duration duration;
  final Duration position;
  final List<TimelineTimeRange> buffered;
  final List<TimelinePieceSegment> pieces;
  final List<TimelineOverlayLayer> layers;
  final List<TimelineMarker> markers;
}

abstract interface class TimelineOverlaySource {
  Stream<TimelineOverlaySnapshot> watch(VirtualMediaStreamId streamId);
}
