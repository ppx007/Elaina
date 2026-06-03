import '../../playback/capability_matrix.dart';
import '../../playback/player_adapter.dart';
import '../../playback/track_management.dart';

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

final class PlaybackController implements ActivePlaybackCapabilities {
  const PlaybackController({required ActivePlayerAdapterResolver adapterResolver})
      : _adapterResolver = adapterResolver;

  final ActivePlayerAdapterResolver _adapterResolver;

  PlayerAdapter get activeAdapter => _adapterResolver.activeAdapter;

  @override
  PlaybackCapabilityMatrix get matrix => activeAdapter.capabilities;

  PlaybackSurfaceState resolveSurfaceState() {
    final PlaybackCapabilityMatrix capabilityMatrix = matrix;
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

  Future<PlaybackCommandResult> play() => activeAdapter.play();

  Future<PlaybackCommandResult> pause() => activeAdapter.pause();

  Future<PlaybackCommandResult> seek(Duration position) => activeAdapter.seek(position);

  Future<PlaybackCommandResult> stop() => activeAdapter.stop();

  Future<TrackDiscoveryResult> discoverTracks() => activeAdapter.discoverTracks();

  Future<TrackSwitchResult> switchTrack(MediaTrackId trackId) {
    final PlaybackCapabilityMatrix capabilityMatrix = matrix;
    final bool canSwitchAudio = capabilityMatrix.supports(PlaybackCapability.audioTrackSwitching);
    final bool canSwitchSubtitle = capabilityMatrix.supports(PlaybackCapability.subtitleTrackSwitching);
    if (!canSwitchAudio && !canSwitchSubtitle) {
      return Future<TrackSwitchResult>.value(
        const TrackSwitchResult.unsupported('Track switching is unsupported by the active adapter.'),
      );
    }

    return activeAdapter.switchTrack(trackId);
  }
}
