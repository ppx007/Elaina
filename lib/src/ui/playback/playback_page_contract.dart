import '../../domain/playback/playback_controller.dart';

enum PlaybackPageControlId {
  playPause,
  seek,
  stop,
  progress,
  audioTracks,
  subtitleTracks,
}

enum PlaybackPagePanelId {
  tracks,
}

final class PlaybackPageControlDescriptor {
  const PlaybackPageControlDescriptor({
    required this.id,
    this.isVisible = true,
    this.isEnabled = true,
  });

  final PlaybackPageControlId id;
  final bool isVisible;
  final bool isEnabled;
}

final class PlaybackPagePanelDescriptor {
  const PlaybackPagePanelDescriptor({
    required this.id,
    this.isVisible = true,
    this.isEnabled = true,
  });

  final PlaybackPagePanelId id;
  final bool isVisible;
  final bool isEnabled;
}

final class PlaybackPageSurfaceDescriptor {
  const PlaybackPageSurfaceDescriptor({
    required this.controls,
    required this.panels,
  });

  factory PlaybackPageSurfaceDescriptor.fromState(PlaybackSurfaceState state) {
    return PlaybackPageSurfaceDescriptor(
      controls: <PlaybackPageControlDescriptor>[
        if (state.visibleControls.contains(PlaybackSurfaceControl.playPause))
          const PlaybackPageControlDescriptor(id: PlaybackPageControlId.playPause),
        if (state.visibleControls.contains(PlaybackSurfaceControl.seek))
          const PlaybackPageControlDescriptor(id: PlaybackPageControlId.seek),
        if (state.visibleControls.contains(PlaybackSurfaceControl.stop))
          const PlaybackPageControlDescriptor(id: PlaybackPageControlId.stop),
        if (state.visibleControls.contains(PlaybackSurfaceControl.progress))
          const PlaybackPageControlDescriptor(id: PlaybackPageControlId.progress),
        if (state.visibleControls.contains(PlaybackSurfaceControl.audioTracks))
          const PlaybackPageControlDescriptor(id: PlaybackPageControlId.audioTracks),
        if (state.visibleControls.contains(PlaybackSurfaceControl.subtitleTracks))
          const PlaybackPageControlDescriptor(id: PlaybackPageControlId.subtitleTracks),
      ],
      panels: <PlaybackPagePanelDescriptor>[
        if (state.availablePanels.contains(PlaybackSurfacePanel.tracks))
          const PlaybackPagePanelDescriptor(id: PlaybackPagePanelId.tracks),
      ],
    );
  }

  final List<PlaybackPageControlDescriptor> controls;
  final List<PlaybackPagePanelDescriptor> panels;

  bool hasActiveControl(PlaybackPageControlId id) {
    return controls.any(
      (PlaybackPageControlDescriptor control) => control.id == id && control.isVisible && control.isEnabled,
    );
  }

  bool hasActivePanel(PlaybackPagePanelId id) {
    return panels.any(
      (PlaybackPagePanelDescriptor panel) => panel.id == id && panel.isVisible && panel.isEnabled,
    );
  }
}

final class PlaybackPageContract {
  const PlaybackPageContract({required PlaybackController controller}) : _controller = controller;

  final PlaybackController _controller;

  PlaybackSurfaceState resolveState() => _controller.resolveSurfaceState();

  PlaybackPageSurfaceDescriptor resolveSurface() {
    return PlaybackPageSurfaceDescriptor.fromState(resolveState());
  }
}
