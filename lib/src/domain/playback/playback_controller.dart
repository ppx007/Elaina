import '../../playback/capability_matrix.dart';
import '../../playback/player_adapter.dart';
import '../../playback/track_management.dart';
import 'playback_state.dart';

typedef DomainPlaybackCommandResult = PlaybackCommandResult;
typedef DomainTrackSwitchResult = TrackSwitchResult;

// Tests use a fixed observation time so seek assertions do not depend on wall
// clock drift or the order in which WidgetTester pumps frames.
final DateTime mockPlaybackObservedAt = DateTime.utc(2026, 6, 3, 12, 0);

abstract interface class ActivePlayerAdapterResolver {
  PlayerAdapter get activeAdapter;
}

enum PlaybackSurfaceControl {
  playPause,
  seek,
  stop,
  progress,
  audioTracks,
  subtitleTracks,
}

enum PlaybackSurfacePanel {
  tracks,
}

enum DomainPlaybackCapabilityId {
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

final class DomainPlaybackCapabilityStatus {
  const DomainPlaybackCapabilityStatus({
    required this.isSupported,
    this.reason,
  });

  final bool isSupported;
  final String? reason;
}

final class DomainPlaybackCapabilityItem {
  const DomainPlaybackCapabilityItem({
    required this.id,
    required this.status,
  });

  final DomainPlaybackCapabilityId id;
  final DomainPlaybackCapabilityStatus status;
}

final class DomainPlaybackCapabilitySummary {
  DomainPlaybackCapabilitySummary({
    required Iterable<DomainPlaybackCapabilityItem> items,
  }) : items = List<DomainPlaybackCapabilityItem>.unmodifiable(items);

  final List<DomainPlaybackCapabilityItem> items;

  DomainPlaybackCapabilityStatus statusOf(DomainPlaybackCapabilityId id) {
    for (final DomainPlaybackCapabilityItem item in items) {
      if (item.id == id) return item.status;
    }
    return const DomainPlaybackCapabilityStatus(
      isSupported: false,
      reason: 'Capability is not declared.',
    );
  }
}

final class DomainMediaTrackDescriptor {
  const DomainMediaTrackDescriptor({
    required this.id,
    required this.type,
    required this.label,
    this.languageCode,
    this.isSelected = false,
  });

  final DomainMediaTrackId id;
  final DomainMediaTrackType type;
  final String label;
  final String? languageCode;
  final bool isSelected;
}

final class DomainTrackDiscoveryResult {
  DomainTrackDiscoveryResult({
    required this.isSupported,
    required Iterable<DomainMediaTrackDescriptor> tracks,
    this.unsupportedReason,
  }) : tracks = List<DomainMediaTrackDescriptor>.unmodifiable(tracks);

  final bool isSupported;
  final List<DomainMediaTrackDescriptor> tracks;
  final String? unsupportedReason;
}

final class PlaybackSurfaceState {
  const PlaybackSurfaceState({
    required this.visibleControls,
    required this.availablePanels,
  });

  final Set<PlaybackSurfaceControl> visibleControls;
  final Set<PlaybackSurfacePanel> availablePanels;
}

PlaybackSurfaceState playbackSurfaceStateForCapabilities(
    PlaybackCapabilityMatrix capabilityMatrix) {
  return PlaybackSurfaceState(
    visibleControls: <PlaybackSurfaceControl>{
      if (capabilityMatrix.supports(PlaybackCapability.playPause))
        PlaybackSurfaceControl.playPause,
      if (capabilityMatrix.supports(PlaybackCapability.seek))
        PlaybackSurfaceControl.seek,
      if (capabilityMatrix.supports(PlaybackCapability.stop))
        PlaybackSurfaceControl.stop,
      if (capabilityMatrix.supports(PlaybackCapability.progressReporting))
        PlaybackSurfaceControl.progress,
      if (capabilityMatrix.supports(PlaybackCapability.audioTrackSwitching))
        PlaybackSurfaceControl.audioTracks,
      if (capabilityMatrix.supports(PlaybackCapability.subtitleTrackSwitching))
        PlaybackSurfaceControl.subtitleTracks,
    },
    availablePanels: <PlaybackSurfacePanel>{
      if (capabilityMatrix.supports(PlaybackCapability.secondaryPanels))
        PlaybackSurfacePanel.tracks,
    },
  );
}

abstract interface class PlaybackControllerContract
    implements ActivePlaybackCapabilities, PlaybackStateObservable {
  PlaybackSurfaceState resolveSurfaceState();

  DomainPlaybackCapabilitySummary resolveCapabilitySummary();

  Future<PlaybackCommandResult> open(PlaybackSource source);

  Future<PlaybackCommandResult> play();

  Future<PlaybackCommandResult> pause();

  Future<PlaybackCommandResult> seek(Duration position);

  Future<PlaybackCommandResult> stop();

  Future<TrackDiscoveryResult> discoverTracks();

  Future<DomainTrackDiscoveryResult> discoverDomainTracks();

  Future<TrackSwitchResult> switchTrack(DomainMediaTrackId trackId,
      {DomainMediaTrackType? trackType});
}

DomainPlaybackCapabilitySummary domainPlaybackCapabilitySummaryFromMatrix(
  PlaybackCapabilityMatrix matrix,
) {
  return DomainPlaybackCapabilitySummary(
    items: <DomainPlaybackCapabilityItem>[
      for (final DomainPlaybackCapabilityId id
          in DomainPlaybackCapabilityId.values)
        DomainPlaybackCapabilityItem(
          id: id,
          status: _domainStatusFromPlaybackStatus(
            matrix.statusOf(_playbackCapabilityForDomainId(id)),
          ),
        ),
    ],
  );
}

DomainTrackDiscoveryResult domainTrackDiscoveryResultFromPlayback(
  TrackDiscoveryResult result,
) {
  final bool supported =
      result.capabilityMatrix.supports(PlaybackCapability.audioTrackDiscovery) ||
          result.capabilityMatrix
              .supports(PlaybackCapability.subtitleTrackDiscovery);
  return DomainTrackDiscoveryResult(
    isSupported: supported,
    unsupportedReason:
        supported ? null : _trackDiscoveryUnsupportedReason(result.capabilityMatrix),
    tracks: <DomainMediaTrackDescriptor>[
      for (final MediaTrackDescriptor descriptor in result.tracks)
        DomainMediaTrackDescriptor(
          id: DomainMediaTrackId(descriptor.id.value),
          type: switch (descriptor.type) {
            MediaTrackType.audio => DomainMediaTrackType.audio,
            MediaTrackType.subtitle => DomainMediaTrackType.subtitle,
          },
          label: descriptor.label,
          languageCode: descriptor.languageCode,
          isSelected: descriptor.isSelected,
        ),
    ],
  );
}

TrackSwitchResult playbackTrackSwitchSupportResult({
  required PlaybackCapabilityMatrix capabilityMatrix,
  DomainMediaTrackType? trackType,
}) {
  final bool canSwitchAudio =
      capabilityMatrix.supports(PlaybackCapability.audioTrackSwitching);
  final bool canSwitchSubtitle =
      capabilityMatrix.supports(PlaybackCapability.subtitleTrackSwitching);
  return switch (trackType) {
    DomainMediaTrackType.audio when !canSwitchAudio =>
      const TrackSwitchResult.unsupported(
          'Audio track switching is unsupported by the active adapter.'),
    DomainMediaTrackType.subtitle when !canSwitchSubtitle =>
      const TrackSwitchResult.unsupported(
          'Subtitle track switching is unsupported by the active adapter.'),
    null when !canSwitchAudio && !canSwitchSubtitle =>
      const TrackSwitchResult.unsupported(
          'Track switching is unsupported by the active adapter.'),
    _ => const TrackSwitchResult.success(),
  };
}

final class PlaybackController implements PlaybackControllerContract {
  const PlaybackController(
      {required ActivePlayerAdapterResolver adapterResolver})
      : _adapterResolver = adapterResolver;

  final ActivePlayerAdapterResolver _adapterResolver;

  PlayerAdapter get activeAdapter => _adapterResolver.activeAdapter;

  @override
  PlaybackCapabilityMatrix get matrix => activeAdapter.capabilities;

  @override
  PlaybackStateSnapshot get currentState =>
      const PlaybackStateSnapshot(status: PlaybackLifecycleStatus.idle);

  @override
  void addPlaybackStateObserver(PlaybackStateObserver observer) {}

  @override
  void removePlaybackStateObserver(PlaybackStateObserver observer) {}

  @override
  PlaybackSurfaceState resolveSurfaceState() {
    return playbackSurfaceStateForCapabilities(matrix);
  }

  @override
  DomainPlaybackCapabilitySummary resolveCapabilitySummary() {
    return domainPlaybackCapabilitySummaryFromMatrix(matrix);
  }

  @override
  Future<PlaybackCommandResult> open(PlaybackSource source) {
    final PlaybackCommandResult sourceSupport = playbackSourceSupportResult(
      source: source,
      capabilityMatrix: matrix,
    );
    if (!sourceSupport.isSuccess) {
      return Future<PlaybackCommandResult>.value(sourceSupport);
    }

    return activeAdapter.load(source);
  }

  @override
  Future<PlaybackCommandResult> play() => activeAdapter.play();

  @override
  Future<PlaybackCommandResult> pause() => activeAdapter.pause();

  @override
  Future<PlaybackCommandResult> seek(Duration position) =>
      activeAdapter.seek(position);

  @override
  Future<PlaybackCommandResult> stop() => activeAdapter.stop();

  @override
  Future<TrackDiscoveryResult> discoverTracks() =>
      activeAdapter.discoverTracks();

  @override
  Future<DomainTrackDiscoveryResult> discoverDomainTracks() async {
    return domainTrackDiscoveryResultFromPlayback(await discoverTracks());
  }

  @override
  Future<TrackSwitchResult> switchTrack(DomainMediaTrackId trackId,
      {DomainMediaTrackType? trackType}) {
    final TrackSwitchResult support = playbackTrackSwitchSupportResult(
      capabilityMatrix: matrix,
      trackType: trackType,
    );
    if (!support.isSuccess) {
      return Future<TrackSwitchResult>.value(support);
    }

    return activeAdapter.switchTrack(MediaTrackId(trackId.value));
  }
}

final class MockPlaybackController implements PlaybackControllerContract {
  MockPlaybackController({
    required PlaybackCapabilityMatrix matrix,
    PlaybackStateSnapshot initialState =
        const PlaybackStateSnapshot(status: PlaybackLifecycleStatus.idle),
    List<MediaTrackDescriptor> tracks = const <MediaTrackDescriptor>[],
  })  : _matrix = matrix,
        _currentState = initialState,
        _tracks = List<MediaTrackDescriptor>.unmodifiable(tracks);

  final PlaybackCapabilityMatrix _matrix;
  final List<PlaybackStateObserver> _observers = <PlaybackStateObserver>[];
  final List<MediaTrackDescriptor> _tracks;
  PlaybackStateSnapshot _currentState;

  @override
  PlaybackCapabilityMatrix get matrix => _matrix;

  @override
  PlaybackStateSnapshot get currentState => _currentState;

  @override
  void addPlaybackStateObserver(PlaybackStateObserver observer) {
    if (!_observers.contains(observer)) {
      _observers.add(observer);
    }
  }

  @override
  void removePlaybackStateObserver(PlaybackStateObserver observer) {
    _observers.remove(observer);
  }

  @override
  PlaybackSurfaceState resolveSurfaceState() {
    return playbackSurfaceStateForCapabilities(matrix);
  }

  @override
  DomainPlaybackCapabilitySummary resolveCapabilitySummary() {
    return domainPlaybackCapabilitySummaryFromMatrix(matrix);
  }

  @override
  Future<PlaybackCommandResult> open(PlaybackSource source) {
    final PlaybackCommandResult sourceSupport = playbackSourceSupportResult(
      source: source,
      capabilityMatrix: matrix,
    );
    if (!sourceSupport.isSuccess) {
      _setState(
        _snapshotWith(
          status: PlaybackLifecycleStatus.failed,
          failureReason: sourceSupport.failure?.message,
        ),
      );
      return Future<PlaybackCommandResult>.value(sourceSupport);
    }

    _setState(_snapshotWith(
        status: PlaybackLifecycleStatus.paused, sourceUri: source.uri));
    return Future<PlaybackCommandResult>.value(
        const PlaybackCommandResult.success());
  }

  @override
  Future<PlaybackCommandResult> play() {
    _setState(_snapshotWith(status: PlaybackLifecycleStatus.playing));
    return Future<PlaybackCommandResult>.value(
        const PlaybackCommandResult.success());
  }

  @override
  Future<PlaybackCommandResult> pause() {
    _setState(_snapshotWith(status: PlaybackLifecycleStatus.paused));
    return Future<PlaybackCommandResult>.value(
        const PlaybackCommandResult.success());
  }

  @override
  Future<PlaybackCommandResult> seek(Duration position) {
    _setState(
      _snapshotWith(
        timeline: PlaybackTimelineState(
          position: position,
          duration: currentState.timeline.duration,
          observedAt: mockPlaybackObservedAt,
        ),
      ),
    );
    return Future<PlaybackCommandResult>.value(
        const PlaybackCommandResult.success());
  }

  @override
  Future<PlaybackCommandResult> stop() {
    _setState(_snapshotWith(status: PlaybackLifecycleStatus.ended));
    return Future<PlaybackCommandResult>.value(
        const PlaybackCommandResult.success());
  }

  @override
  Future<TrackDiscoveryResult> discoverTracks() {
    return Future<TrackDiscoveryResult>.value(
      TrackDiscoveryResult(
        tracks: _tracks,
        capabilityMatrix: matrix,
      ),
    );
  }

  @override
  Future<DomainTrackDiscoveryResult> discoverDomainTracks() async {
    return domainTrackDiscoveryResultFromPlayback(await discoverTracks());
  }

  @override
  Future<TrackSwitchResult> switchTrack(DomainMediaTrackId trackId,
      {DomainMediaTrackType? trackType}) {
    final TrackSwitchResult support = playbackTrackSwitchSupportResult(
      capabilityMatrix: matrix,
      trackType: trackType,
    );
    if (!support.isSuccess) {
      return Future<TrackSwitchResult>.value(support);
    }

    if (trackType != null) {
      _setState(
        _snapshotWith(
          activeTracks: switch (trackType) {
            DomainMediaTrackType.audio => ActivePlaybackTrackState(
                audioTrackId: trackId,
                subtitleTrackId: currentState.activeTracks.subtitleTrackId,
              ),
            DomainMediaTrackType.subtitle => ActivePlaybackTrackState(
                audioTrackId: currentState.activeTracks.audioTrackId,
                subtitleTrackId: trackId,
              ),
          },
        ),
      );
    }
    return Future<TrackSwitchResult>.value(const TrackSwitchResult.success());
  }

  PlaybackStateSnapshot _snapshotWith({
    PlaybackLifecycleStatus? status,
    PlaybackTimelineState? timeline,
    PlaybackBufferingState? buffering,
    ActivePlaybackTrackState? activeTracks,
    PlaybackSubtitleStateSnapshot? subtitles,
    PlaybackDanmakuStateSnapshot? danmaku,
    Uri? sourceUri,
    String? failureReason,
  }) {
    // Preserve the full projection when a test command mutates one field.
    // Playback UI tests often assert subtitles, danmaku, buffering, and active
    // tracks after play/seek commands; dropping untouched fields here would
    // make the fake less faithful than the real controller.
    return PlaybackStateSnapshot(
      status: status ?? currentState.status,
      timeline: timeline ?? currentState.timeline,
      buffering: buffering ?? currentState.buffering,
      activeTracks: activeTracks ?? currentState.activeTracks,
      subtitles: subtitles ?? currentState.subtitles,
      danmaku: danmaku ?? currentState.danmaku,
      sourceUri: sourceUri ?? currentState.sourceUri,
      failureReason: failureReason,
    );
  }

  void _setState(PlaybackStateSnapshot snapshot) {
    _currentState = snapshot;
    for (final PlaybackStateObserver observer
        in List<PlaybackStateObserver>.of(_observers)) {
      observer.onPlaybackState(snapshot);
    }
  }
}

DomainPlaybackCapabilityStatus _domainStatusFromPlaybackStatus(
  CapabilityStatus status,
) {
  return DomainPlaybackCapabilityStatus(
    isSupported: status.isSupported,
    reason: status.reason,
  );
}

PlaybackCapability _playbackCapabilityForDomainId(
  DomainPlaybackCapabilityId id,
) {
  return switch (id) {
    DomainPlaybackCapabilityId.localFilePlayback =>
      PlaybackCapability.localFilePlayback,
    DomainPlaybackCapabilityId.httpPlayback => PlaybackCapability.httpPlayback,
    DomainPlaybackCapabilityId.hlsPlayback => PlaybackCapability.hlsPlayback,
    DomainPlaybackCapabilityId.playPause => PlaybackCapability.playPause,
    DomainPlaybackCapabilityId.seek => PlaybackCapability.seek,
    DomainPlaybackCapabilityId.stop => PlaybackCapability.stop,
    DomainPlaybackCapabilityId.progressReporting =>
      PlaybackCapability.progressReporting,
    DomainPlaybackCapabilityId.audioTrackDiscovery =>
      PlaybackCapability.audioTrackDiscovery,
    DomainPlaybackCapabilityId.audioTrackSwitching =>
      PlaybackCapability.audioTrackSwitching,
    DomainPlaybackCapabilityId.subtitleTrackDiscovery =>
      PlaybackCapability.subtitleTrackDiscovery,
    DomainPlaybackCapabilityId.subtitleTrackSwitching =>
      PlaybackCapability.subtitleTrackSwitching,
    DomainPlaybackCapabilityId.danmakuRendering =>
      PlaybackCapability.danmakuRendering,
    DomainPlaybackCapabilityId.secondaryPanels =>
      PlaybackCapability.secondaryPanels,
    DomainPlaybackCapabilityId.videoEnhancement =>
      PlaybackCapability.videoEnhancement,
    DomainPlaybackCapabilityId.hdrToneMapping =>
      PlaybackCapability.hdrToneMapping,
    DomainPlaybackCapabilityId.debandFiltering =>
      PlaybackCapability.debandFiltering,
    DomainPlaybackCapabilityId.anime4kPreset =>
      PlaybackCapability.anime4kPreset,
    DomainPlaybackCapabilityId.avSyncGuard => PlaybackCapability.avSyncGuard,
    DomainPlaybackCapabilityId.matrixDanmaku =>
      PlaybackCapability.matrixDanmaku,
    DomainPlaybackCapabilityId.dualSubtitles =>
      PlaybackCapability.dualSubtitles,
    DomainPlaybackCapabilityId.pgsSubtitleRendering =>
      PlaybackCapability.pgsSubtitleRendering,
    DomainPlaybackCapabilityId.assSubtitleEnhancement =>
      PlaybackCapability.assSubtitleEnhancement,
    DomainPlaybackCapabilityId.fallbackAdapter =>
      PlaybackCapability.fallbackAdapter,
  };
}

String? _trackDiscoveryUnsupportedReason(PlaybackCapabilityMatrix matrix) {
  return matrix.statusOf(PlaybackCapability.audioTrackDiscovery).reason ??
      matrix.statusOf(PlaybackCapability.subtitleTrackDiscovery).reason ??
      'Track discovery is unsupported by the active adapter.';
}
