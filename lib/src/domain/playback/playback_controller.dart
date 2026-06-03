import '../../playback/capability_matrix.dart';
import '../../playback/player_adapter.dart';
import '../../playback/track_management.dart';
import 'playback_state.dart';

typedef DomainPlaybackCommandResult = PlaybackCommandResult;
typedef DomainTrackSwitchResult = TrackSwitchResult;

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

final class PlaybackSurfaceState {
  const PlaybackSurfaceState({
    required this.visibleControls,
    required this.availablePanels,
  });

  final Set<PlaybackSurfaceControl> visibleControls;
  final Set<PlaybackSurfacePanel> availablePanels;
}

PlaybackSurfaceState playbackSurfaceStateForCapabilities(PlaybackCapabilityMatrix capabilityMatrix) {
  return PlaybackSurfaceState(
    visibleControls: <PlaybackSurfaceControl>{
      if (capabilityMatrix.supports(PlaybackCapability.playPause)) PlaybackSurfaceControl.playPause,
      if (capabilityMatrix.supports(PlaybackCapability.seek)) PlaybackSurfaceControl.seek,
      if (capabilityMatrix.supports(PlaybackCapability.stop)) PlaybackSurfaceControl.stop,
      if (capabilityMatrix.supports(PlaybackCapability.progressReporting)) PlaybackSurfaceControl.progress,
      if (capabilityMatrix.supports(PlaybackCapability.audioTrackSwitching)) PlaybackSurfaceControl.audioTracks,
      if (capabilityMatrix.supports(PlaybackCapability.subtitleTrackSwitching)) PlaybackSurfaceControl.subtitleTracks,
    },
    availablePanels: <PlaybackSurfacePanel>{
      if (capabilityMatrix.supports(PlaybackCapability.secondaryPanels)) PlaybackSurfacePanel.tracks,
    },
  );
}

abstract interface class PlaybackControllerContract implements ActivePlaybackCapabilities, PlaybackStateObservable {
  PlaybackSurfaceState resolveSurfaceState();

  Future<PlaybackCommandResult> open(PlaybackSource source);

  Future<PlaybackCommandResult> play();

  Future<PlaybackCommandResult> pause();

  Future<PlaybackCommandResult> seek(Duration position);

  Future<PlaybackCommandResult> stop();

  Future<TrackDiscoveryResult> discoverTracks();

  Future<TrackSwitchResult> switchTrack(DomainMediaTrackId trackId, {DomainMediaTrackType? trackType});
}

TrackSwitchResult playbackTrackSwitchSupportResult({
  required PlaybackCapabilityMatrix capabilityMatrix,
  DomainMediaTrackType? trackType,
}) {
  final bool canSwitchAudio = capabilityMatrix.supports(PlaybackCapability.audioTrackSwitching);
  final bool canSwitchSubtitle = capabilityMatrix.supports(PlaybackCapability.subtitleTrackSwitching);
  return switch (trackType) {
    DomainMediaTrackType.audio when !canSwitchAudio =>
      const TrackSwitchResult.unsupported('Audio track switching is unsupported by the active adapter.'),
    DomainMediaTrackType.subtitle when !canSwitchSubtitle =>
      const TrackSwitchResult.unsupported('Subtitle track switching is unsupported by the active adapter.'),
    null when !canSwitchAudio && !canSwitchSubtitle =>
      const TrackSwitchResult.unsupported('Track switching is unsupported by the active adapter.'),
    _ => const TrackSwitchResult.success(),
  };
}

final class PlaybackController implements PlaybackControllerContract {
  const PlaybackController({required ActivePlayerAdapterResolver adapterResolver})
      : _adapterResolver = adapterResolver;

  final ActivePlayerAdapterResolver _adapterResolver;

  PlayerAdapter get activeAdapter => _adapterResolver.activeAdapter;

  @override
  PlaybackCapabilityMatrix get matrix => activeAdapter.capabilities;

  @override
  PlaybackStateSnapshot get currentState => const PlaybackStateSnapshot(status: PlaybackLifecycleStatus.idle);

  @override
  void addPlaybackStateObserver(PlaybackStateObserver observer) {}

  @override
  void removePlaybackStateObserver(PlaybackStateObserver observer) {}

  @override
  PlaybackSurfaceState resolveSurfaceState() {
    return playbackSurfaceStateForCapabilities(matrix);
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
  Future<PlaybackCommandResult> seek(Duration position) => activeAdapter.seek(position);

  @override
  Future<PlaybackCommandResult> stop() => activeAdapter.stop();

  @override
  Future<TrackDiscoveryResult> discoverTracks() => activeAdapter.discoverTracks();

  @override
  Future<TrackSwitchResult> switchTrack(DomainMediaTrackId trackId, {DomainMediaTrackType? trackType}) {
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
    PlaybackStateSnapshot initialState = const PlaybackStateSnapshot(status: PlaybackLifecycleStatus.idle),
  })  : _matrix = matrix,
        _currentState = initialState;

  final PlaybackCapabilityMatrix _matrix;
  final List<PlaybackStateObserver> _observers = <PlaybackStateObserver>[];
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

    _setState(_snapshotWith(status: PlaybackLifecycleStatus.paused, sourceUri: source.uri));
    return Future<PlaybackCommandResult>.value(const PlaybackCommandResult.success());
  }

  @override
  Future<PlaybackCommandResult> play() {
    _setState(_snapshotWith(status: PlaybackLifecycleStatus.playing));
    return Future<PlaybackCommandResult>.value(const PlaybackCommandResult.success());
  }

  @override
  Future<PlaybackCommandResult> pause() {
    _setState(_snapshotWith(status: PlaybackLifecycleStatus.paused));
    return Future<PlaybackCommandResult>.value(const PlaybackCommandResult.success());
  }

  @override
  Future<PlaybackCommandResult> seek(Duration position) {
    _setState(
      _snapshotWith(
        timeline: PlaybackTimelineState(
          position: position,
          duration: currentState.timeline.duration,
          observedAt: DateTime.utc(2026, 6, 3, 12, 0),
        ),
      ),
    );
    return Future<PlaybackCommandResult>.value(const PlaybackCommandResult.success());
  }

  @override
  Future<PlaybackCommandResult> stop() {
    _setState(_snapshotWith(status: PlaybackLifecycleStatus.ended));
    return Future<PlaybackCommandResult>.value(const PlaybackCommandResult.success());
  }

  @override
  Future<TrackDiscoveryResult> discoverTracks() {
    return Future<TrackDiscoveryResult>.value(
      TrackDiscoveryResult(
        tracks: const <MediaTrackDescriptor>[],
        capabilityMatrix: matrix,
      ),
    );
  }

  @override
  Future<TrackSwitchResult> switchTrack(DomainMediaTrackId trackId, {DomainMediaTrackType? trackType}) {
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
    Uri? sourceUri,
    String? failureReason,
  }) {
    return PlaybackStateSnapshot(
      status: status ?? currentState.status,
      timeline: timeline ?? currentState.timeline,
      buffering: buffering ?? currentState.buffering,
      activeTracks: activeTracks ?? currentState.activeTracks,
      sourceUri: sourceUri ?? currentState.sourceUri,
      failureReason: failureReason,
    );
  }

  void _setState(PlaybackStateSnapshot snapshot) {
    _currentState = snapshot;
    for (final PlaybackStateObserver observer in List<PlaybackStateObserver>.of(_observers)) {
      observer.onPlaybackState(snapshot);
    }
  }
}
