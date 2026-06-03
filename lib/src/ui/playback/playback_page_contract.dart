import '../../domain/playback/playback_controller.dart';
import '../../domain/playback/playback_state.dart';

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

enum PlaybackPageIntentKind {
  noop,
  play,
  pause,
  seek,
  stop,
  openPanel,
  selectTrack,
}

final class PlaybackPageIntent {
  const PlaybackPageIntent._({
    required this.kind,
    this.position,
    this.panelId,
    this.trackId,
    this.trackType,
  });

  const PlaybackPageIntent.noop() : this._(kind: PlaybackPageIntentKind.noop);

  const PlaybackPageIntent.play() : this._(kind: PlaybackPageIntentKind.play);

  const PlaybackPageIntent.pause() : this._(kind: PlaybackPageIntentKind.pause);

  const PlaybackPageIntent.seek(Duration position)
      : this._(
          kind: PlaybackPageIntentKind.seek,
          position: position,
        );

  const PlaybackPageIntent.stop() : this._(kind: PlaybackPageIntentKind.stop);

  const PlaybackPageIntent.openPanel(PlaybackPagePanelId panelId)
      : this._(
          kind: PlaybackPageIntentKind.openPanel,
          panelId: panelId,
        );

  const PlaybackPageIntent.selectTrack({
    required DomainMediaTrackId trackId,
    required DomainMediaTrackType trackType,
  }) : this._(
          kind: PlaybackPageIntentKind.selectTrack,
          trackId: trackId,
          trackType: trackType,
        );

  final PlaybackPageIntentKind kind;
  final Duration? position;
  final PlaybackPagePanelId? panelId;
  final DomainMediaTrackId? trackId;
  final DomainMediaTrackType? trackType;
}

enum PlaybackPageIntentOutcome {
  executed,
  ignored,
  unsupported,
}

final class PlaybackPageIntentResult {
  const PlaybackPageIntentResult._({
    required this.outcome,
    this.commandResult,
    this.trackSwitchResult,
    this.panelId,
    this.reason,
  });

  const PlaybackPageIntentResult.executedCommand(DomainPlaybackCommandResult commandResult)
      : this._(
          outcome: PlaybackPageIntentOutcome.executed,
          commandResult: commandResult,
        );

  const PlaybackPageIntentResult.executedTrackSwitch(DomainTrackSwitchResult trackSwitchResult)
      : this._(
          outcome: PlaybackPageIntentOutcome.executed,
          trackSwitchResult: trackSwitchResult,
        );

  const PlaybackPageIntentResult.executedPanel(PlaybackPagePanelId panelId)
      : this._(
          outcome: PlaybackPageIntentOutcome.executed,
          panelId: panelId,
        );

  const PlaybackPageIntentResult.ignored(String reason)
      : this._(
          outcome: PlaybackPageIntentOutcome.ignored,
          reason: reason,
        );

  const PlaybackPageIntentResult.unsupported(String reason)
      : this._(
          outcome: PlaybackPageIntentOutcome.unsupported,
          reason: reason,
        );

  final PlaybackPageIntentOutcome outcome;
  final DomainPlaybackCommandResult? commandResult;
  final DomainTrackSwitchResult? trackSwitchResult;
  final PlaybackPagePanelId? panelId;
  final String? reason;

  bool get isExecuted => outcome == PlaybackPageIntentOutcome.executed;
}

final class PlaybackPageContract {
  const PlaybackPageContract({required PlaybackControllerContract controller}) : _controller = controller;

  final PlaybackControllerContract _controller;

  PlaybackSurfaceState resolveState() => _controller.resolveSurfaceState();

  PlaybackPageSurfaceDescriptor resolveSurface() {
    return PlaybackPageSurfaceDescriptor.fromState(resolveState());
  }

  Future<PlaybackPageIntentResult> dispatch(PlaybackPageIntent intent) async {
    final PlaybackPageSurfaceDescriptor surface = resolveSurface();
    switch (intent.kind) {
      case PlaybackPageIntentKind.noop:
        return const PlaybackPageIntentResult.ignored('Playback page intent was a no-op.');
      case PlaybackPageIntentKind.play:
        if (!surface.hasActiveControl(PlaybackPageControlId.playPause)) {
          return const PlaybackPageIntentResult.unsupported('Play/pause control is unsupported by the active surface.');
        }
        return PlaybackPageIntentResult.executedCommand(await _controller.play());
      case PlaybackPageIntentKind.pause:
        if (!surface.hasActiveControl(PlaybackPageControlId.playPause)) {
          return const PlaybackPageIntentResult.unsupported('Play/pause control is unsupported by the active surface.');
        }
        return PlaybackPageIntentResult.executedCommand(await _controller.pause());
      case PlaybackPageIntentKind.seek:
        if (!surface.hasActiveControl(PlaybackPageControlId.seek)) {
          return const PlaybackPageIntentResult.unsupported('Seek control is unsupported by the active surface.');
        }
        return PlaybackPageIntentResult.executedCommand(await _controller.seek(intent.position!));
      case PlaybackPageIntentKind.stop:
        if (!surface.hasActiveControl(PlaybackPageControlId.stop)) {
          return const PlaybackPageIntentResult.unsupported('Stop control is unsupported by the active surface.');
        }
        return PlaybackPageIntentResult.executedCommand(await _controller.stop());
      case PlaybackPageIntentKind.openPanel:
        final PlaybackPagePanelId panelId = intent.panelId!;
        if (!surface.hasActivePanel(panelId)) {
          return const PlaybackPageIntentResult.unsupported('Panel is unsupported by the active surface.');
        }
        return PlaybackPageIntentResult.executedPanel(panelId);
      case PlaybackPageIntentKind.selectTrack:
        final PlaybackPageControlId controlId = switch (intent.trackType!) {
          DomainMediaTrackType.audio => PlaybackPageControlId.audioTracks,
          DomainMediaTrackType.subtitle => PlaybackPageControlId.subtitleTracks,
        };
        if (!surface.hasActiveControl(controlId)) {
          return const PlaybackPageIntentResult.unsupported('Track selection is unsupported by the active surface.');
        }
        return PlaybackPageIntentResult.executedTrackSwitch(
          await _controller.switchTrack(intent.trackId!, trackType: intent.trackType),
        );
    }
  }
}
