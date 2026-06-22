import '../foundation/cache_invalidation/cache_invalidation_bus.dart';
import 'bt_task_core.dart';
import 'virtual_media_stream.dart';

/// Timeline overlay ranges use both playback time and byte ranges.
///
/// Keeping them separate prevents UI heatmaps from assuming a linear mapping
/// when a container layout or torrent file ordering says otherwise.
final class TimelineTimeRange {
  const TimelineTimeRange({required this.start, required this.end})
      : assert(start >= Duration.zero, 'Timeline start must not be negative.'),
        assert(end >= start,
            'Timeline end must be greater than or equal to start.');

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
  const TimelinePieceSegment(
      {required this.pieceIndex, required this.state, this.byteRange});

  final BtPieceIndex pieceIndex;
  final TimelinePieceState state;
  final TimelineByteRange? byteRange;
}

enum TimelineOverlayLayerKind {
  playbackProgress,
  bufferedRanges,
  pieceMap,
  priorityWindow,
  marker,
  heat,
}

enum TimelineOverlayCompositionFailureKind {
  playbackUnavailable,
  streamUnavailable,
  durationUnavailable,
  positionOutOfRange,
  invalidLayerConfiguration,
}

final class TimelineOverlayCompositionFailure implements Exception {
  const TimelineOverlayCompositionFailure(
      {required this.kind, required this.message});

  final TimelineOverlayCompositionFailureKind kind;
  final String message;
}

final class TimelineOverlayLayer {
  const TimelineOverlayLayer({
    required this.id,
    required this.kind,
    required this.visible,
    required this.order,
  })  : assert(id != '', 'Timeline overlay layer id must not be empty.'),
        assert(
            order >= 0, 'Timeline overlay layer order must not be negative.');

  final String id;
  final TimelineOverlayLayerKind kind;
  final bool visible;
  final int order;
}

final class TimelineMarker {
  const TimelineMarker(
      {required this.id, required this.position, required this.label})
      : assert(id != '', 'Timeline marker id must not be empty.'),
        assert(label != '', 'Timeline marker label must not be empty.');

  final String id;
  final Duration position;
  final String label;
}

final class TimelinePlaybackSnapshot {
  const TimelinePlaybackSnapshot(
      {required this.position, required this.duration})
      : assert(position >= Duration.zero,
            'Playback position must not be negative.'),
        assert(duration >= Duration.zero,
            'Playback duration must not be negative.');

  final Duration position;
  final Duration duration;
}

final class TimelinePriorityWindow {
  const TimelinePriorityWindow({
    required this.id,
    required this.pieceIndex,
    required this.byteRange,
    required this.priority,
    required this.reason,
  })  : assert(id != '', 'Timeline priority window id must not be empty.'),
        assert(priority != '', 'Timeline priority must not be empty.'),
        assert(reason != '', 'Timeline priority reason must not be empty.');

  final String id;
  final BtPieceIndex pieceIndex;
  final TimelineByteRange byteRange;
  final String priority;
  final String reason;
}

final class TimelineHeatValue {
  const TimelineHeatValue(
      {required this.id, required this.range, required this.intensity})
      : assert(id != '', 'Timeline heat id must not be empty.'),
        assert(intensity >= 0 && intensity <= 1,
            'Timeline heat intensity must be between 0 and 1.');

  final String id;
  final TimelineTimeRange range;
  final double intensity;
}

final class TimelineOverlaySnapshot {
  const TimelineOverlaySnapshot({
    required this.streamId,
    required this.duration,
    required this.position,
    required this.buffered,
    required this.pieces,
    required this.layers,
    this.priorityWindows = const <TimelinePriorityWindow>[],
    this.markers = const <TimelineMarker>[],
    this.heatValues = const <TimelineHeatValue>[],
    this.composedAt,
  })  : assert(duration >= Duration.zero,
            'Timeline duration must not be negative.'),
        assert(position >= Duration.zero,
            'Timeline position must not be negative.');

  final VirtualMediaStreamId streamId;
  final Duration duration;
  final Duration position;
  final List<TimelineTimeRange> buffered;
  final List<TimelinePieceSegment> pieces;
  final List<TimelineOverlayLayer> layers;
  final List<TimelinePriorityWindow> priorityWindows;
  final List<TimelineMarker> markers;
  final List<TimelineHeatValue> heatValues;
  final DateTime? composedAt;
}

final class TimelineOverlayCompositionInput {
  const TimelineOverlayCompositionInput({
    required this.stream,
    required this.playback,
    this.bufferedRanges = const <StreamBufferedRange>[],
    this.pieces = const <TimelinePieceSegment>[],
    this.priorityWindows = const <TimelinePriorityWindow>[],
    this.markers = const <TimelineMarker>[],
    this.heatValues = const <TimelineHeatValue>[],
    this.layers = const <TimelineOverlayLayer>[],
  });

  final VirtualMediaStreamDescriptor stream;
  final TimelinePlaybackSnapshot playback;
  final List<StreamBufferedRange> bufferedRanges;
  final List<TimelinePieceSegment> pieces;
  final List<TimelinePriorityWindow> priorityWindows;
  final List<TimelineMarker> markers;
  final List<TimelineHeatValue> heatValues;
  final List<TimelineOverlayLayer> layers;
}

final class TimelineOverlayCompositionOutcome {
  const TimelineOverlayCompositionOutcome._({this.snapshot, this.failure});

  const TimelineOverlayCompositionOutcome.success(
      {required TimelineOverlaySnapshot snapshot})
      : this._(snapshot: snapshot);

  const TimelineOverlayCompositionOutcome.failure(
      {required TimelineOverlayCompositionFailure failure})
      : this._(failure: failure);

  final TimelineOverlaySnapshot? snapshot;
  final TimelineOverlayCompositionFailure? failure;

  bool get isSuccess => failure == null;
}

abstract interface class TimelineOverlayComposer {
  TimelineOverlayCompositionOutcome compose(
      TimelineOverlayCompositionInput input);
}

/// Deterministic overlay composer for BT piece state, priority windows, and
/// playback markers. It produces UI-ready snapshots without touching the engine.
final class DeterministicTimelineOverlayComposer
    implements TimelineOverlayComposer {
  DeterministicTimelineOverlayComposer(
      {this.cacheInvalidationBus, DateTime Function()? clock})
      : _clock = clock ?? _defaultClock;

  final CacheInvalidationBus? cacheInvalidationBus;
  final DateTime Function() _clock;

  @override
  TimelineOverlayCompositionOutcome compose(
      TimelineOverlayCompositionInput input) {
    final TimelineOverlayCompositionFailure? failure = _validate(input);
    if (failure != null) {
      cacheInvalidationBus?.publish(TimelineOverlayCompositionRejected(
        occurredAt: _clock(),
        streamId: input.stream.id.value,
        failureKind: failure.kind.name,
      ));
      return TimelineOverlayCompositionOutcome.failure(failure: failure);
    }
    final DateTime composedAt = _clock();
    final TimelineOverlaySnapshot snapshot = TimelineOverlaySnapshot(
      streamId: input.stream.id,
      duration: input.playback.duration,
      position: input.playback.position,
      buffered: _bufferedTimelineRanges(input),
      pieces: input.pieces,
      layers: _orderedLayers(input),
      priorityWindows: input.priorityWindows,
      markers: input.markers,
      heatValues: input.heatValues,
      composedAt: composedAt,
    );
    cacheInvalidationBus?.publish(TimelineOverlaySnapshotRefreshed(
      occurredAt: composedAt,
      streamId: input.stream.id.value,
      layerCount: snapshot.layers.length,
    ));
    return TimelineOverlayCompositionOutcome.success(snapshot: snapshot);
  }

  TimelineOverlayCompositionFailure? _validate(
      TimelineOverlayCompositionInput input) {
    if (input.stream.lengthBytes <= 0) {
      return const TimelineOverlayCompositionFailure(
        kind: TimelineOverlayCompositionFailureKind.streamUnavailable,
        message: 'Timeline overlay requires a stream with positive length.',
      );
    }
    if (input.playback.duration == Duration.zero) {
      return const TimelineOverlayCompositionFailure(
        kind: TimelineOverlayCompositionFailureKind.durationUnavailable,
        message: 'Timeline overlay requires a positive playback duration.',
      );
    }
    if (input.playback.position > input.playback.duration) {
      return const TimelineOverlayCompositionFailure(
        kind: TimelineOverlayCompositionFailureKind.positionOutOfRange,
        message: 'Playback position must not exceed playback duration.',
      );
    }
    final Set<String> layerIds = <String>{};
    for (final TimelineOverlayLayer layer in input.layers) {
      if (!layerIds.add(layer.id)) {
        return TimelineOverlayCompositionFailure(
          kind: TimelineOverlayCompositionFailureKind.invalidLayerConfiguration,
          message: 'Duplicate timeline overlay layer id ${layer.id}.',
        );
      }
    }
    return null;
  }

  List<TimelineTimeRange> _bufferedTimelineRanges(
      TimelineOverlayCompositionInput input) {
    return input.bufferedRanges
        .map((StreamBufferedRange range) => TimelineTimeRange(
              start: _byteOffsetToDuration(range.range.startByte, input),
              end: _byteOffsetToDuration(range.range.endByte + 1, input),
            ))
        .toList(growable: false);
  }

  Duration _byteOffsetToDuration(
      int byteOffset, TimelineOverlayCompositionInput input) {
    final int clamped = byteOffset.clamp(0, input.stream.lengthBytes).toInt();
    final int micros = (input.playback.duration.inMicroseconds * clamped) ~/
        input.stream.lengthBytes;
    return Duration(microseconds: micros);
  }

  List<TimelineOverlayLayer> _orderedLayers(
      TimelineOverlayCompositionInput input) {
    final List<TimelineOverlayLayer> layers = input.layers.isEmpty
        ? _defaultLayers(input)
        : <TimelineOverlayLayer>[...input.layers];
    layers.sort((TimelineOverlayLayer left, TimelineOverlayLayer right) =>
        left.order.compareTo(right.order));
    return layers;
  }

  List<TimelineOverlayLayer> _defaultLayers(
      TimelineOverlayCompositionInput input) {
    return <TimelineOverlayLayer>[
      const TimelineOverlayLayer(
          id: 'playback-progress',
          kind: TimelineOverlayLayerKind.playbackProgress,
          visible: true,
          order: 0),
      if (input.bufferedRanges.isNotEmpty)
        const TimelineOverlayLayer(
            id: 'buffered-ranges',
            kind: TimelineOverlayLayerKind.bufferedRanges,
            visible: true,
            order: 1),
      if (input.pieces.isNotEmpty)
        const TimelineOverlayLayer(
            id: 'piece-map',
            kind: TimelineOverlayLayerKind.pieceMap,
            visible: true,
            order: 2),
      if (input.priorityWindows.isNotEmpty)
        const TimelineOverlayLayer(
            id: 'priority-windows',
            kind: TimelineOverlayLayerKind.priorityWindow,
            visible: true,
            order: 3),
      if (input.markers.isNotEmpty)
        const TimelineOverlayLayer(
            id: 'markers',
            kind: TimelineOverlayLayerKind.marker,
            visible: true,
            order: 4),
      if (input.heatValues.isNotEmpty)
        const TimelineOverlayLayer(
            id: 'heat',
            kind: TimelineOverlayLayerKind.heat,
            visible: true,
            order: 5),
    ];
  }
}

abstract interface class TimelineOverlaySource {
  Stream<TimelineOverlaySnapshot> watch(VirtualMediaStreamId streamId);
}

DateTime _defaultClock() => DateTime.now().toUtc();
