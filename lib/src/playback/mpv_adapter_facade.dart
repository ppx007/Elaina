// MPV adapter facade translates the generic PlayerAdapter contract to an MPV
// binding. Keep libmpv-specific loading and command quirks behind this file.
import 'capability_matrix.dart';
import 'player_adapter.dart';
import 'track_management.dart';
import 'video_enhancement_pipeline.dart';

abstract interface class MpvAdapterBinding {
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
}

final class MpvPlayerAdapterFacade implements PlayerAdapter {
  const MpvPlayerAdapterFacade.unsupported(
      {String reason = 'MPV binding is unavailable.'})
      : _binding = null,
        _boundCapabilities = null,
        _unavailableReason = reason;

  const MpvPlayerAdapterFacade.bound({
    required MpvAdapterBinding binding,
    PlaybackCapabilityMatrix? capabilities,
  })  : _binding = binding,
        _boundCapabilities = capabilities,
        _unavailableReason = null;

  final MpvAdapterBinding? _binding;
  final PlaybackCapabilityMatrix? _boundCapabilities;
  final String? _unavailableReason;

  @override
  String get id => 'mpv';

  @override
  String get displayName => 'MPV';

  @override
  PlaybackCapabilityMatrix get capabilities {
    final MpvAdapterBinding? binding = _binding;
    if (binding == null) {
      return PlaybackCapabilityMatrix.unsupported(
        reason: _bindingUnavailableMessage,
      );
    }

    if (binding is PlaybackCapabilityProbeSource) {
      final PlaybackCapabilityProbeSource probeSource =
          binding as PlaybackCapabilityProbeSource;
      return probeSource.currentCapabilityProbe.capabilities;
    }

    return _boundCapabilities ??
        PlaybackCapabilityMatrix(
          capabilities: <PlaybackCapability, CapabilityStatus>{
            PlaybackCapability.localFilePlayback: CapabilityStatus.supported(),
            PlaybackCapability.httpPlayback: CapabilityStatus.supported(),
            PlaybackCapability.hlsPlayback: CapabilityStatus.supported(),
            PlaybackCapability.playPause: CapabilityStatus.supported(),
            PlaybackCapability.seek: CapabilityStatus.supported(),
            PlaybackCapability.stop: CapabilityStatus.supported(),
            PlaybackCapability.progressReporting: CapabilityStatus.supported(),
            PlaybackCapability.audioTrackDiscovery:
                CapabilityStatus.supported(),
            PlaybackCapability.audioTrackSwitching:
                CapabilityStatus.supported(),
            PlaybackCapability.subtitleTrackDiscovery:
                CapabilityStatus.supported(),
            PlaybackCapability.subtitleTrackSwitching:
                CapabilityStatus.supported(),
            PlaybackCapability.secondaryPanels: CapabilityStatus.supported(),
          },
        );
  }

  @override
  Future<PlaybackCommandResult> load(PlaybackSource source) async {
    final MpvAdapterBinding? binding = _binding;
    if (binding == null) {
      return _unsupported(PlaybackOperation.load);
    }
    final PlaybackCommandResult sourceSupport = playbackSourceSupportResult(
      source: source,
      capabilityMatrix: capabilities,
    );
    if (!sourceSupport.isSuccess) {
      return sourceSupport;
    }
    return binding.load(source);
  }

  @override
  Future<PlaybackCommandResult> play() async {
    final MpvAdapterBinding? binding = _binding;
    if (binding == null) {
      return _unsupported(PlaybackOperation.play);
    }
    return binding.play();
  }

  @override
  Future<PlaybackCommandResult> pause() async {
    final MpvAdapterBinding? binding = _binding;
    if (binding == null) {
      return _unsupported(PlaybackOperation.pause);
    }
    return binding.pause();
  }

  @override
  Future<PlaybackCommandResult> seek(Duration position) async {
    final MpvAdapterBinding? binding = _binding;
    if (binding == null) {
      return _unsupported(PlaybackOperation.seek);
    }
    return binding.seek(position);
  }

  @override
  Future<PlaybackCommandResult> stop() async {
    final MpvAdapterBinding? binding = _binding;
    if (binding == null) {
      return _unsupported(PlaybackOperation.stop);
    }
    return binding.stop();
  }

  @override
  Future<PlaybackCommandResult> dispose() async {
    final MpvAdapterBinding? binding = _binding;
    if (binding == null) {
      return _unsupported(PlaybackOperation.dispose);
    }
    return binding.dispose();
  }

  @override
  Future<TrackDiscoveryResult> discoverTracks() async {
    final MpvAdapterBinding? binding = _binding;
    if (binding == null) {
      return TrackDiscoveryResult.unsupported(
          reason: _bindingUnavailableMessage);
    }
    return binding.discoverTracks();
  }

  @override
  Future<TrackSwitchResult> switchTrack(MediaTrackId trackId) async {
    final MpvAdapterBinding? binding = _binding;
    if (binding == null) {
      return TrackSwitchResult.unsupported(_bindingUnavailableMessage);
    }
    return binding.switchTrack(trackId);
  }

  @override
  Future<EnhancementApplyOutcome> applyEnhancement(
      VideoEnhancementProfile profile) async {
    final MpvAdapterBinding? binding = _binding;
    if (binding == null) {
      return EnhancementApplyOutcome.rejected(
        failure: _enhancementUnavailableFailure(),
      );
    }
    final EnhancementPipelineFailure? unsupported =
        _unsupportedEnhancementFailure(profile);
    if (unsupported != null) {
      return EnhancementApplyOutcome.rejected(failure: unsupported);
    }
    return binding.applyEnhancement(profile);
  }

  @override
  Future<EnhancementDisableOutcome> disableEnhancement() async {
    final MpvAdapterBinding? binding = _binding;
    if (binding == null) {
      return EnhancementDisableOutcome.rejected(
        failure: _enhancementUnavailableFailure(),
      );
    }
    return binding.disableEnhancement();
  }

  PlaybackCommandResult _unsupported(PlaybackOperation operation) {
    return PlaybackCommandResult.failure(
      PlaybackFailure(
        operation: operation,
        kind: PlaybackFailureKind.adapterUnavailable,
        message: _bindingUnavailableMessage,
      ),
    );
  }

  String get _bindingUnavailableMessage {
    return _unavailableReason ?? 'MPV binding is unavailable.';
  }

  EnhancementPipelineFailure _enhancementUnavailableFailure() {
    return EnhancementPipelineFailure(
      kind: EnhancementPipelineFailureKind.adapterRejected,
      message: _bindingUnavailableMessage,
    );
  }

  EnhancementPipelineFailure? _unsupportedEnhancementFailure(
    VideoEnhancementProfile profile,
  ) {
    final VideoEnhancementCapabilityStatus status =
        capabilities.videoEnhancementStatus();
    final List<String> reasons = <String>[
      if (!status.videoEnhancement.isSupported)
        status.videoEnhancement.reason ?? 'Video enhancement is unsupported.',
      if (profile.hdrHandling != HdrHandlingIntent.adapterDefault &&
          !status.hdrToneMapping.isSupported)
        status.hdrToneMapping.reason ?? 'HDR tone mapping is unsupported.',
      if (profile.deband != DebandIntent.off &&
          !status.debandFiltering.isSupported)
        status.debandFiltering.reason ?? 'Deband filtering is unsupported.',
      if (profile.anime4kPreset != Anime4kPresetIntent.off &&
          !status.anime4kPreset.isSupported)
        status.anime4kPreset.reason ??
            'Anime4K-style presets are unsupported.',
    ];
    if (reasons.isEmpty) return null;
    return EnhancementPipelineFailure(
      kind: EnhancementPipelineFailureKind.capabilityUnsupported,
      message: reasons.join(' '),
    );
  }
}
