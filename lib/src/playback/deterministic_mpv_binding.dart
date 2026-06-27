import 'capability_matrix.dart';
import 'mpv_adapter_facade.dart';
import 'player_adapter.dart';
import 'track_management.dart';
import 'video_enhancement_pipeline.dart';

/// Deterministic [MpvAdapterBinding] for Phase 1 runtime tests.
///
/// This binding records operations and returns normalized playback results
/// without importing concrete engine or presentation surfaces.
final class DeterministicMpvBinding implements MpvAdapterBinding {
  DeterministicMpvBinding({
    List<MediaTrackDescriptor> tracks = const <MediaTrackDescriptor>[],
    PlaybackCommandResult Function(PlaybackOperation operation)? resultFor,
  })  : _tracks = List<MediaTrackDescriptor>.unmodifiable(tracks),
        _resultFor = resultFor;

  final List<MediaTrackDescriptor> _tracks;
  final PlaybackCommandResult Function(PlaybackOperation operation)? _resultFor;
  bool _disposed = false;

  final List<PlaybackOperation> operations = <PlaybackOperation>[];
  PlaybackSource? loadedSource;
  Duration? seekPosition;
  MediaTrackId? switchedTrackId;
  VideoEnhancementProfile? activeEnhancementProfile;
  bool enhancementDisabled = false;

  bool get isDisposed => _disposed;

  @override
  Future<PlaybackCommandResult> load(PlaybackSource source) async {
    final PlaybackCommandResult? disposed =
        _rejectIfDisposed(PlaybackOperation.load);
    if (disposed != null) return disposed;
    operations.add(PlaybackOperation.load);
    loadedSource = source;
    return _resultFor?.call(PlaybackOperation.load) ??
        const PlaybackCommandResult.success();
  }

  @override
  Future<PlaybackCommandResult> play() async {
    return _recordCommand(PlaybackOperation.play);
  }

  @override
  Future<PlaybackCommandResult> pause() async {
    return _recordCommand(PlaybackOperation.pause);
  }

  @override
  Future<PlaybackCommandResult> seek(Duration position) async {
    final PlaybackCommandResult? disposed =
        _rejectIfDisposed(PlaybackOperation.seek);
    if (disposed != null) return disposed;
    operations.add(PlaybackOperation.seek);
    seekPosition = position;
    return _resultFor?.call(PlaybackOperation.seek) ??
        const PlaybackCommandResult.success();
  }

  @override
  Future<PlaybackCommandResult> stop() async {
    return _recordCommand(PlaybackOperation.stop);
  }

  @override
  Future<PlaybackCommandResult> dispose() async {
    if (_disposed) {
      return _disposedFailure(PlaybackOperation.dispose);
    }
    operations.add(PlaybackOperation.dispose);
    _disposed = true;
    return _resultFor?.call(PlaybackOperation.dispose) ??
        const PlaybackCommandResult.success();
  }

  @override
  Future<TrackDiscoveryResult> discoverTracks() async {
    if (_disposed) {
      return TrackDiscoveryResult.unsupported(
          reason: 'Deterministic MPV binding has been disposed.');
    }
    operations.add(PlaybackOperation.discoverTracks);
    return TrackDiscoveryResult(
      tracks: _tracks,
      capabilityMatrix: PlaybackCapabilityMatrix(
        capabilities: <PlaybackCapability, CapabilityStatus>{
          PlaybackCapability.audioTrackDiscovery: CapabilityStatus.supported(),
          PlaybackCapability.subtitleTrackDiscovery:
              CapabilityStatus.supported(),
          PlaybackCapability.audioTrackSwitching: CapabilityStatus.supported(),
          PlaybackCapability.subtitleTrackSwitching:
              CapabilityStatus.supported(),
        },
      ),
    );
  }

  @override
  Future<TrackSwitchResult> switchTrack(MediaTrackId trackId) async {
    if (_disposed) {
      return const TrackSwitchResult.unsupported(
          'Deterministic MPV binding has been disposed.');
    }
    operations.add(PlaybackOperation.switchTrack);
    if (!_tracks
        .any((MediaTrackDescriptor track) => track.id.value == trackId.value)) {
      return TrackSwitchResult.unsupported(
          'Track ${trackId.value} is not available.');
    }
    switchedTrackId = trackId;
    return const TrackSwitchResult.success();
  }

  @override
  Future<EnhancementApplyOutcome> applyEnhancement(
      VideoEnhancementProfile profile) async {
    final PlaybackCommandResult? disposed =
        _rejectIfDisposed(PlaybackOperation.applyEnhancement);
    if (disposed != null) {
      return EnhancementApplyOutcome.rejected(
        failure: EnhancementPipelineFailure(
          kind: EnhancementPipelineFailureKind.adapterRejected,
          message: disposed.failure!.message,
        ),
      );
    }
    operations.add(PlaybackOperation.applyEnhancement);
    activeEnhancementProfile = profile;
    enhancementDisabled = false;
    return EnhancementApplyOutcome.applied(profile: profile);
  }

  @override
  Future<EnhancementDisableOutcome> disableEnhancement() async {
    final PlaybackCommandResult? disposed =
        _rejectIfDisposed(PlaybackOperation.disableEnhancement);
    if (disposed != null) {
      return EnhancementDisableOutcome.rejected(
        failure: EnhancementPipelineFailure(
          kind: EnhancementPipelineFailureKind.adapterRejected,
          message: disposed.failure!.message,
        ),
      );
    }
    operations.add(PlaybackOperation.disableEnhancement);
    activeEnhancementProfile = null;
    enhancementDisabled = true;
    return const EnhancementDisableOutcome.disabled();
  }

  Future<PlaybackCommandResult> _recordCommand(
      PlaybackOperation operation) async {
    final PlaybackCommandResult? disposed = _rejectIfDisposed(operation);
    if (disposed != null) return disposed;
    operations.add(operation);
    return _resultFor?.call(operation) ?? const PlaybackCommandResult.success();
  }

  PlaybackCommandResult? _rejectIfDisposed(PlaybackOperation operation) {
    if (!_disposed) return null;
    return _disposedFailure(operation);
  }

  PlaybackCommandResult _disposedFailure(PlaybackOperation operation) {
    return PlaybackCommandResult.failure(
      PlaybackFailure(
        operation: operation,
        kind: PlaybackFailureKind.disposed,
        message: 'Deterministic MPV binding has been disposed.',
      ),
    );
  }
}
