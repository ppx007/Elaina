enum PlaybackCapability {
  localFilePlayback,
  httpPlayback,
  hlsPlayback,
  playPause,
  seek,
  stop,
  progressReporting,
  audioTrackDiscovery,
  audioTrackSwitching,
  subtitleTrackDiscovery,
  subtitleTrackSwitching,
  danmakuRendering,
  secondaryPanels,
  videoEnhancement,
  hdrToneMapping,
  debandFiltering,
  anime4kPreset,
  avSyncGuard,
  matrixDanmaku,
  dualSubtitles,
  pgsSubtitleRendering,
  assSubtitleEnhancement,
  fallbackAdapter,
}

enum CapabilitySupportState {
  supported,
  unsupported,
}

final class CapabilityStatus {
  const CapabilityStatus.supported()
      : state = CapabilitySupportState.supported,
        reason = null;

  const CapabilityStatus.unsupported(this.reason)
      : state = CapabilitySupportState.unsupported;

  final CapabilitySupportState state;
  final String? reason;

  bool get isSupported => state == CapabilitySupportState.supported;
}

final class PlaybackCapabilityMatrix {
  PlaybackCapabilityMatrix(
      {required Map<PlaybackCapability, CapabilityStatus> capabilities})
      : _capabilities = Map<PlaybackCapability, CapabilityStatus>.unmodifiable(
            capabilities);

  factory PlaybackCapabilityMatrix.unsupported({required String reason}) {
    return PlaybackCapabilityMatrix(
      capabilities: <PlaybackCapability, CapabilityStatus>{
        for (final PlaybackCapability capability in PlaybackCapability.values)
          capability: CapabilityStatus.unsupported(reason),
      },
    );
  }

  final Map<PlaybackCapability, CapabilityStatus> _capabilities;

  CapabilityStatus statusOf(PlaybackCapability capability) {
    return _capabilities[capability] ??
        const CapabilityStatus.unsupported('Capability is not declared.');
  }

  bool supports(PlaybackCapability capability) =>
      statusOf(capability).isSupported;

  VideoEnhancementCapabilityStatus videoEnhancementStatus() {
    return VideoEnhancementCapabilityStatus(
      videoEnhancement: statusOf(PlaybackCapability.videoEnhancement),
      hdrToneMapping: statusOf(PlaybackCapability.hdrToneMapping),
      debandFiltering: statusOf(PlaybackCapability.debandFiltering),
      anime4kPreset: statusOf(PlaybackCapability.anime4kPreset),
    );
  }

  List<PlaybackCapability> get supportedCapabilities {
    return <PlaybackCapability>[
      for (final MapEntry<PlaybackCapability, CapabilityStatus> entry
          in _capabilities.entries)
        if (entry.value.isSupported) entry.key,
    ];
  }
}

final class VideoEnhancementCapabilityStatus {
  const VideoEnhancementCapabilityStatus({
    required this.videoEnhancement,
    required this.hdrToneMapping,
    required this.debandFiltering,
    required this.anime4kPreset,
  });

  final CapabilityStatus videoEnhancement;
  final CapabilityStatus hdrToneMapping;
  final CapabilityStatus debandFiltering;
  final CapabilityStatus anime4kPreset;

  bool get hasAnyUnsupportedComponent =>
      !videoEnhancement.isSupported ||
      !hdrToneMapping.isSupported ||
      !debandFiltering.isSupported ||
      !anime4kPreset.isSupported;

  List<String> unsupportedReasons() {
    return <String>[
      if (!videoEnhancement.isSupported)
        videoEnhancement.reason ?? 'Video enhancement is unsupported.',
      if (!hdrToneMapping.isSupported)
        hdrToneMapping.reason ?? 'HDR tone mapping is unsupported.',
      if (!debandFiltering.isSupported)
        debandFiltering.reason ?? 'Deband filtering is unsupported.',
      if (!anime4kPreset.isSupported)
        anime4kPreset.reason ?? 'Anime4K-style presets are unsupported.',
    ];
  }
}

abstract interface class ActivePlaybackCapabilities {
  PlaybackCapabilityMatrix get matrix;
}
