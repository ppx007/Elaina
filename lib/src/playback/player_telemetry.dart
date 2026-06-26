import 'track_management.dart';

/// Playback-owned state stream emitted by concrete player integrations.
///
/// Commands tell the player what to do, but the UI must render what the player
/// actually did. This boundary keeps media_kit/libmpv stream details inside the
/// Playback layer while letting Domain publish accurate progress and buffering.
abstract interface class PlayerTelemetrySource {
  PlayerTelemetrySnapshot get currentTelemetry;

  Stream<PlayerTelemetrySnapshot> get telemetry;
}

final class PlayerTelemetrySnapshot {
  PlayerTelemetrySnapshot({
    this.playing = false,
    this.completed = false,
    this.buffering = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.bufferedPosition = Duration.zero,
    DateTime? observedAt,
    this.failureReason,
    this.activeAudioTrackId,
    this.activeSubtitleTrackId,
    Iterable<MediaTrackDescriptor> tracks = const <MediaTrackDescriptor>[],
  })  : observedAt = observedAt ?? DateTime.now(),
        tracks = List<MediaTrackDescriptor>.unmodifiable(tracks);

  final bool playing;
  final bool completed;
  final bool buffering;
  final Duration position;
  final Duration duration;
  final Duration bufferedPosition;
  final DateTime observedAt;
  final String? failureReason;
  final MediaTrackId? activeAudioTrackId;
  final MediaTrackId? activeSubtitleTrackId;
  final List<MediaTrackDescriptor> tracks;

  PlayerTelemetrySnapshot copyWith({
    bool? playing,
    bool? completed,
    bool? buffering,
    Duration? position,
    Duration? duration,
    Duration? bufferedPosition,
    DateTime? observedAt,
    String? failureReason,
    bool clearFailureReason = false,
    MediaTrackId? activeAudioTrackId,
    bool clearActiveAudioTrackId = false,
    MediaTrackId? activeSubtitleTrackId,
    bool clearActiveSubtitleTrackId = false,
    Iterable<MediaTrackDescriptor>? tracks,
  }) {
    return PlayerTelemetrySnapshot(
      playing: playing ?? this.playing,
      completed: completed ?? this.completed,
      buffering: buffering ?? this.buffering,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      bufferedPosition: bufferedPosition ?? this.bufferedPosition,
      observedAt: observedAt ?? this.observedAt,
      failureReason: clearFailureReason
          ? null
          : failureReason ?? this.failureReason,
      activeAudioTrackId: clearActiveAudioTrackId
          ? null
          : activeAudioTrackId ?? this.activeAudioTrackId,
      activeSubtitleTrackId: clearActiveSubtitleTrackId
          ? null
          : activeSubtitleTrackId ?? this.activeSubtitleTrackId,
      tracks: tracks ?? this.tracks,
    );
  }
}
