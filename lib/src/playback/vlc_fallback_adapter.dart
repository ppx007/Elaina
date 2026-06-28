// VLC fallback adapter is a capability-described placeholder for environments
// where VLC is the selected secondary player. It must not hide capability loss.
// Real playback commands still flow through the common PlayerAdapter contract.
import 'capability_matrix.dart';
import 'fallback_adapter.dart';
import 'player_adapter.dart';
import 'subtitle_style.dart';
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
const String vlcFallbackProbeSource = 'windows-libvlc-fallback-probe';
const String vlcFallbackMpvOnlyEnhancementReason =
    'VLC fallback does not expose MPV shader/property enhancement commands.';
const String vlcFallbackMpvOnlySubtitleStyleReason =
    'VLC fallback does not expose MPV subtitle style property commands.';
const String vlcFallbackAvSyncSamplerReason =
    'VLC fallback does not expose MPV avsync property sampling.';
const String vlcFallbackMatrixDanmakuReason =
    'VLC fallback does not provide a native Matrix4 danmaku renderer.';

abstract interface class VlcFallbackBackend {
  Future<void> openLocalFile(Uri uri);

  Future<void> play();

  Future<void> pause();

  Future<void> seek(Duration position);

  Future<void> stop();

  Future<void> dispose();
}

final class VlcFallbackAdapter
    implements PlayerAdapter, RefreshablePlaybackCapabilityProbeSource {
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
  PlaybackCapabilityMatrix get capabilities {
    final VlcFallbackBackend? backend = _backend;
    final PlaybackCapabilityProbeSource? probe =
        backend is PlaybackCapabilityProbeSource
            ? backend as PlaybackCapabilityProbeSource
            : null;
    if (probe != null) {
      return probe.currentCapabilityProbe.capabilities;
    }
    return _capabilities;
  }

  @override
  PlaybackCapabilityProbeSnapshot get currentCapabilityProbe {
    final VlcFallbackBackend? backend = _backend;
    final PlaybackCapabilityProbeSource? probe =
        backend is PlaybackCapabilityProbeSource
            ? backend as PlaybackCapabilityProbeSource
            : null;
    if (probe != null) {
      return probe.currentCapabilityProbe;
    }
    final bool backendAvailable = _backend != null || _backendFactory != null;
    return PlaybackCapabilityProbeSnapshot(
      capabilities: _capabilities,
      checkedAt: DateTime.now(),
      source: vlcFallbackProbeSource,
      backendLabel: vlcFallbackDisplayName,
      details: <String, String>{
        'backend': vlcFallbackDisplayName,
        'backendAvailable': backendAvailable.toString(),
        'nativeVlcBridge': backendAvailable.toString(),
        'anime4kSupported': 'false',
        'anime4kReason': vlcFallbackMpvOnlyEnhancementReason,
        'hdrDebandSupported': 'false',
        'hdrDebandReason': vlcFallbackMpvOnlyEnhancementReason,
        'avSyncSampler': 'false',
        'avSyncSamplerReason': vlcFallbackAvSyncSamplerReason,
      },
    );
  }

  @override
  Future<void> refreshCapabilityProbe() async {
    final VlcFallbackBackend? backend = _backend;
    final RefreshablePlaybackCapabilityProbeSource? probe =
        backend is RefreshablePlaybackCapabilityProbeSource
            ? backend as RefreshablePlaybackCapabilityProbeSource
            : null;
    if (probe != null) {
      await probe.refreshCapabilityProbe();
    }
  }

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

  @override
  Future<PlaybackCommandResult> applySubtitleStyle(
    SubtitleStyleProfile profile,
  ) async {
    return const PlaybackCommandResult.failure(
      PlaybackFailure(
        operation: PlaybackOperation.applySubtitleStyle,
        kind: PlaybackFailureKind.unsupported,
        message: vlcFallbackMpvOnlySubtitleStyleReason,
      ),
    );
  }

  @override
  Future<PlaybackCommandResult> setSubtitleVisibility(bool visible) async {
    return const PlaybackCommandResult.failure(
      PlaybackFailure(
        operation: PlaybackOperation.setSubtitleVisibility,
        kind: PlaybackFailureKind.unsupported,
        message: vlcFallbackMpvOnlySubtitleStyleReason,
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
  bool telemetryAvailable = false,
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
    capabilities[PlaybackCapability.progressReporting] = telemetryAvailable
        ? const CapabilityStatus.supported()
        : const CapabilityStatus.unsupported(
            vlcFallbackUnverifiedCapabilityReason,
          );
    capabilities[PlaybackCapability.videoEnhancement] =
        const CapabilityStatus.unsupported(
      vlcFallbackMpvOnlyEnhancementReason,
    );
    capabilities[PlaybackCapability.hdrToneMapping] =
        const CapabilityStatus.unsupported(
      vlcFallbackMpvOnlyEnhancementReason,
    );
    capabilities[PlaybackCapability.debandFiltering] =
        const CapabilityStatus.unsupported(
      vlcFallbackMpvOnlyEnhancementReason,
    );
    capabilities[PlaybackCapability.anime4kPreset] =
        const CapabilityStatus.unsupported(
      vlcFallbackMpvOnlyEnhancementReason,
    );
    capabilities[PlaybackCapability.avSyncGuard] =
        const CapabilityStatus.unsupported(
      vlcFallbackAvSyncSamplerReason,
    );
    capabilities[PlaybackCapability.matrixDanmaku] =
        const CapabilityStatus.unsupported(
      vlcFallbackMatrixDanmakuReason,
    );
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
