import '../foundation/extension_points.dart';
import 'capability_matrix.dart';
import 'subtitle_style.dart';
import 'track_management.dart';
import 'video_enhancement_pipeline.dart';

abstract class PlaybackSource {
  const PlaybackSource(
      {required this.uri, this.headers = const <String, String>{}});

  final Uri uri;
  final Map<String, String> headers;
}

final class LocalFilePlaybackSource extends PlaybackSource {
  const LocalFilePlaybackSource({required super.uri});
}

final class HttpPlaybackSource extends PlaybackSource {
  const HttpPlaybackSource({required super.uri, super.headers});
}

final class HlsPlaybackSource extends PlaybackSource {
  const HlsPlaybackSource({required super.uri, super.headers});
}

enum PlaybackOperation {
  load,
  play,
  pause,
  seek,
  stop,
  dispose,
  discoverTracks,
  switchTrack,
  applyEnhancement,
  disableEnhancement,
  applySubtitleStyle,
}

enum PlaybackFailureKind {
  unsupported,
  invalidSource,
  adapterUnavailable,
  operationFailed,
  disposed,
}

final class PlaybackFailure implements Exception {
  const PlaybackFailure({
    required this.operation,
    required this.kind,
    required this.message,
  });

  final PlaybackOperation operation;
  final PlaybackFailureKind kind;
  final String message;
}

final class PlaybackCommandResult {
  const PlaybackCommandResult._({this.failure});

  const PlaybackCommandResult.success() : this._();

  const PlaybackCommandResult.failure(PlaybackFailure failure)
      : this._(failure: failure);

  final PlaybackFailure? failure;

  bool get isSuccess => failure == null;
}

abstract interface class PlayerAdapter implements ElainaAdapter {
  PlaybackCapabilityMatrix get capabilities;

  Future<PlaybackCommandResult> load(PlaybackSource source);

  Future<PlaybackCommandResult> play();

  Future<PlaybackCommandResult> pause();

  Future<PlaybackCommandResult> seek(Duration position);

  Future<PlaybackCommandResult> stop();

  Future<PlaybackCommandResult> dispose();

  Future<TrackDiscoveryResult> discoverTracks();

  Future<TrackSwitchResult> switchTrack(MediaTrackId trackId);

  Future<EnhancementApplyOutcome> applyEnhancement(
      VideoEnhancementProfile profile);

  Future<EnhancementDisableOutcome> disableEnhancement();

  Future<PlaybackCommandResult> applySubtitleStyle(
      SubtitleStyleProfile profile);
}

PlaybackCapability? playbackCapabilityForSource(PlaybackSource source) {
  return switch (source) {
    LocalFilePlaybackSource() => PlaybackCapability.localFilePlayback,
    HttpPlaybackSource() => PlaybackCapability.httpPlayback,
    HlsPlaybackSource() => PlaybackCapability.hlsPlayback,
    _ when source.uri.isScheme('http') || source.uri.isScheme('https') =>
      PlaybackCapability.httpPlayback,
    _ => null,
  };
}

PlaybackCommandResult playbackSourceSupportResult({
  required PlaybackSource source,
  required PlaybackCapabilityMatrix capabilityMatrix,
}) {
  final PlaybackCapability? requiredCapability =
      playbackCapabilityForSource(source);
  if (requiredCapability == null) {
    return const PlaybackCommandResult.failure(
      PlaybackFailure(
        operation: PlaybackOperation.load,
        kind: PlaybackFailureKind.invalidSource,
        message: 'Playback source type is not supported by Player core.',
      ),
    );
  }

  final CapabilityStatus sourceSupport =
      capabilityMatrix.statusOf(requiredCapability);
  if (sourceSupport.isSupported) {
    return const PlaybackCommandResult.success();
  }

  return PlaybackCommandResult.failure(
    PlaybackFailure(
      operation: PlaybackOperation.load,
      kind: PlaybackFailureKind.unsupported,
      message:
          sourceSupport.reason ?? 'Playback source capability is unsupported.',
    ),
  );
}
