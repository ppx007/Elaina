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

  const CapabilityStatus.unsupported(this.reason) : state = CapabilitySupportState.unsupported;

  final CapabilitySupportState state;
  final String? reason;

  bool get isSupported => state == CapabilitySupportState.supported;
}

final class PlaybackCapabilityMatrix {
  PlaybackCapabilityMatrix({required Map<PlaybackCapability, CapabilityStatus> capabilities})
      : _capabilities = Map<PlaybackCapability, CapabilityStatus>.unmodifiable(capabilities);

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
    return _capabilities[capability] ?? const CapabilityStatus.unsupported('Capability is not declared.');
  }

  bool supports(PlaybackCapability capability) => statusOf(capability).isSupported;

  List<PlaybackCapability> get supportedCapabilities {
    return <PlaybackCapability>[
      for (final MapEntry<PlaybackCapability, CapabilityStatus> entry in _capabilities.entries)
        if (entry.value.isSupported) entry.key,
    ];
  }
}

abstract interface class ActivePlaybackCapabilities {
  PlaybackCapabilityMatrix get matrix;
}
