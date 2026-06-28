// Playback state is the domain read model shared by controller, UI, metadata
// bridge, and tests. Keep adapter-specific details out of these snapshots.
import 'subtitle_style.dart';

final class DomainMediaTrackId {
  const DomainMediaTrackId(this.value)
      : assert(value != '', 'Track id must not be empty.');

  final String value;
}

enum DomainMediaTrackType {
  audio,
  subtitle,
}

enum PlaybackLifecycleStatus {
  idle,
  opening,
  playing,
  paused,
  buffering,
  ended,
  failed,
}

final class PlaybackTimelineState {
  const PlaybackTimelineState({
    required this.position,
    this.duration,
    this.observedAt,
  });

  const PlaybackTimelineState.zero()
      : position = Duration.zero,
        duration = null,
        observedAt = null;

  final Duration position;
  final Duration? duration;
  final DateTime? observedAt;
}

final class PlaybackBufferingState {
  const PlaybackBufferingState({
    this.isBuffering = false,
    this.bufferedPosition,
    this.bufferedFraction,
  });

  const PlaybackBufferingState.none()
      : isBuffering = false,
        bufferedPosition = null,
        bufferedFraction = null;

  final bool isBuffering;
  final Duration? bufferedPosition;
  final double? bufferedFraction;
}

final class ActivePlaybackTrackState {
  const ActivePlaybackTrackState({
    this.audioTrackId,
    this.subtitleTrackId,
  });

  const ActivePlaybackTrackState.none()
      : audioTrackId = null,
        subtitleTrackId = null;

  final DomainMediaTrackId? audioTrackId;
  final DomainMediaTrackId? subtitleTrackId;
}

final class DomainSubtitleCueDescriptor {
  const DomainSubtitleCueDescriptor({
    required this.start,
    required this.end,
    required this.text,
    this.id,
    this.hasEmbeddedStyle = false,
  }) : assert(end >= start, 'Subtitle cue end must not precede start.');

  final Duration start;
  final Duration end;
  final String text;
  final String? id;
  final bool hasEmbeddedStyle;
}

final class DomainSubtitleTrackDescriptor {
  const DomainSubtitleTrackDescriptor({
    required this.id,
    required this.format,
    this.languageCode,
    this.title,
  }) : assert(id != '', 'Subtitle track id must not be empty.');

  final String id;
  final String format;
  final String? languageCode;
  final String? title;
}

final class PlaybackSubtitleStateSnapshot {
  PlaybackSubtitleStateSnapshot({
    List<DomainSubtitleTrackDescriptor> availableTracks =
        const <DomainSubtitleTrackDescriptor>[],
    this.selectedTrackId,
    List<DomainSubtitleCueDescriptor> activeCues =
        const <DomainSubtitleCueDescriptor>[],
    this.offset = Duration.zero,
    this.styleProfile = SubtitleStyleProfile.defaults,
    List<String> warnings = const <String>[],
    this.failureReason,
  })  : availableTracks =
            List<DomainSubtitleTrackDescriptor>.unmodifiable(availableTracks),
        activeCues = List<DomainSubtitleCueDescriptor>.unmodifiable(activeCues),
        warnings = List<String>.unmodifiable(warnings);

  const PlaybackSubtitleStateSnapshot.none()
      : availableTracks = const <DomainSubtitleTrackDescriptor>[],
        selectedTrackId = null,
        activeCues = const <DomainSubtitleCueDescriptor>[],
        offset = Duration.zero,
        styleProfile = SubtitleStyleProfile.defaults,
        warnings = const <String>[],
        failureReason = null;

  final List<DomainSubtitleTrackDescriptor> availableTracks;
  final String? selectedTrackId;
  final List<DomainSubtitleCueDescriptor> activeCues;
  final Duration offset;
  final SubtitleStyleProfile styleProfile;
  final List<String> warnings;
  final String? failureReason;

  bool get hasActiveCues => activeCues.isNotEmpty;
}

enum DomainDanmakuMode {
  scrolling,
  top,
  bottom,
}

final class DomainDanmakuCommentDescriptor {
  const DomainDanmakuCommentDescriptor({
    required this.id,
    required this.timestamp,
    required this.text,
    required this.mode,
    this.colorArgb,
  }) : assert(id != '', 'Danmaku comment id must not be empty.');

  final String id;
  final Duration timestamp;
  final String text;
  final DomainDanmakuMode mode;
  final int? colorArgb;
}

final class DomainDanmakuLaneDescriptor {
  DomainDanmakuLaneDescriptor({
    required this.mode,
    Iterable<DomainDanmakuCommentDescriptor> comments =
        const <DomainDanmakuCommentDescriptor>[],
  }) : comments = List<DomainDanmakuCommentDescriptor>.unmodifiable(comments);

  final DomainDanmakuMode mode;
  final List<DomainDanmakuCommentDescriptor> comments;
}

final class DomainCaptionTransform4Descriptor {
  DomainCaptionTransform4Descriptor({required Iterable<double> values})
      : assert(
          values.length == 16,
          'Matrix4 transform must contain 16 values.',
        ),
        values = List<double>.unmodifiable(values);

  const DomainCaptionTransform4Descriptor._(this.values);

  static const List<double> identityValues = <double>[
    1,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    1,
  ];

  static const DomainCaptionTransform4Descriptor identity =
      DomainCaptionTransform4Descriptor._(identityValues);

  final List<double> values;
}

final class DomainMatrixDanmakuCommentDescriptor {
  const DomainMatrixDanmakuCommentDescriptor({
    required this.id,
    required this.timestamp,
    required this.text,
    required this.mode,
    this.colorArgb,
  }) : assert(id != '', 'Matrix danmaku comment id must not be empty.');

  final String id;
  final Duration timestamp;
  final String text;
  final DomainDanmakuMode mode;
  final int? colorArgb;
}

final class PlaybackMatrixDanmakuStateSnapshot {
  PlaybackMatrixDanmakuStateSnapshot({
    this.clockPosition = Duration.zero,
    DomainCaptionTransform4Descriptor? transform,
    Iterable<DomainMatrixDanmakuCommentDescriptor> comments =
        const <DomainMatrixDanmakuCommentDescriptor>[],
    this.rendererSource,
    this.failureReason,
  })  : transform = transform ?? DomainCaptionTransform4Descriptor.identity,
        comments =
            List<DomainMatrixDanmakuCommentDescriptor>.unmodifiable(comments);

  const PlaybackMatrixDanmakuStateSnapshot.none()
      : clockPosition = Duration.zero,
        transform = DomainCaptionTransform4Descriptor.identity,
        comments = const <DomainMatrixDanmakuCommentDescriptor>[],
        rendererSource = null,
        failureReason = null;

  final Duration clockPosition;
  final DomainCaptionTransform4Descriptor transform;
  final List<DomainMatrixDanmakuCommentDescriptor> comments;
  final String? rendererSource;
  final String? failureReason;

  int get renderedCommentCount => comments.length;

  bool get hasVisibleComments => comments.isNotEmpty;
}

final class PlaybackDanmakuStateSnapshot {
  PlaybackDanmakuStateSnapshot({
    this.clockPosition = Duration.zero,
    Iterable<DomainDanmakuLaneDescriptor> lanes =
        const <DomainDanmakuLaneDescriptor>[],
    Iterable<String> warnings = const <String>[],
    PlaybackMatrixDanmakuStateSnapshot? matrix,
    this.failureReason,
  })  : lanes = List<DomainDanmakuLaneDescriptor>.unmodifiable(lanes),
        warnings = List<String>.unmodifiable(warnings),
        matrix = matrix ?? PlaybackMatrixDanmakuStateSnapshot.none();

  const PlaybackDanmakuStateSnapshot.none()
      : clockPosition = Duration.zero,
        lanes = const <DomainDanmakuLaneDescriptor>[],
        warnings = const <String>[],
        matrix = const PlaybackMatrixDanmakuStateSnapshot.none(),
        failureReason = null;

  final Duration clockPosition;
  final List<DomainDanmakuLaneDescriptor> lanes;
  final List<String> warnings;
  final PlaybackMatrixDanmakuStateSnapshot matrix;
  final String? failureReason;

  bool get hasVisibleComments {
    return lanes.any(
      (DomainDanmakuLaneDescriptor lane) => lane.comments.isNotEmpty,
    );
  }
}

final class PlaybackStateSnapshot {
  const PlaybackStateSnapshot({
    required this.status,
    this.timeline = const PlaybackTimelineState.zero(),
    this.buffering = const PlaybackBufferingState.none(),
    this.activeTracks = const ActivePlaybackTrackState.none(),
    this.subtitles = const PlaybackSubtitleStateSnapshot.none(),
    this.danmaku = const PlaybackDanmakuStateSnapshot.none(),
    this.sourceUri,
    this.failureReason,
  });

  final PlaybackLifecycleStatus status;
  final PlaybackTimelineState timeline;
  final PlaybackBufferingState buffering;
  final ActivePlaybackTrackState activeTracks;
  final PlaybackSubtitleStateSnapshot subtitles;
  final PlaybackDanmakuStateSnapshot danmaku;
  final Uri? sourceUri;
  final String? failureReason;
}

abstract interface class PlaybackStateObserver {
  void onPlaybackState(PlaybackStateSnapshot snapshot);
}

abstract interface class PlaybackStateObservable {
  PlaybackStateSnapshot get currentState;

  void addPlaybackStateObserver(PlaybackStateObserver observer);

  void removePlaybackStateObserver(PlaybackStateObserver observer);
}
