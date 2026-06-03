import 'playback_controller.dart';

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

final class PlaybackStateSnapshot {
  const PlaybackStateSnapshot({
    required this.status,
    this.timeline = const PlaybackTimelineState.zero(),
    this.buffering = const PlaybackBufferingState.none(),
    this.activeTracks = const ActivePlaybackTrackState.none(),
    this.sourceUri,
    this.failureReason,
  });

  final PlaybackLifecycleStatus status;
  final PlaybackTimelineState timeline;
  final PlaybackBufferingState buffering;
  final ActivePlaybackTrackState activeTracks;
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
