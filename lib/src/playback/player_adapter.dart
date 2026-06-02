import '../foundation/extension_points.dart';
import 'capability_matrix.dart';
import 'track_management.dart';

abstract class PlaybackSource {
  const PlaybackSource({required this.uri, this.headers = const <String, String>{}});

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

  const PlaybackCommandResult.failure(PlaybackFailure failure) : this._(failure: failure);

  final PlaybackFailure? failure;

  bool get isSuccess => failure == null;
}

abstract interface class PlayerAdapter implements CelesteriaAdapter {
  PlaybackCapabilityMatrix get capabilities;

  Future<PlaybackCommandResult> load(PlaybackSource source);

  Future<PlaybackCommandResult> play();

  Future<PlaybackCommandResult> pause();

  Future<PlaybackCommandResult> seek(Duration position);

  Future<PlaybackCommandResult> stop();

  Future<PlaybackCommandResult> dispose();

  Future<TrackDiscoveryResult> discoverTracks();

  Future<TrackSwitchResult> switchTrack(MediaTrackId trackId);
}
