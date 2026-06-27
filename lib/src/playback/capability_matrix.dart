// Playback capability matrix is the single source for feature availability.
// UI should expose controls from this contract instead of probing adapters.
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

  PlaybackCapabilityMatrix withCapabilityStatus(
    PlaybackCapability capability,
    CapabilityStatus status,
  ) {
    return PlaybackCapabilityMatrix(
      capabilities: <PlaybackCapability, CapabilityStatus>{
        ..._capabilities,
        capability: status,
      },
    );
  }

  VideoEnhancementCapabilityStatus videoEnhancementStatus() {
    return VideoEnhancementCapabilityStatus(
      videoEnhancement: statusOf(PlaybackCapability.videoEnhancement),
      hdrToneMapping: statusOf(PlaybackCapability.hdrToneMapping),
      debandFiltering: statusOf(PlaybackCapability.debandFiltering),
      anime4kPreset: statusOf(PlaybackCapability.anime4kPreset),
    );
  }

  CapabilityStatus get avSyncGuardStatus {
    return statusOf(PlaybackCapability.avSyncGuard);
  }

  AdvancedCaptionCapabilityStatus advancedCaptionStatus() {
    return AdvancedCaptionCapabilityStatus(
      matrixDanmaku: statusOf(PlaybackCapability.matrixDanmaku),
      dualSubtitles: statusOf(PlaybackCapability.dualSubtitles),
      pgsSubtitleRendering: statusOf(PlaybackCapability.pgsSubtitleRendering),
      assSubtitleEnhancement:
          statusOf(PlaybackCapability.assSubtitleEnhancement),
    );
  }

  FallbackAdapterCapabilityStatus fallbackAdapterStatus(
      {Map<PlaybackCapability, CapabilityStatus> hiddenCapabilities =
          const <PlaybackCapability, CapabilityStatus>{}}) {
    return FallbackAdapterCapabilityStatus(
      fallbackAdapter: statusOf(PlaybackCapability.fallbackAdapter),
      hiddenCapabilities: hiddenCapabilities,
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

final class PlaybackCapabilityProbeSnapshot {
  PlaybackCapabilityProbeSnapshot({
    required this.capabilities,
    required this.checkedAt,
    required this.source,
    required this.backendLabel,
    this.cached = false,
    Map<String, String> details = const <String, String>{},
  }) : details = Map<String, String>.unmodifiable(details);

  final PlaybackCapabilityMatrix capabilities;
  final DateTime checkedAt;
  final String source;
  final String backendLabel;
  final bool cached;
  final Map<String, String> details;
}

abstract interface class PlaybackCapabilityProbeSource {
  PlaybackCapabilityProbeSnapshot get currentCapabilityProbe;
}

final class FallbackAdapterCapabilityStatus {
  FallbackAdapterCapabilityStatus({
    required this.fallbackAdapter,
    required Map<PlaybackCapability, CapabilityStatus> hiddenCapabilities,
  }) : hiddenCapabilities =
            Map<PlaybackCapability, CapabilityStatus>.unmodifiable(
                hiddenCapabilities);

  final CapabilityStatus fallbackAdapter;
  final Map<PlaybackCapability, CapabilityStatus> hiddenCapabilities;

  bool get isFallbackSupported => fallbackAdapter.isSupported;

  bool get hasHiddenCapabilities => hiddenCapabilities.isNotEmpty;

  List<String> unsupportedReasons() {
    return <String>[
      if (!fallbackAdapter.isSupported)
        fallbackAdapter.reason ?? 'Fallback adapter is unsupported.',
      for (final CapabilityStatus status in hiddenCapabilities.values)
        if (!status.isSupported)
          status.reason ?? 'Fallback adapter hides a capability.',
    ];
  }
}

final class AdvancedCaptionCapabilityStatus {
  const AdvancedCaptionCapabilityStatus({
    required this.matrixDanmaku,
    required this.dualSubtitles,
    required this.pgsSubtitleRendering,
    required this.assSubtitleEnhancement,
  });

  final CapabilityStatus matrixDanmaku;
  final CapabilityStatus dualSubtitles;
  final CapabilityStatus pgsSubtitleRendering;
  final CapabilityStatus assSubtitleEnhancement;

  bool get hasAnyUnsupportedComponent =>
      !matrixDanmaku.isSupported ||
      !dualSubtitles.isSupported ||
      !pgsSubtitleRendering.isSupported ||
      !assSubtitleEnhancement.isSupported;

  List<String> unsupportedReasons() {
    return <String>[
      if (!matrixDanmaku.isSupported)
        matrixDanmaku.reason ?? 'Matrix4 danmaku is unsupported.',
      if (!dualSubtitles.isSupported)
        dualSubtitles.reason ?? 'Dual subtitles are unsupported.',
      if (!pgsSubtitleRendering.isSupported)
        pgsSubtitleRendering.reason ?? 'PGS subtitle rendering is unsupported.',
      if (!assSubtitleEnhancement.isSupported)
        assSubtitleEnhancement.reason ??
            'ASS subtitle enhancement is unsupported.',
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
