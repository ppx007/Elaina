import 'package:flutter/material.dart';

import '../../domain/playback/playback_controller.dart';
import '../../domain/playback/playback_state.dart';
import 'playback_page_contract.dart';

final DateTime mockPlaybackShellObservedAt = DateTime.utc(2026, 6, 3, 12, 0);
/// Demo seek target used by the legacy shell driver.
///
/// Production playback controls use the controller contract and redesigned
/// production page; this shell remains as a lightweight compatibility surface.
const Duration demoPlaybackSeekPosition = Duration(seconds: 42);

/// Driver boundary for the legacy Flutter-only playback shell.
///
/// New playback UI should prefer the production driver/page pair; this
/// interface exists so older shell tests can keep exercising widget wiring.
abstract interface class FlutterPlaybackShellDriver {
  PlaybackStateSnapshot get snapshot;

  PlaybackPageSurfaceDescriptor get surface;

  PlaybackPageIntentResult? get lastIntentResult;

  PlaybackPagePanelId? get activePanel;

  void addListener(VoidCallback listener);

  void removeListener(VoidCallback listener);

  Future<void> dispatch(PlaybackPageIntent intent);
}

final class MockFlutterPlaybackShellDriver extends ChangeNotifier
    implements FlutterPlaybackShellDriver {
  MockFlutterPlaybackShellDriver({
    required PlaybackStateSnapshot initialSnapshot,
    required PlaybackPageSurfaceDescriptor surface,
  })  : _snapshot = initialSnapshot,
        _surface = surface;

  PlaybackStateSnapshot _snapshot;
  final PlaybackPageSurfaceDescriptor _surface;
  PlaybackPageIntentResult? _lastIntentResult;
  PlaybackPagePanelId? _activePanel;

  @override
  PlaybackStateSnapshot get snapshot => _snapshot;

  @override
  PlaybackPageSurfaceDescriptor get surface => _surface;

  @override
  PlaybackPageIntentResult? get lastIntentResult => _lastIntentResult;

  @override
  PlaybackPagePanelId? get activePanel => _activePanel;

  @override
  Future<void> dispatch(PlaybackPageIntent intent) async {
    switch (intent.kind) {
      case PlaybackPageIntentKind.noop:
        _lastIntentResult = const PlaybackPageIntentResult.ignored(
            'Mock shell ignored no-op intent.');
      case PlaybackPageIntentKind.play:
        _snapshot = _snapshotWith(status: PlaybackLifecycleStatus.playing);
        _lastIntentResult = const PlaybackPageIntentResult.ignored(
            'Mock shell recorded play intent.');
      case PlaybackPageIntentKind.pause:
        _snapshot = _snapshotWith(status: PlaybackLifecycleStatus.paused);
        _lastIntentResult = const PlaybackPageIntentResult.ignored(
            'Mock shell recorded pause intent.');
      case PlaybackPageIntentKind.seek:
        _snapshot = _snapshotWith(
          timeline: PlaybackTimelineState(
            position: intent.position ?? _snapshot.timeline.position,
            duration: _snapshot.timeline.duration,
            observedAt: mockPlaybackShellObservedAt,
          ),
        );
        _lastIntentResult = const PlaybackPageIntentResult.ignored(
            'Mock shell recorded seek intent.');
      case PlaybackPageIntentKind.stop:
        _snapshot = _snapshotWith(status: PlaybackLifecycleStatus.ended);
        _lastIntentResult = const PlaybackPageIntentResult.ignored(
            'Mock shell recorded stop intent.');
      case PlaybackPageIntentKind.openPanel:
        _activePanel = intent.panelId;
        _lastIntentResult =
            PlaybackPageIntentResult.executedPanel(intent.panelId!);
      case PlaybackPageIntentKind.selectTrack:
        _snapshot = _snapshotWith(
          activeTracks: switch (intent.trackType!) {
            DomainMediaTrackType.audio => ActivePlaybackTrackState(
                audioTrackId: intent.trackId,
                subtitleTrackId: _snapshot.activeTracks.subtitleTrackId,
              ),
            DomainMediaTrackType.subtitle => ActivePlaybackTrackState(
                audioTrackId: _snapshot.activeTracks.audioTrackId,
                subtitleTrackId: intent.trackId,
              ),
          },
        );
        _lastIntentResult = const PlaybackPageIntentResult.ignored(
            'Mock shell recorded track intent.');
      case PlaybackPageIntentKind.applyVideoEnhancement:
        _lastIntentResult = PlaybackPageIntentResult.executedVideoEnhancement(
          DomainVideoEnhancementApplyResult.applied(
            preset: intent.videoEnhancementProfile!.preset,
          ),
        );
    }
    notifyListeners();
  }

  PlaybackStateSnapshot _snapshotWith({
    PlaybackLifecycleStatus? status,
    PlaybackTimelineState? timeline,
    PlaybackBufferingState? buffering,
    ActivePlaybackTrackState? activeTracks,
    PlaybackSubtitleStateSnapshot? subtitles,
    PlaybackDanmakuStateSnapshot? danmaku,
  }) {
    return PlaybackStateSnapshot(
      status: status ?? _snapshot.status,
      timeline: timeline ?? _snapshot.timeline,
      buffering: buffering ?? _snapshot.buffering,
      activeTracks: activeTracks ?? _snapshot.activeTracks,
      subtitles: subtitles ?? _snapshot.subtitles,
      danmaku: danmaku ?? _snapshot.danmaku,
      sourceUri: _snapshot.sourceUri,
      failureReason: _snapshot.failureReason,
    );
  }
}

final class ControllerDrivenFlutterPlaybackShellDriver extends ChangeNotifier
    implements FlutterPlaybackShellDriver, PlaybackStateObserver {
  ControllerDrivenFlutterPlaybackShellDriver(
      {required PlaybackControllerContract controller})
      : _controller = controller,
        _contract = PlaybackPageContract(controller: controller) {
    _controller.addPlaybackStateObserver(this);
  }

  final PlaybackControllerContract _controller;
  final PlaybackPageContract _contract;
  PlaybackPageIntentResult? _lastIntentResult;
  PlaybackPagePanelId? _activePanel;
  bool _isDispatching = false;

  @override
  PlaybackStateSnapshot get snapshot => _controller.currentState;

  @override
  PlaybackPageSurfaceDescriptor get surface => _contract.resolveSurface();

  @override
  PlaybackPageIntentResult? get lastIntentResult => _lastIntentResult;

  @override
  PlaybackPagePanelId? get activePanel => _activePanel;

  @override
  Future<void> dispatch(PlaybackPageIntent intent) async {
    _isDispatching = true;
    final PlaybackPageIntentResult result;
    try {
      result = await _contract.dispatch(intent);
    } finally {
      _isDispatching = false;
    }
    _lastIntentResult = result;
    if (result.panelId != null) {
      _activePanel = result.panelId;
    }
    notifyListeners();
  }

  @override
  void onPlaybackState(PlaybackStateSnapshot snapshot) {
    if (_isDispatching) {
      return;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _controller.removePlaybackStateObserver(this);
    super.dispose();
  }
}

final class FlutterPlaybackPage extends StatefulWidget {
  const FlutterPlaybackPage({super.key, required this.driver});

  final FlutterPlaybackShellDriver driver;

  @override
  State<FlutterPlaybackPage> createState() => _FlutterPlaybackPageState();
}

final class _FlutterPlaybackPageState extends State<FlutterPlaybackPage> {
  @override
  void initState() {
    super.initState();
    widget.driver.addListener(_handleDriverChanged);
  }

  @override
  void didUpdateWidget(FlutterPlaybackPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.driver != widget.driver) {
      oldWidget.driver.removeListener(_handleDriverChanged);
      widget.driver.addListener(_handleDriverChanged);
    }
  }

  @override
  void dispose() {
    widget.driver.removeListener(_handleDriverChanged);
    super.dispose();
  }

  void _handleDriverChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final PlaybackStateSnapshot snapshot = widget.driver.snapshot;
    final PlaybackPageSurfaceDescriptor surface = widget.driver.surface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Status: ${snapshot.status.name}'),
        Text('Position: ${_formatDuration(snapshot.timeline.position)}'),
        if (snapshot.timeline.duration != null)
          Text('Duration: ${_formatDuration(snapshot.timeline.duration!)}'),
        if (surface.hasActiveControl(PlaybackPageControlId.progress))
          const Text('Progress'),
        if (snapshot.buffering.isBuffering) const Text('Buffering'),
        if (snapshot.activeTracks.audioTrackId != null)
          Text('Audio: ${snapshot.activeTracks.audioTrackId!.value}'),
        if (snapshot.activeTracks.subtitleTrackId != null)
          Text('Subtitle: ${snapshot.activeTracks.subtitleTrackId!.value}'),
        for (final PlaybackPageSubtitleCueDescriptor cue
            in surface.subtitleOverlay.cues)
          Text('Subtitle cue: ${cue.text}'),
        for (final PlaybackPageDanmakuLaneDescriptor lane
            in surface.danmakuOverlay.lanes)
          for (final PlaybackPageDanmakuCommentDescriptor comment
              in lane.comments)
            Text('Danmaku ${lane.mode.name}: ${comment.text}'),
        Wrap(
          spacing: 8,
          children: <Widget>[
            if (surface.hasActiveControl(PlaybackPageControlId.playPause))
              OutlinedButton(
                onPressed: () =>
                    widget.driver.dispatch(const PlaybackPageIntent.play()),
                child: const Text('Play'),
              ),
            if (surface.hasActiveControl(PlaybackPageControlId.seek))
              OutlinedButton(
                onPressed: () => widget.driver.dispatch(
                    const PlaybackPageIntent.seek(demoPlaybackSeekPosition)),
                child: const Text('Seek'),
              ),
            if (surface.hasActiveControl(PlaybackPageControlId.stop))
              OutlinedButton(
                onPressed: () =>
                    widget.driver.dispatch(const PlaybackPageIntent.stop()),
                child: const Text('Stop'),
              ),
            if (surface.hasActiveControl(PlaybackPageControlId.audioTracks))
              OutlinedButton(
                onPressed: () => widget.driver.dispatch(
                  const PlaybackPageIntent.selectTrack(
                    trackId: DomainMediaTrackId('audio-main'),
                    trackType: DomainMediaTrackType.audio,
                  ),
                ),
                child: const Text('Audio'),
              ),
            if (surface.hasActiveControl(PlaybackPageControlId.subtitleTracks))
              OutlinedButton(
                onPressed: () => widget.driver.dispatch(
                  const PlaybackPageIntent.selectTrack(
                    trackId: DomainMediaTrackId('subtitle-ja'),
                    trackType: DomainMediaTrackType.subtitle,
                  ),
                ),
                child: const Text('Subtitle'),
              ),
            if (surface.hasActivePanel(PlaybackPagePanelId.tracks))
              OutlinedButton(
                onPressed: () => widget.driver.dispatch(
                    const PlaybackPageIntent.openPanel(
                        PlaybackPagePanelId.tracks)),
                child: const Text('Tracks'),
              ),
          ],
        ),
        if (widget.driver.activePanel != null)
          Text('Panel: ${widget.driver.activePanel!.name}'),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final int minutes = duration.inMinutes;
    final int seconds = duration.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
