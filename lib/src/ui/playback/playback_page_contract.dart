import '../../domain/playback/playback_controller.dart';
import '../../domain/playback/playback_state.dart';
import '../../domain/playback/subtitle_style.dart';

const String playbackPageMatrixDanmakuRendererSource =
    'flutter-custom-painter-overlay';

/// UI controls the playback page is allowed to expose.
///
/// The page resolves these from domain surface state before dispatching any
/// intent, so unsupported controls cannot call into the controller by accident.
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

final class PlaybackPageSubtitleCueDescriptor {
  const PlaybackPageSubtitleCueDescriptor({
    required this.text,
    required this.start,
    required this.end,
    this.hasEmbeddedStyle = false,
    this.styleSource = DomainSubtitleStyleSource.userDefault,
  });

  final String text;
  final Duration start;
  final Duration end;
  final bool hasEmbeddedStyle;
  final DomainSubtitleStyleSource styleSource;
}

final class PlaybackPageSubtitleOverlayDescriptor {
  PlaybackPageSubtitleOverlayDescriptor({
    this.selectedTrackId,
    List<PlaybackPageSubtitleCueDescriptor> cues =
        const <PlaybackPageSubtitleCueDescriptor>[],
    this.offset = Duration.zero,
    this.styleProfile = SubtitleStyleProfile.defaults,
    this.failureReason,
  }) : cues = List<PlaybackPageSubtitleCueDescriptor>.unmodifiable(cues);

  const PlaybackPageSubtitleOverlayDescriptor.none()
      : selectedTrackId = null,
        cues = const <PlaybackPageSubtitleCueDescriptor>[],
        offset = Duration.zero,
        styleProfile = SubtitleStyleProfile.defaults,
        failureReason = null;

  factory PlaybackPageSubtitleOverlayDescriptor.fromState(
      PlaybackSubtitleStateSnapshot state) {
    return PlaybackPageSubtitleOverlayDescriptor(
      selectedTrackId: state.selectedTrackId,
      cues: <PlaybackPageSubtitleCueDescriptor>[
        for (final DomainSubtitleCueDescriptor cue in state.activeCues)
          PlaybackPageSubtitleCueDescriptor(
            text: cue.text,
            start: cue.start,
            end: cue.end,
            hasEmbeddedStyle: cue.hasEmbeddedStyle,
            styleSource: _styleSourceForCue(cue, state.styleProfile),
          ),
      ],
      offset: state.offset,
      styleProfile: state.styleProfile,
      failureReason: state.failureReason,
    );
  }

  final String? selectedTrackId;
  final List<PlaybackPageSubtitleCueDescriptor> cues;
  final Duration offset;
  final SubtitleStyleProfile styleProfile;
  final String? failureReason;

  bool get hasVisibleCues => cues.isNotEmpty;
}

DomainSubtitleStyleSource _styleSourceForCue(
  DomainSubtitleCueDescriptor cue,
  SubtitleStyleProfile profile,
) {
  if (!cue.hasEmbeddedStyle) return DomainSubtitleStyleSource.userDefault;
  return profile.forceOverrideEmbeddedStyle
      ? DomainSubtitleStyleSource.forcedUserOverride
      : DomainSubtitleStyleSource.embedded;
}

final class PlaybackPageDanmakuCommentDescriptor {
  const PlaybackPageDanmakuCommentDescriptor({
    required this.id,
    required this.timestamp,
    required this.text,
    this.colorArgb,
  });

  final String id;
  final Duration timestamp;
  final String text;
  final int? colorArgb;
}

final class PlaybackPageDanmakuLaneDescriptor {
  PlaybackPageDanmakuLaneDescriptor({
    required this.mode,
    Iterable<PlaybackPageDanmakuCommentDescriptor> comments =
        const <PlaybackPageDanmakuCommentDescriptor>[],
  }) : comments =
            List<PlaybackPageDanmakuCommentDescriptor>.unmodifiable(comments);

  final DomainDanmakuMode mode;
  final List<PlaybackPageDanmakuCommentDescriptor> comments;
}

final class PlaybackPageDanmakuOverlayDescriptor {
  PlaybackPageDanmakuOverlayDescriptor({
    this.clockPosition = Duration.zero,
    Iterable<PlaybackPageDanmakuLaneDescriptor> lanes =
        const <PlaybackPageDanmakuLaneDescriptor>[],
    this.failureReason,
  }) : lanes = List<PlaybackPageDanmakuLaneDescriptor>.unmodifiable(lanes);

  const PlaybackPageDanmakuOverlayDescriptor.none()
      : clockPosition = Duration.zero,
        lanes = const <PlaybackPageDanmakuLaneDescriptor>[],
        failureReason = null;

  factory PlaybackPageDanmakuOverlayDescriptor.fromState(
    PlaybackDanmakuStateSnapshot state,
  ) {
    return PlaybackPageDanmakuOverlayDescriptor(
      clockPosition: state.clockPosition,
      lanes: <PlaybackPageDanmakuLaneDescriptor>[
        for (final DomainDanmakuLaneDescriptor lane in state.lanes)
          PlaybackPageDanmakuLaneDescriptor(
            mode: lane.mode,
            comments: <PlaybackPageDanmakuCommentDescriptor>[
              for (final DomainDanmakuCommentDescriptor comment
                  in lane.comments)
                PlaybackPageDanmakuCommentDescriptor(
                  id: comment.id,
                  timestamp: comment.timestamp,
                  text: comment.text,
                  colorArgb: comment.colorArgb,
                ),
            ],
          ),
      ],
      failureReason: state.failureReason,
    );
  }

  final Duration clockPosition;
  final List<PlaybackPageDanmakuLaneDescriptor> lanes;
  final String? failureReason;

  bool get hasVisibleComments {
    return lanes.any(
      (PlaybackPageDanmakuLaneDescriptor lane) => lane.comments.isNotEmpty,
    );
  }
}

final class PlaybackPageMatrixDanmakuCommentDescriptor {
  const PlaybackPageMatrixDanmakuCommentDescriptor({
    required this.id,
    required this.timestamp,
    required this.text,
    required this.mode,
    this.colorArgb,
  });

  final String id;
  final Duration timestamp;
  final String text;
  final DomainDanmakuMode mode;
  final int? colorArgb;
}

final class PlaybackPageMatrixDanmakuOverlayDescriptor {
  PlaybackPageMatrixDanmakuOverlayDescriptor({
    this.clockPosition = Duration.zero,
    Iterable<double> transformValues =
        DomainCaptionTransform4Descriptor.identityValues,
    Iterable<PlaybackPageMatrixDanmakuCommentDescriptor> comments =
        const <PlaybackPageMatrixDanmakuCommentDescriptor>[],
    this.rendererSource,
    this.failureReason,
  })  : transformValues = List<double>.unmodifiable(transformValues),
        comments =
            List<PlaybackPageMatrixDanmakuCommentDescriptor>.unmodifiable(
          comments,
        );

  const PlaybackPageMatrixDanmakuOverlayDescriptor.none()
      : clockPosition = Duration.zero,
        transformValues = DomainCaptionTransform4Descriptor.identityValues,
        comments = const <PlaybackPageMatrixDanmakuCommentDescriptor>[],
        rendererSource = null,
        failureReason = null;

  factory PlaybackPageMatrixDanmakuOverlayDescriptor.fromState(
    PlaybackMatrixDanmakuStateSnapshot state,
  ) {
    return PlaybackPageMatrixDanmakuOverlayDescriptor(
      clockPosition: state.clockPosition,
      transformValues: state.transform.values,
      comments: <PlaybackPageMatrixDanmakuCommentDescriptor>[
        for (final DomainMatrixDanmakuCommentDescriptor comment
            in state.comments)
          PlaybackPageMatrixDanmakuCommentDescriptor(
            id: comment.id,
            timestamp: comment.timestamp,
            text: comment.text,
            mode: comment.mode,
            colorArgb: comment.colorArgb,
          ),
      ],
      rendererSource: state.rendererSource,
      failureReason: state.failureReason,
    );
  }

  factory PlaybackPageMatrixDanmakuOverlayDescriptor.fromDanmakuState(
    PlaybackDanmakuStateSnapshot state,
  ) {
    if (state.matrix.hasVisibleComments ||
        state.matrix.rendererSource != null ||
        state.matrix.failureReason != null) {
      return PlaybackPageMatrixDanmakuOverlayDescriptor.fromState(state.matrix);
    }
    return PlaybackPageMatrixDanmakuOverlayDescriptor(
      clockPosition: state.clockPosition,
      comments: <PlaybackPageMatrixDanmakuCommentDescriptor>[
        for (final DomainDanmakuLaneDescriptor lane in state.lanes)
          for (final DomainDanmakuCommentDescriptor comment in lane.comments)
            PlaybackPageMatrixDanmakuCommentDescriptor(
              id: comment.id,
              timestamp: comment.timestamp,
              text: comment.text,
              mode: comment.mode,
              colorArgb: comment.colorArgb,
            ),
      ],
      rendererSource: playbackPageMatrixDanmakuRendererSource,
      failureReason: state.failureReason,
    );
  }

  final Duration clockPosition;
  final List<double> transformValues;
  final List<PlaybackPageMatrixDanmakuCommentDescriptor> comments;
  final String? rendererSource;
  final String? failureReason;

  int get renderedCommentCount => comments.length;

  bool get hasVisibleComments => comments.isNotEmpty;
}

final class PlaybackPageSurfaceDescriptor {
  const PlaybackPageSurfaceDescriptor({
    required this.controls,
    required this.panels,
    this.subtitleOverlay = const PlaybackPageSubtitleOverlayDescriptor.none(),
    this.danmakuOverlay = const PlaybackPageDanmakuOverlayDescriptor.none(),
    this.matrixDanmakuOverlay =
        const PlaybackPageMatrixDanmakuOverlayDescriptor.none(),
  });

  factory PlaybackPageSurfaceDescriptor.fromState(
    PlaybackSurfaceState state, {
    PlaybackSubtitleStateSnapshot subtitles =
        const PlaybackSubtitleStateSnapshot.none(),
    PlaybackDanmakuStateSnapshot danmaku =
        const PlaybackDanmakuStateSnapshot.none(),
    bool matrixDanmakuSupported = false,
  }) {
    return PlaybackPageSurfaceDescriptor(
      controls: <PlaybackPageControlDescriptor>[
        if (state.visibleControls.contains(PlaybackSurfaceControl.playPause))
          const PlaybackPageControlDescriptor(
              id: PlaybackPageControlId.playPause),
        if (state.visibleControls.contains(PlaybackSurfaceControl.seek))
          const PlaybackPageControlDescriptor(id: PlaybackPageControlId.seek),
        if (state.visibleControls.contains(PlaybackSurfaceControl.stop))
          const PlaybackPageControlDescriptor(id: PlaybackPageControlId.stop),
        if (state.visibleControls.contains(PlaybackSurfaceControl.progress))
          const PlaybackPageControlDescriptor(
              id: PlaybackPageControlId.progress),
        if (state.visibleControls.contains(PlaybackSurfaceControl.audioTracks))
          const PlaybackPageControlDescriptor(
              id: PlaybackPageControlId.audioTracks),
        if (state.visibleControls
            .contains(PlaybackSurfaceControl.subtitleTracks))
          const PlaybackPageControlDescriptor(
              id: PlaybackPageControlId.subtitleTracks),
      ],
      panels: <PlaybackPagePanelDescriptor>[
        if (state.availablePanels.contains(PlaybackSurfacePanel.tracks))
          const PlaybackPagePanelDescriptor(id: PlaybackPagePanelId.tracks),
      ],
      subtitleOverlay:
          PlaybackPageSubtitleOverlayDescriptor.fromState(subtitles),
      danmakuOverlay: PlaybackPageDanmakuOverlayDescriptor.fromState(danmaku),
      matrixDanmakuOverlay: matrixDanmakuSupported
          ? PlaybackPageMatrixDanmakuOverlayDescriptor.fromDanmakuState(danmaku)
          : const PlaybackPageMatrixDanmakuOverlayDescriptor.none(),
    );
  }

  final List<PlaybackPageControlDescriptor> controls;
  final List<PlaybackPagePanelDescriptor> panels;
  final PlaybackPageSubtitleOverlayDescriptor subtitleOverlay;
  final PlaybackPageDanmakuOverlayDescriptor danmakuOverlay;
  final PlaybackPageMatrixDanmakuOverlayDescriptor matrixDanmakuOverlay;

  bool hasActiveControl(PlaybackPageControlId id) {
    return controls.any(
      (PlaybackPageControlDescriptor control) =>
          control.id == id && control.isVisible && control.isEnabled,
    );
  }

  bool hasActivePanel(PlaybackPagePanelId id) {
    return panels.any(
      (PlaybackPagePanelDescriptor panel) =>
          panel.id == id && panel.isVisible && panel.isEnabled,
    );
  }
}

/// A user action expressed at page level before it becomes a controller call.
///
/// Keeping page intent separate from controller commands lets the page gate
/// panels, tracks, and transport actions through the current surface descriptor.
enum PlaybackPageIntentKind {
  noop,
  play,
  pause,
  seek,
  stop,
  openPanel,
  selectTrack,
  applyVideoEnhancement,
  updateSubtitleStyle,
  resetSubtitleStyle,
}

final class PlaybackPageIntent {
  const PlaybackPageIntent._({
    required this.kind,
    this.position,
    this.panelId,
    this.trackId,
    this.trackType,
    this.videoEnhancementProfile,
    this.subtitleStyleProfile,
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

  const PlaybackPageIntent.applyVideoEnhancement(
    DomainVideoEnhancementProfileDescriptor profile,
  ) : this._(
          kind: PlaybackPageIntentKind.applyVideoEnhancement,
          videoEnhancementProfile: profile,
        );

  const PlaybackPageIntent.updateSubtitleStyle(
    SubtitleStyleProfile profile,
  ) : this._(
          kind: PlaybackPageIntentKind.updateSubtitleStyle,
          subtitleStyleProfile: profile,
        );

  const PlaybackPageIntent.resetSubtitleStyle()
      : this._(kind: PlaybackPageIntentKind.resetSubtitleStyle);

  final PlaybackPageIntentKind kind;
  final Duration? position;
  final PlaybackPagePanelId? panelId;
  final DomainMediaTrackId? trackId;
  final DomainMediaTrackType? trackType;
  final DomainVideoEnhancementProfileDescriptor? videoEnhancementProfile;
  final SubtitleStyleProfile? subtitleStyleProfile;
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
    this.videoEnhancementResult,
    this.panelId,
    this.reason,
  });

  const PlaybackPageIntentResult.executedCommand(
      DomainPlaybackCommandResult commandResult)
      : this._(
          outcome: PlaybackPageIntentOutcome.executed,
          commandResult: commandResult,
        );

  const PlaybackPageIntentResult.executedTrackSwitch(
      DomainTrackSwitchResult trackSwitchResult)
      : this._(
          outcome: PlaybackPageIntentOutcome.executed,
          trackSwitchResult: trackSwitchResult,
        );

  const PlaybackPageIntentResult.executedVideoEnhancement(
      DomainVideoEnhancementApplyResult videoEnhancementResult)
      : this._(
          outcome: PlaybackPageIntentOutcome.executed,
          videoEnhancementResult: videoEnhancementResult,
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
  final DomainVideoEnhancementApplyResult? videoEnhancementResult;
  final PlaybackPagePanelId? panelId;
  final String? reason;

  bool get isExecuted => outcome == PlaybackPageIntentOutcome.executed;
}

final class PlaybackPageContract {
  const PlaybackPageContract({required PlaybackControllerContract controller})
      : _controller = controller;

  final PlaybackControllerContract _controller;

  PlaybackSurfaceState resolveState() => _controller.resolveSurfaceState();

  PlaybackPageSurfaceDescriptor resolveSurface() {
    final DomainPlaybackCapabilityStatus matrixDanmaku =
        _controller.resolveCapabilitySummary().statusOf(
              DomainPlaybackCapabilityId.matrixDanmaku,
            );
    return PlaybackPageSurfaceDescriptor.fromState(
      resolveState(),
      subtitles: _controller.currentState.subtitles,
      danmaku: _controller.currentState.danmaku,
      matrixDanmakuSupported: matrixDanmaku.isSupported,
    );
  }

  Future<PlaybackPageIntentResult> dispatch(PlaybackPageIntent intent) async {
    final PlaybackPageSurfaceDescriptor surface = resolveSurface();
    switch (intent.kind) {
      case PlaybackPageIntentKind.noop:
        return const PlaybackPageIntentResult.ignored(
            'Playback page intent was a no-op.');
      case PlaybackPageIntentKind.play:
        if (!surface.hasActiveControl(PlaybackPageControlId.playPause)) {
          return const PlaybackPageIntentResult.unsupported(
              'Play/pause control is unsupported by the active surface.');
        }
        return PlaybackPageIntentResult.executedCommand(
            await _controller.play());
      case PlaybackPageIntentKind.pause:
        if (!surface.hasActiveControl(PlaybackPageControlId.playPause)) {
          return const PlaybackPageIntentResult.unsupported(
              'Play/pause control is unsupported by the active surface.');
        }
        return PlaybackPageIntentResult.executedCommand(
            await _controller.pause());
      case PlaybackPageIntentKind.seek:
        if (!surface.hasActiveControl(PlaybackPageControlId.seek)) {
          return const PlaybackPageIntentResult.unsupported(
              'Seek control is unsupported by the active surface.');
        }
        return PlaybackPageIntentResult.executedCommand(
            await _controller.seek(intent.position!));
      case PlaybackPageIntentKind.stop:
        if (!surface.hasActiveControl(PlaybackPageControlId.stop)) {
          return const PlaybackPageIntentResult.unsupported(
              'Stop control is unsupported by the active surface.');
        }
        return PlaybackPageIntentResult.executedCommand(
            await _controller.stop());
      case PlaybackPageIntentKind.openPanel:
        final PlaybackPagePanelId panelId = intent.panelId!;
        if (!surface.hasActivePanel(panelId)) {
          return const PlaybackPageIntentResult.unsupported(
              'Panel is unsupported by the active surface.');
        }
        return PlaybackPageIntentResult.executedPanel(panelId);
      case PlaybackPageIntentKind.selectTrack:
        final PlaybackPageControlId controlId = switch (intent.trackType!) {
          DomainMediaTrackType.audio => PlaybackPageControlId.audioTracks,
          DomainMediaTrackType.subtitle => PlaybackPageControlId.subtitleTracks,
        };
        if (!surface.hasActiveControl(controlId)) {
          return const PlaybackPageIntentResult.unsupported(
              'Track selection is unsupported by the active surface.');
        }
        return PlaybackPageIntentResult.executedTrackSwitch(
          await _controller.switchTrack(intent.trackId!,
              trackType: intent.trackType),
        );
      case PlaybackPageIntentKind.applyVideoEnhancement:
        final DomainVideoEnhancementProfileDescriptor profile =
            intent.videoEnhancementProfile!;
        final DomainPlaybackCapabilitySummary capabilities =
            _controller.resolveCapabilitySummary();
        final DomainPlaybackCapabilityStatus videoEnhancement =
            capabilities.statusOf(DomainPlaybackCapabilityId.videoEnhancement);
        if (!videoEnhancement.isSupported) {
          return PlaybackPageIntentResult.unsupported(
            videoEnhancement.reason ?? 'Video enhancement is unsupported.',
          );
        }
        if (profile.preset != VideoEnhancementPresetSelection.off) {
          final DomainPlaybackCapabilityStatus anime4k =
              capabilities.statusOf(DomainPlaybackCapabilityId.anime4kPreset);
          if (!anime4k.isSupported) {
            return PlaybackPageIntentResult.unsupported(
              anime4k.reason ?? 'Anime4K preset is unsupported.',
            );
          }
        }
        return PlaybackPageIntentResult.executedVideoEnhancement(
          profile.preset == VideoEnhancementPresetSelection.off
              ? await _controller.disableVideoEnhancement()
              : await _controller.applyVideoEnhancement(profile),
        );
      case PlaybackPageIntentKind.updateSubtitleStyle:
      case PlaybackPageIntentKind.resetSubtitleStyle:
        return const PlaybackPageIntentResult.ignored(
          'Subtitle style intents are handled by the page driver.',
        );
    }
  }
}
