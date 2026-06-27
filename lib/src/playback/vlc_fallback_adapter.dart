// VLC fallback adapter is a capability-described placeholder for environments
// where VLC is the selected secondary player. It must not hide capability loss.
// Real playback commands still flow through the common PlayerAdapter contract.
import 'capability_matrix.dart';
import 'fallback_adapter.dart';
import 'player_adapter.dart';
import 'track_management.dart';
import 'video_enhancement_pipeline.dart';

typedef VlcFallbackBackendFactory = VlcFallbackBackend Function();

const String vlcFallbackAdapterId = 'vlc-fallback';
const String vlcFallbackDisplayName = 'VLC Fallback';
const int vlcFallbackDefaultPriority = 10;
const String vlcFallbackBackendUnavailableReason =
    'VLC fallback backend is unavailable.';
const String vlcFallbackUnsupportedSourceReason =
    'VLC fallback adapter supports local file playback only.';
const String vlcFallbackUnverifiedCapabilityReason =
    'VLC fallback capability is not verified by the current backend.';

abstract interface class VlcFallbackBackend {
  Future<void> openLocalFile(Uri uri);

  Future<void> play();

  Future<void> pause();

  Future<void> seek(Duration position);

  Future<void> stop();

  Future<void> dispose();
}

final class VlcFallbackAdapter implements PlayerAdapter {
  VlcFallbackAdapter({
    VlcFallbackBackend? backend,
    VlcFallbackBackendFactory? backendFactory,
    PlaybackCapabilityMatrix? capabilities,
  })  : assert(
          backend == null || backendFactory == null,
          'Provide either a VLC backend instance or a backend factory, not both.',
        ),
        _backend = backend,
        _backendFactory = backendFactory,
        _capabilities = capabilities ??
            vlcFallbackLocalFilePlaybackCapabilities(
              backendAvailable: backend != null || backendFactory != null,
            );

  VlcFallbackBackend? _backend;
  final VlcFallbackBackendFactory? _backendFactory;
  final PlaybackCapabilityMatrix _capabilities;
  bool _disposed = false;

  @override
  String get id => vlcFallbackAdapterId;

  @override
  String get displayName => vlcFallbackDisplayName;

  @override
  PlaybackCapabilityMatrix get capabilities => _capabilities;

  @override
  Future<PlaybackCommandResult> load(PlaybackSource source) async {
    final PlaybackCommandResult? disposed =
        _rejectIfDisposed(PlaybackOperation.load);
    if (disposed != null) return disposed;

    final PlaybackCommandResult sourceSupport = playbackSourceSupportResult(
      source: source,
      capabilityMatrix: capabilities,
    );
    if (!sourceSupport.isSuccess) return sourceSupport;

    if (source is! LocalFilePlaybackSource) {
      return _failure(
        operation: PlaybackOperation.load,
        kind: PlaybackFailureKind.unsupported,
        message: vlcFallbackUnsupportedSourceReason,
      );
    }

    return _runBackendCommand(
      PlaybackOperation.load,
      (VlcFallbackBackend backend) => backend.openLocalFile(source.uri),
    );
  }

  @override
  Future<PlaybackCommandResult> play() {
    return _recordCommand(
      PlaybackOperation.play,
      (VlcFallbackBackend backend) => backend.play(),
    );
  }

  @override
  Future<PlaybackCommandResult> pause() {
    return _recordCommand(
      PlaybackOperation.pause,
      (VlcFallbackBackend backend) => backend.pause(),
    );
  }

  @override
  Future<PlaybackCommandResult> seek(Duration position) async {
    final PlaybackCommandResult? disposed =
        _rejectIfDisposed(PlaybackOperation.seek);
    if (disposed != null) return disposed;
    return _runBackendCommand(
      PlaybackOperation.seek,
      (VlcFallbackBackend backend) => backend.seek(position),
    );
  }

  @override
  Future<PlaybackCommandResult> stop() {
    return _recordCommand(
      PlaybackOperation.stop,
      (VlcFallbackBackend backend) => backend.stop(),
    );
  }

  @override
  Future<PlaybackCommandResult> dispose() async {
    if (_disposed) return _disposedFailure(PlaybackOperation.dispose);
    final VlcFallbackBackend? backend = _backend;
    if (backend != null) {
      final PlaybackCommandResult result = await _runBackendCommand(
        PlaybackOperation.dispose,
        (VlcFallbackBackend backend) => backend.dispose(),
      );
      if (!result.isSuccess) return result;
    }
    _disposed = true;
    return const PlaybackCommandResult.success();
  }

  @override
  Future<TrackDiscoveryResult> discoverTracks() async {
    return TrackDiscoveryResult.unsupported(
      reason: vlcFallbackUnverifiedCapabilityReason,
    );
  }

  @override
  Future<TrackSwitchResult> switchTrack(MediaTrackId trackId) async {
    return const TrackSwitchResult.unsupported(
      vlcFallbackUnverifiedCapabilityReason,
    );
  }

  @override
  Future<EnhancementApplyOutcome> applyEnhancement(
      VideoEnhancementProfile profile) async {
    return const EnhancementApplyOutcome.rejected(
      failure: EnhancementPipelineFailure(
        kind: EnhancementPipelineFailureKind.capabilityUnsupported,
        message: vlcFallbackUnverifiedCapabilityReason,
      ),
    );
  }

  @override
  Future<EnhancementDisableOutcome> disableEnhancement() async {
    return const EnhancementDisableOutcome.rejected(
      failure: EnhancementPipelineFailure(
        kind: EnhancementPipelineFailureKind.capabilityUnsupported,
        message: vlcFallbackUnverifiedCapabilityReason,
      ),
    );
  }

  Future<PlaybackCommandResult> _recordCommand(
    PlaybackOperation operation,
    Future<void> Function(VlcFallbackBackend backend) command,
  ) async {
    final PlaybackCommandResult? disposed = _rejectIfDisposed(operation);
    if (disposed != null) return disposed;
    return _runBackendCommand(operation, command);
  }

  Future<PlaybackCommandResult> _runBackendCommand(
    PlaybackOperation operation,
    Future<void> Function(VlcFallbackBackend backend) command,
  ) async {
    try {
      final VlcFallbackBackend? backend = _backend ?? _backendFactory?.call();
      if (backend == null) {
        return _failure(
          operation: operation,
          kind: PlaybackFailureKind.adapterUnavailable,
          message: vlcFallbackBackendUnavailableReason,
        );
      }
      _backend = backend;
      await command(backend);
      return const PlaybackCommandResult.success();
    } catch (error) {
      return _failure(
        operation: operation,
        kind: PlaybackFailureKind.operationFailed,
        message: 'VLC fallback operation failed: $error',
      );
    }
  }

  PlaybackCommandResult? _rejectIfDisposed(PlaybackOperation operation) {
    if (!_disposed) return null;
    return _disposedFailure(operation);
  }

  PlaybackCommandResult _disposedFailure(PlaybackOperation operation) {
    return _failure(
      operation: operation,
      kind: PlaybackFailureKind.disposed,
      message: 'VLC fallback adapter has been disposed.',
    );
  }

  PlaybackCommandResult _failure({
    required PlaybackOperation operation,
    required PlaybackFailureKind kind,
    required String message,
  }) {
    return PlaybackCommandResult.failure(
      PlaybackFailure(
        operation: operation,
        kind: kind,
        message: message,
      ),
    );
  }
}

FallbackAdapterCandidate vlcFallbackAdapterCandidate({
  VlcFallbackBackend? backend,
  VlcFallbackBackendFactory? backendFactory,
  int priority = vlcFallbackDefaultPriority,
}) {
  final VlcFallbackAdapter adapter = VlcFallbackAdapter(
    backend: backend,
    backendFactory: backendFactory,
  );
  return FallbackAdapterCandidate(
    id: const FallbackAdapterId(vlcFallbackAdapterId),
    adapter: adapter,
    capabilities: adapter.capabilities,
    priority: priority,
  );
}

PlaybackCapabilityMatrix vlcFallbackLocalFilePlaybackCapabilities({
  required bool backendAvailable,
}) {
  final Map<PlaybackCapability, CapabilityStatus> capabilities =
      <PlaybackCapability, CapabilityStatus>{
    for (final PlaybackCapability capability in PlaybackCapability.values)
      capability: const CapabilityStatus.unsupported(
        vlcFallbackUnverifiedCapabilityReason,
      ),
  };

  if (backendAvailable) {
    capabilities[PlaybackCapability.fallbackAdapter] =
        const CapabilityStatus.supported();
    capabilities[PlaybackCapability.localFilePlayback] =
        const CapabilityStatus.supported();
    capabilities[PlaybackCapability.playPause] =
        const CapabilityStatus.supported();
    capabilities[PlaybackCapability.seek] = const CapabilityStatus.supported();
    capabilities[PlaybackCapability.stop] = const CapabilityStatus.supported();
  } else {
    capabilities[PlaybackCapability.fallbackAdapter] =
        const CapabilityStatus.unsupported(
      vlcFallbackBackendUnavailableReason,
    );
    capabilities[PlaybackCapability.localFilePlayback] =
        const CapabilityStatus.unsupported(
      vlcFallbackBackendUnavailableReason,
    );
  }

  return PlaybackCapabilityMatrix(capabilities: capabilities);
}
