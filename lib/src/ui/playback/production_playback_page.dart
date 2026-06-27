import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/playback/playback_controller.dart';
import '../../domain/playback/playback_state.dart';
import '../testing/ui_element_ids.dart';
import '../theme/elaina_theme.dart';
import 'playback_page_contract.dart';
import 'playback_page_driver.dart';

/// Production playback surface.
///
/// The page owns only presentation state such as overlay visibility. Playback
/// actions, surface availability, tracks, subtitles, danmaku, and capability
/// status all come from PlaybackPageDriver so the UI cannot grow direct
/// dependencies on concrete player adapters.
class ProductionPlaybackPage extends StatefulWidget {
  const ProductionPlaybackPage({
    super.key,
    required this.controller,
    required this.videoSurface,
  });

  final PlaybackControllerContract controller;
  final Widget videoSurface;

  @override
  State<ProductionPlaybackPage> createState() => _ProductionPlaybackPageState();
}

class _ProductionPlaybackPageState extends State<ProductionPlaybackPage> {
  // Playback is a fullscreen tool surface; keeping the geometry tokens local to
  // this page prevents reusable theme constants from being polluted with values
  // that only make sense around a video surface.
  static const Duration _overlayAnimationDuration = Duration(milliseconds: 220);
  static const Duration _playButtonAnimationDuration =
      Duration(milliseconds: 160);
  static const double _topBarHeight = 72;
  static const double _topBarHiddenOffset = -88;
  static const double _bottomBarHiddenOffset = -140;
  static const double _horizontalInset = 22;
  static const double _bottomBarVerticalPadding = 18;
  static const double _controlGap = 10;
  static const double _transportButtonSize = 42;
  static const double _centerButtonSize = 86;
  static const double _inspectorWidth = 380;
  static const double _compactInspectorBreakpoint = 780;
  static const double _compactInspectorHeight = 420;
  static const double _panelRadius = 8;
  static const double _sectionGap = 14;
  static const double _sectionPadding = 14;
  static const double _subtitleBottomInset = 138;
  static const double _subtitleHiddenControlsBottomInset = 64;
  static const double _subtitleMaxWidth = 920;
  static const double _failurePanelMaxWidth = 520;
  static const double _danmakuTopInset = 92;
  static const double _danmakuLaneHeight = 30;
  static const double _bufferBarHeight = 3;
  static const double _statusChipHeight = 28;
  static const double _iconOnlyButtonSize = 40;
  static const double _capabilityIconSize = 18;
  static const double _busyIndicatorSize = 22;
  static const double _inlineBusyIndicatorSize = 16;
  static const double _failureIconSize = 34;
  static const double _subtitleFontSize = 22;
  static const double _danmakuFontSize = 16;
  static const double _microGap = 2;
  static const double _cueGap = 4;
  static const double _itemGap = 6;
  static const double _smallGap = 8;
  static const double _standardGap = 10;
  static const double _mediumGap = 12;
  static const double _wideGap = 18;
  static const double _inspectorHorizontalPadding = 18;
  static const double _inspectorHeaderTopPadding = 12;
  static const double _inspectorHeaderRightPadding = 12;
  static const double _inspectorBodyBottomPadding = 18;
  static const double _trackButtonHorizontalPadding = 12;
  static const double _trackButtonVerticalPadding = 10;
  static const double _sourceTextAlpha = 0.64;
  static const double _secondaryTextAlpha = 0.72;
  static const double _mutedTextAlpha = 0.58;
  static const double _subtleTextAlpha = 0.54;
  static const double _messageTextAlpha = 0.68;
  static const double _timelineTextAlpha = 0.76;
  static const double _bufferingTextAlpha = 0.78;
  static const double _bufferTrackAlpha = 0.16;
  static const double _bufferValueAlpha = 0.34;
  static const double _inspectorScrimAlpha = 0.9;
  static const double _sectionSurfaceAlpha = 0.08;
  static const double _sectionBorderAlpha = 0.1;
  static const double _selectedTrackAlpha = 0.16;
  static const double _idleTrackAlpha = 0.08;
  static const double _busySurfaceAlpha = 0.62;
  static const double _busyBorderAlpha = 0.14;
  static const double _failureSurfaceAlpha = 0.72;
  static const double _failureBorderAlpha = 0.44;
  static const double _centerButtonSurfaceAlpha = 0.5;
  static const double _centerButtonBorderAlpha = 0.22;
  static const double _statusChipSurfaceAlpha = 0.12;
  static const double _statusChipBorderAlpha = 0.16;
  static const double _fractionMin = 0;
  static const double _fractionMax = 1;
  static const int _maxInlineOverlayComments = 3;

  late ControllerPlaybackPageDriver _driver;

  // These toggles are page-local affordances. They do not mutate playback
  // runtime configuration, which keeps hide/show UI actions reversible and cheap.
  bool _areControlsVisible = true;
  bool _isInspectorVisible = false;
  bool _areSubtitlesVisible = true;
  bool _isDanmakuVisible = true;

  @override
  void initState() {
    super.initState();
    _driver = ControllerPlaybackPageDriver(controller: widget.controller);
    _driver.addListener(_handleDriverChanged);
  }

  @override
  void didUpdateWidget(ProductionPlaybackPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _driver.removeListener(_handleDriverChanged);
      _driver.dispose();
      _driver = ControllerPlaybackPageDriver(controller: widget.controller);
      _driver.addListener(_handleDriverChanged);
    }
  }

  @override
  void dispose() {
    _driver.removeListener(_handleDriverChanged);
    _driver.dispose();
    super.dispose();
  }

  void _handleDriverChanged() {
    if (mounted) setState(() {});
  }

  void _toggleControls() {
    setState(() {
      _areControlsVisible = !_areControlsVisible;
    });
  }

  void _openInspector() {
    setState(() {
      _areControlsVisible = true;
      _isInspectorVisible = true;
    });
    // Track discovery can be adapter-expensive and sometimes depends on the
    // current source being opened, so it is pulled only when the inspector needs
    // it instead of during page construction.
    final PlaybackTrackPanelStatus trackStatus = _driver.view.tracks.status;
    if (trackStatus == PlaybackTrackPanelStatus.idle) {
      unawaited(_driver.loadTracks());
    }
  }

  void _closeInspector() {
    setState(() {
      _isInspectorVisible = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final PlaybackPageViewSnapshot view = _driver.view;
    final ElainaThemeData theme = ElainaTheme.of(context);

    return KeyedSubtree(
      key: const ValueKey<String>(UiElementIds.playbackPage),
      child: Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark().copyWith(
            primary: theme.primary,
            secondary: theme.secondary,
            surface: theme.surface,
          ),
          tooltipTheme: const TooltipThemeData(preferBelow: false),
        ),
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: <Widget>[
              // Layer order matters: the native surface stays at the bottom,
              // passive overlays sit above it, and interactive controls/inspector
              // own the top hit-test regions.
              Positioned.fill(child: Center(child: widget.videoSurface)),
              Positioned.fill(
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _toggleControls,
                  ),
                ),
              ),
              _SubtitleOverlay(
                view: view,
                controlsVisible: _areControlsVisible,
                visible: _areSubtitlesVisible,
              ),
              _MatrixDanmakuOverlay(
                view: view,
                visible: _isDanmakuVisible,
                repaint: _driver,
              ),
              _DanmakuOverlay(view: view, visible: _isDanmakuVisible),
              _CenterPlaybackStatus(
                view: view,
                driver: _driver,
                controlsVisible: _areControlsVisible,
              ),
              _TopPlaybackBar(
                view: view,
                visible: _areControlsVisible,
                onStop: () => _driver.dispatch(const PlaybackPageIntent.stop()),
              ),
              _BottomTransportBar(
                view: view,
                driver: _driver,
                visible: _areControlsVisible,
                subtitlesVisible: _areSubtitlesVisible,
                danmakuVisible: _isDanmakuVisible,
                onOpenInspector: _openInspector,
                onToggleSubtitles: () {
                  setState(() {
                    _areSubtitlesVisible = !_areSubtitlesVisible;
                  });
                },
                onToggleDanmaku: () {
                  setState(() {
                    _isDanmakuVisible = !_isDanmakuVisible;
                  });
                },
              ),
              _InspectorLayer(
                view: view,
                driver: _driver,
                visible: _isInspectorVisible,
                subtitlesVisible: _areSubtitlesVisible,
                danmakuVisible: _isDanmakuVisible,
                onClose: _closeInspector,
                onRefreshTracks: _driver.loadTracks,
                onToggleSubtitles: () {
                  setState(() {
                    _areSubtitlesVisible = !_areSubtitlesVisible;
                  });
                },
                onToggleDanmaku: () {
                  setState(() {
                    _isDanmakuVisible = !_isDanmakuVisible;
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopPlaybackBar extends StatelessWidget {
  const _TopPlaybackBar({
    required this.view,
    required this.visible,
    required this.onStop,
  });

  final PlaybackPageViewSnapshot view;
  final bool visible;
  final Future<PlaybackPageIntentResult> Function() onStop;

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      duration: _ProductionPlaybackPageState._overlayAnimationDuration,
      top: visible ? 0 : _ProductionPlaybackPageState._topBarHiddenOffset,
      left: 0,
      right: 0,
      height: _ProductionPlaybackPageState._topBarHeight,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[Colors.black87, Colors.transparent],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: _ProductionPlaybackPageState._horizontalInset,
            ),
            child: Row(
              children: <Widget>[
                _PlaybackIconButton(
                  tooltip: '停止播放',
                  icon: Icons.arrow_back,
                  onPressed: () => unawaited(onStop()),
                ),
                const SizedBox(width: _ProductionPlaybackPageState._controlGap),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _titleForSource(view.playback.sourceUri),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(
                          height: _ProductionPlaybackPageState._microGap),
                      Text(
                        _sourceLabel(view.playback.sourceUri),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(
                            alpha:
                                _ProductionPlaybackPageState._sourceTextAlpha,
                          ),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: _ProductionPlaybackPageState._controlGap),
                _PlaybackStatusChip(status: view.playback.status),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomTransportBar extends StatelessWidget {
  const _BottomTransportBar({
    required this.view,
    required this.driver,
    required this.visible,
    required this.subtitlesVisible,
    required this.danmakuVisible,
    required this.onOpenInspector,
    required this.onToggleSubtitles,
    required this.onToggleDanmaku,
  });

  final PlaybackPageViewSnapshot view;
  final PlaybackPageDriver driver;
  final bool visible;
  final bool subtitlesVisible;
  final bool danmakuVisible;
  final VoidCallback onOpenInspector;
  final VoidCallback onToggleSubtitles;
  final VoidCallback onToggleDanmaku;

  @override
  Widget build(BuildContext context) {
    final PlaybackStateSnapshot playback = view.playback;
    final Duration position = playback.timeline.position;
    final Duration duration = playback.timeline.duration ?? Duration.zero;
    final double sliderMax = duration.inMilliseconds
        .toDouble()
        .clamp(1.0, double.infinity)
        .toDouble();
    final bool canSeek =
        view.surface.hasActiveControl(PlaybackPageControlId.seek);
    final bool canShowProgress =
        view.surface.hasActiveControl(PlaybackPageControlId.progress) ||
            view.surface.hasActiveControl(PlaybackPageControlId.seek);

    return AnimatedPositioned(
      duration: _ProductionPlaybackPageState._overlayAnimationDuration,
      bottom: visible ? 0 : _ProductionPlaybackPageState._bottomBarHiddenOffset,
      left: 0,
      right: 0,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[Colors.transparent, Colors.black87],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              _ProductionPlaybackPageState._horizontalInset,
              _ProductionPlaybackPageState._bottomBarVerticalPadding,
              _ProductionPlaybackPageState._horizontalInset,
              _ProductionPlaybackPageState._bottomBarVerticalPadding,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (canShowProgress)
                  _TimelineControl(
                    position: position,
                    duration: duration,
                    bufferedFraction: playback.buffering.bufferedFraction,
                    sliderMax: sliderMax,
                    canSeek: canSeek,
                    onSeek: (Duration target) {
                      unawaited(
                          driver.dispatch(PlaybackPageIntent.seek(target)));
                    },
                  ),
                Row(
                  children: <Widget>[
                    if (view.surface
                        .hasActiveControl(PlaybackPageControlId.playPause))
                      _PlaybackIconButton(
                        key: const ValueKey<String>(
                          UiElementIds.playbackPlayPause,
                        ),
                        tooltip:
                            playback.status == PlaybackLifecycleStatus.playing
                                ? '暂停'
                                : '播放',
                        icon: playback.status == PlaybackLifecycleStatus.playing
                            ? Icons.pause
                            : Icons.play_arrow,
                        size: _ProductionPlaybackPageState._transportButtonSize,
                        onPressed: () {
                          final PlaybackPageIntent intent =
                              playback.status == PlaybackLifecycleStatus.playing
                                  ? const PlaybackPageIntent.pause()
                                  : const PlaybackPageIntent.play();
                          unawaited(driver.dispatch(intent));
                        },
                      ),
                    if (view.surface
                        .hasActiveControl(PlaybackPageControlId.stop))
                      _PlaybackIconButton(
                        key: const ValueKey<String>(UiElementIds.playbackStop),
                        tooltip: '停止',
                        icon: Icons.stop,
                        size: _ProductionPlaybackPageState._transportButtonSize,
                        onPressed: () {
                          unawaited(
                            driver.dispatch(const PlaybackPageIntent.stop()),
                          );
                        },
                      ),
                    const SizedBox(
                        width: _ProductionPlaybackPageState._controlGap),
                    Text(
                      '${_formatDuration(position)} / ${_formatDuration(duration)}',
                      style: TextStyle(
                        color: Colors.white.withValues(
                          alpha:
                              _ProductionPlaybackPageState._timelineTextAlpha,
                        ),
                        fontSize: 12,
                        fontFeatures: const <FontFeature>[
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                    if (playback.buffering.isBuffering) ...<Widget>[
                      const SizedBox(
                        width: _ProductionPlaybackPageState._controlGap,
                      ),
                      Text(
                        '缓冲中',
                        style: TextStyle(
                          color: Colors.white.withValues(
                            alpha: _ProductionPlaybackPageState
                                ._bufferingTextAlpha,
                          ),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const Spacer(),
                    _PlaybackIconButton(
                      tooltip: subtitlesVisible ? '隐藏字幕' : '显示字幕',
                      icon: subtitlesVisible
                          ? Icons.subtitles
                          : Icons.subtitles_off,
                      size: _ProductionPlaybackPageState._iconOnlyButtonSize,
                      onPressed: onToggleSubtitles,
                    ),
                    _PlaybackIconButton(
                      tooltip: danmakuVisible ? '隐藏弹幕' : '显示弹幕',
                      icon: danmakuVisible
                          ? Icons.chat_bubble_outline
                          : Icons.chat_bubble_outline,
                      size: _ProductionPlaybackPageState._iconOnlyButtonSize,
                      onPressed: onToggleDanmaku,
                    ),
                    _PlaybackIconButton(
                      tooltip: '打开播放信息',
                      icon: Icons.tune,
                      size: _ProductionPlaybackPageState._iconOnlyButtonSize,
                      onPressed: onOpenInspector,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TimelineControl extends StatelessWidget {
  const _TimelineControl({
    required this.position,
    required this.duration,
    required this.bufferedFraction,
    required this.sliderMax,
    required this.canSeek,
    required this.onSeek,
  });

  final Duration position;
  final Duration duration;
  final double? bufferedFraction;
  final double sliderMax;
  final bool canSeek;
  final ValueChanged<Duration> onSeek;

  @override
  Widget build(BuildContext context) {
    final double sliderValue =
        position.inMilliseconds.toDouble().clamp(0.0, sliderMax).toDouble();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(
            _ProductionPlaybackPageState._bufferBarHeight,
          ),
          child: LinearProgressIndicator(
            minHeight: _ProductionPlaybackPageState._bufferBarHeight,
            value: _normalizedFraction(bufferedFraction),
            backgroundColor: Colors.white.withValues(
              alpha: _ProductionPlaybackPageState._bufferTrackAlpha,
            ),
            valueColor: AlwaysStoppedAnimation<Color>(
              Colors.white.withValues(
                alpha: _ProductionPlaybackPageState._bufferValueAlpha,
              ),
            ),
          ),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: _ProductionPlaybackPageState._bufferBarHeight,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          ),
          child: Slider(
            key: const ValueKey<String>(UiElementIds.playbackSeekBar),
            value: sliderValue,
            max: sliderMax,
            onChanged: canSeek
                ? (double value) {
                    onSeek(Duration(milliseconds: value.round()));
                  }
                : null,
          ),
        ),
      ],
    );
  }
}

class _CenterPlaybackStatus extends StatelessWidget {
  const _CenterPlaybackStatus({
    required this.view,
    required this.driver,
    required this.controlsVisible,
  });

  final PlaybackPageViewSnapshot view;
  final PlaybackPageDriver driver;
  final bool controlsVisible;

  @override
  Widget build(BuildContext context) {
    final PlaybackLifecycleStatus status = view.playback.status;
    if (status == PlaybackLifecycleStatus.opening ||
        status == PlaybackLifecycleStatus.buffering ||
        view.playback.buffering.isBuffering) {
      return const Center(
        child: _PlaybackBusyIndicator(label: '加载中'),
      );
    }
    if (status == PlaybackLifecycleStatus.failed) {
      return Center(
        child: _PlaybackFailurePanel(
          message: view.playback.failureReason ?? '加载失败',
        ),
      );
    }
    if (!controlsVisible ||
        !view.surface.hasActiveControl(PlaybackPageControlId.playPause)) {
      return const SizedBox.shrink();
    }
    return Center(
      child: AnimatedOpacity(
        duration: _ProductionPlaybackPageState._playButtonAnimationDuration,
        opacity: controlsVisible ? 1 : 0,
        child: _RoundPlaybackButton(
          status: status,
          onPressed: () {
            final PlaybackPageIntent intent =
                status == PlaybackLifecycleStatus.playing
                    ? const PlaybackPageIntent.pause()
                    : const PlaybackPageIntent.play();
            unawaited(driver.dispatch(intent));
          },
        ),
      ),
    );
  }
}

class _SubtitleOverlay extends StatelessWidget {
  const _SubtitleOverlay({
    required this.view,
    required this.controlsVisible,
    required this.visible,
  });

  final PlaybackPageViewSnapshot view;
  final bool controlsVisible;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible || !view.surface.subtitleOverlay.hasVisibleCues) {
      return const SizedBox.shrink();
    }
    return Positioned(
      key: const ValueKey<String>(UiElementIds.playbackSubtitleOverlay),
      left: _ProductionPlaybackPageState._horizontalInset,
      right: _ProductionPlaybackPageState._horizontalInset,
      bottom: controlsVisible
          ? _ProductionPlaybackPageState._subtitleBottomInset
          : _ProductionPlaybackPageState._subtitleHiddenControlsBottomInset,
      child: IgnorePointer(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: _ProductionPlaybackPageState._subtitleMaxWidth,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (final PlaybackPageSubtitleCueDescriptor cue
                    in view.surface.subtitleOverlay.cues)
                  Padding(
                    padding: const EdgeInsets.only(
                      bottom: _ProductionPlaybackPageState._cueGap,
                    ),
                    child: Text(
                      cue.text,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize:
                            _ProductionPlaybackPageState._subtitleFontSize,
                        fontWeight: FontWeight.w800,
                        shadows: <Shadow>[
                          Shadow(
                            blurRadius: 4,
                            offset: Offset(0, 1),
                            color: Colors.black,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DanmakuOverlay extends StatelessWidget {
  const _DanmakuOverlay({required this.view, required this.visible});

  final PlaybackPageViewSnapshot view;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible ||
        view.surface.matrixDanmakuOverlay.hasVisibleComments ||
        !view.surface.danmakuOverlay.hasVisibleComments) {
      return const SizedBox.shrink();
    }
    final List<PlaybackPageDanmakuLaneDescriptor> lanes =
        view.surface.danmakuOverlay.lanes;
    return Positioned.fill(
      key: const ValueKey<String>(UiElementIds.playbackDanmakuOverlay),
      child: IgnorePointer(
        child: ClipRect(
          child: Stack(
            children: <Widget>[
              for (int laneIndex = 0; laneIndex < lanes.length; laneIndex += 1)
                _DanmakuLane(
                  lane: lanes[laneIndex],
                  laneIndex: laneIndex,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MatrixDanmakuOverlay extends StatefulWidget {
  const _MatrixDanmakuOverlay({
    required this.view,
    required this.visible,
    required this.repaint,
  });

  final PlaybackPageViewSnapshot view;
  final bool visible;
  final Listenable repaint;

  @override
  State<_MatrixDanmakuOverlay> createState() => _MatrixDanmakuOverlayState();
}

class _MatrixDanmakuOverlayState extends State<_MatrixDanmakuOverlay> {
  final _MatrixDanmakuTextLayoutCache _textCache =
      _MatrixDanmakuTextLayoutCache();

  @override
  void didUpdateWidget(_MatrixDanmakuOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _textCache.retain(widget.view.surface.matrixDanmakuOverlay.comments);
  }

  @override
  void dispose() {
    _textCache.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final PlaybackPageMatrixDanmakuOverlayDescriptor overlay =
        widget.view.surface.matrixDanmakuOverlay;
    if (!widget.visible || !overlay.hasVisibleComments) {
      return const SizedBox.shrink();
    }
    return Positioned.fill(
      key: const ValueKey<String>(UiElementIds.playbackMatrixDanmakuOverlay),
      child: IgnorePointer(
        child: ClipRect(
          child: RepaintBoundary(
            child: CustomPaint(
              isComplex: true,
              painter: _MatrixDanmakuPainter(
                overlay: overlay,
                textCache: _textCache,
                repaint: widget.repaint,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DanmakuLane extends StatelessWidget {
  const _DanmakuLane({required this.lane, required this.laneIndex});

  final PlaybackPageDanmakuLaneDescriptor lane;
  final int laneIndex;

  @override
  Widget build(BuildContext context) {
    final List<PlaybackPageDanmakuCommentDescriptor> comments = lane.comments
        .take(_ProductionPlaybackPageState._maxInlineOverlayComments)
        .toList();
    return Positioned(
      left: _ProductionPlaybackPageState._horizontalInset,
      right: _ProductionPlaybackPageState._horizontalInset,
      top: _ProductionPlaybackPageState._danmakuTopInset +
          laneIndex * _ProductionPlaybackPageState._danmakuLaneHeight,
      child: Row(
        mainAxisAlignment: switch (lane.mode) {
          DomainDanmakuMode.top => MainAxisAlignment.center,
          DomainDanmakuMode.bottom => MainAxisAlignment.center,
          DomainDanmakuMode.scrolling => MainAxisAlignment.start,
        },
        children: <Widget>[
          for (final PlaybackPageDanmakuCommentDescriptor comment in comments)
            Flexible(
              child: Padding(
                padding: const EdgeInsets.only(
                  right: _ProductionPlaybackPageState._wideGap,
                ),
                child: Text(
                  comment.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _danmakuColor(comment.colorArgb),
                    fontSize: _ProductionPlaybackPageState._danmakuFontSize,
                    fontWeight: FontWeight.w700,
                    shadows: const <Shadow>[
                      Shadow(
                        blurRadius: 3,
                        offset: Offset(0, 1),
                        color: Colors.black,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MatrixDanmakuPainter extends CustomPainter {
  _MatrixDanmakuPainter({
    required this.overlay,
    required this.textCache,
    required Listenable repaint,
  }) : super(repaint: repaint);

  static const Duration _scrollWindow = Duration(seconds: 8);
  static const double _maxTextWidthFraction = 0.72;
  static const double _bottomInset = 176;

  final PlaybackPageMatrixDanmakuOverlayDescriptor overlay;
  final _MatrixDanmakuTextLayoutCache textCache;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || overlay.comments.isEmpty) return;
    final Matrix4 transform = Matrix4.fromList(overlay.transformValues);
    final Offset center = size.center(Offset.zero);

    canvas.save();
    // Matrix4 danmaku is authored relative to the video surface center. Applying
    // the transform around center preserves identity behavior and makes rotate /
    // scale effects usable without pushing all comments off-screen.
    canvas
      ..translate(center.dx, center.dy)
      ..transform(transform.storage)
      ..translate(-center.dx, -center.dy);

    final Map<DomainDanmakuMode, int> laneIndexes = <DomainDanmakuMode, int>{};
    final double maxTextWidth = size.width * _maxTextWidthFraction;
    for (final PlaybackPageMatrixDanmakuCommentDescriptor comment
        in overlay.comments) {
      final int laneIndex = laneIndexes.update(
        comment.mode,
        (int value) => value + 1,
        ifAbsent: () => 0,
      );
      final TextPainter textPainter = textCache.painterFor(
        comment,
        maxWidth: maxTextWidth,
      );
      final Offset offset = _commentOffset(
        comment: comment,
        laneIndex: laneIndex,
        textSize: textPainter.size,
        canvasSize: size,
      );
      textPainter.paint(canvas, offset);
    }
    canvas.restore();
  }

  Offset _commentOffset({
    required PlaybackPageMatrixDanmakuCommentDescriptor comment,
    required int laneIndex,
    required Size textSize,
    required Size canvasSize,
  }) {
    final double laneHeight = _ProductionPlaybackPageState._danmakuLaneHeight;
    return switch (comment.mode) {
      DomainDanmakuMode.scrolling => Offset(
          _scrollingX(comment, textSize, canvasSize),
          _ProductionPlaybackPageState._danmakuTopInset +
              laneIndex * laneHeight,
        ),
      DomainDanmakuMode.top => Offset(
          (canvasSize.width - textSize.width) / 2,
          _ProductionPlaybackPageState._danmakuTopInset +
              laneIndex * laneHeight,
        ),
      DomainDanmakuMode.bottom => Offset(
          (canvasSize.width - textSize.width) / 2,
          canvasSize.height - _bottomInset - (laneIndex + 1) * laneHeight,
        ),
    };
  }

  double _scrollingX(
    PlaybackPageMatrixDanmakuCommentDescriptor comment,
    Size textSize,
    Size canvasSize,
  ) {
    final Duration age = overlay.clockPosition - comment.timestamp;
    final int ageMicros = age.inMicroseconds
        .clamp(
          0,
          _scrollWindow.inMicroseconds,
        )
        .toInt();
    final double progress = ageMicros / _scrollWindow.inMicroseconds;
    return canvasSize.width - progress * (canvasSize.width + textSize.width);
  }

  @override
  bool shouldRepaint(covariant _MatrixDanmakuPainter oldDelegate) {
    return oldDelegate.overlay != overlay || oldDelegate.textCache != textCache;
  }
}

final class _MatrixDanmakuTextLayoutCache {
  final Map<_MatrixDanmakuTextLayoutKey, TextPainter> _painters =
      <_MatrixDanmakuTextLayoutKey, TextPainter>{};

  TextPainter painterFor(
    PlaybackPageMatrixDanmakuCommentDescriptor comment, {
    required double maxWidth,
  }) {
    final _MatrixDanmakuTextLayoutKey key = _MatrixDanmakuTextLayoutKey(
      text: comment.text,
      colorArgb: comment.colorArgb,
      maxWidth: maxWidth.round(),
    );
    return _painters.putIfAbsent(key, () {
      final TextPainter painter = TextPainter(
        text: TextSpan(
          text: comment.text,
          style: TextStyle(
            color: _danmakuColor(comment.colorArgb),
            fontSize: _ProductionPlaybackPageState._danmakuFontSize,
            fontWeight: FontWeight.w700,
            shadows: const <Shadow>[
              Shadow(
                blurRadius: 3,
                offset: Offset(0, 1),
                color: Colors.black,
              ),
            ],
          ),
        ),
        maxLines: 1,
        ellipsis: '…',
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: maxWidth);
      return painter;
    });
  }

  void retain(Iterable<PlaybackPageMatrixDanmakuCommentDescriptor> comments) {
    final Set<String> activeTexts = <String>{
      for (final PlaybackPageMatrixDanmakuCommentDescriptor comment in comments)
        comment.text,
    };
    final List<_MatrixDanmakuTextLayoutKey> stale =
        <_MatrixDanmakuTextLayoutKey>[
      for (final _MatrixDanmakuTextLayoutKey key in _painters.keys)
        if (!activeTexts.contains(key.text)) key,
    ];
    for (final _MatrixDanmakuTextLayoutKey key in stale) {
      _painters.remove(key)?.dispose();
    }
  }

  void dispose() {
    for (final TextPainter painter in _painters.values) {
      painter.dispose();
    }
    _painters.clear();
  }
}

final class _MatrixDanmakuTextLayoutKey {
  const _MatrixDanmakuTextLayoutKey({
    required this.text,
    required this.colorArgb,
    required this.maxWidth,
  });

  final String text;
  final int? colorArgb;
  final int maxWidth;

  @override
  bool operator ==(Object other) {
    return other is _MatrixDanmakuTextLayoutKey &&
        other.text == text &&
        other.colorArgb == colorArgb &&
        other.maxWidth == maxWidth;
  }

  @override
  int get hashCode => Object.hash(text, colorArgb, maxWidth);
}

class _InspectorLayer extends StatelessWidget {
  const _InspectorLayer({
    required this.view,
    required this.driver,
    required this.visible,
    required this.subtitlesVisible,
    required this.danmakuVisible,
    required this.onClose,
    required this.onRefreshTracks,
    required this.onToggleSubtitles,
    required this.onToggleDanmaku,
  });

  final PlaybackPageViewSnapshot view;
  final PlaybackPageDriver driver;
  final bool visible;
  final bool subtitlesVisible;
  final bool danmakuVisible;
  final VoidCallback onClose;
  final Future<void> Function() onRefreshTracks;
  final VoidCallback onToggleSubtitles;
  final VoidCallback onToggleDanmaku;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool compact = constraints.maxWidth <
              _ProductionPlaybackPageState._compactInspectorBreakpoint;
          // Wide screens use a persistent right inspector; compact screens use
          // a bottom sheet so the video surface remains the primary target.
          return Stack(
            children: <Widget>[
              if (compact)
                AnimatedPositioned(
                  duration:
                      _ProductionPlaybackPageState._overlayAnimationDuration,
                  left: 0,
                  right: 0,
                  bottom: visible
                      ? 0
                      : -_ProductionPlaybackPageState._compactInspectorHeight,
                  height: _ProductionPlaybackPageState._compactInspectorHeight,
                  child: _PlaybackInspector(
                    view: view,
                    driver: driver,
                    subtitlesVisible: subtitlesVisible,
                    danmakuVisible: danmakuVisible,
                    onClose: onClose,
                    onRefreshTracks: onRefreshTracks,
                    onToggleSubtitles: onToggleSubtitles,
                    onToggleDanmaku: onToggleDanmaku,
                  ),
                )
              else
                AnimatedPositioned(
                  duration:
                      _ProductionPlaybackPageState._overlayAnimationDuration,
                  top: 0,
                  bottom: 0,
                  right: visible
                      ? 0
                      : -_ProductionPlaybackPageState._inspectorWidth,
                  width: _ProductionPlaybackPageState._inspectorWidth,
                  child: _PlaybackInspector(
                    view: view,
                    driver: driver,
                    subtitlesVisible: subtitlesVisible,
                    danmakuVisible: danmakuVisible,
                    onClose: onClose,
                    onRefreshTracks: onRefreshTracks,
                    onToggleSubtitles: onToggleSubtitles,
                    onToggleDanmaku: onToggleDanmaku,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _PlaybackInspector extends StatelessWidget {
  const _PlaybackInspector({
    required this.view,
    required this.driver,
    required this.subtitlesVisible,
    required this.danmakuVisible,
    required this.onClose,
    required this.onRefreshTracks,
    required this.onToggleSubtitles,
    required this.onToggleDanmaku,
  });

  final PlaybackPageViewSnapshot view;
  final PlaybackPageDriver driver;
  final bool subtitlesVisible;
  final bool danmakuVisible;
  final VoidCallback onClose;
  final Future<void> Function() onRefreshTracks;
  final VoidCallback onToggleSubtitles;
  final VoidCallback onToggleDanmaku;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const ValueKey<String>(UiElementIds.playbackInspector),
      color: Colors.black.withValues(
        alpha: _ProductionPlaybackPageState._inspectorScrimAlpha,
      ),
      child: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                _ProductionPlaybackPageState._inspectorHorizontalPadding,
                _ProductionPlaybackPageState._inspectorHeaderTopPadding,
                _ProductionPlaybackPageState._inspectorHeaderRightPadding,
                _ProductionPlaybackPageState._smallGap,
              ),
              child: Row(
                children: <Widget>[
                  const Expanded(
                    child: Text(
                      '播放信息',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  _PlaybackIconButton(
                    tooltip: '关闭',
                    icon: Icons.close,
                    onPressed: onClose,
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  _ProductionPlaybackPageState._inspectorHorizontalPadding,
                  _ProductionPlaybackPageState._smallGap,
                  _ProductionPlaybackPageState._inspectorHorizontalPadding,
                  _ProductionPlaybackPageState._inspectorBodyBottomPadding,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _TrackSection(
                      view: view,
                      driver: driver,
                      onRefreshTracks: onRefreshTracks,
                    ),
                    const SizedBox(
                        height: _ProductionPlaybackPageState._sectionGap),
                    _SubtitleSection(
                      view: view,
                      visible: subtitlesVisible,
                      onToggle: onToggleSubtitles,
                    ),
                    const SizedBox(
                        height: _ProductionPlaybackPageState._sectionGap),
                    _DanmakuSection(
                      view: view,
                      visible: danmakuVisible,
                      onToggle: onToggleDanmaku,
                    ),
                    const SizedBox(
                        height: _ProductionPlaybackPageState._sectionGap),
                    _VideoEnhancementSection(
                      view: view,
                      driver: driver,
                    ),
                    const SizedBox(
                        height: _ProductionPlaybackPageState._sectionGap),
                    _CapabilitySection(view: view),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackSection extends StatelessWidget {
  const _TrackSection({
    required this.view,
    required this.driver,
    required this.onRefreshTracks,
  });

  final PlaybackPageViewSnapshot view;
  final PlaybackPageDriver driver;
  final Future<void> Function() onRefreshTracks;

  @override
  Widget build(BuildContext context) {
    final PlaybackTrackPanelSnapshot tracks = view.tracks;
    return _InspectorSection(
      key: const ValueKey<String>(UiElementIds.playbackTrackPanel),
      title: '轨道',
      trailing: _PlaybackIconButton(
        tooltip: '刷新轨道',
        icon: Icons.refresh,
        onPressed: () => unawaited(onRefreshTracks()),
      ),
      child: switch (tracks.status) {
        PlaybackTrackPanelStatus.idle => const _InspectorMessage('尚未发现轨道。'),
        PlaybackTrackPanelStatus.loading => const _InlineBusyMessage('正在发现轨道'),
        PlaybackTrackPanelStatus.unsupported =>
          _InspectorMessage(tracks.message ?? '当前播放后端不支持轨道发现。'),
        PlaybackTrackPanelStatus.failed =>
          _InspectorMessage(tracks.message ?? '轨道发现失败。'),
        PlaybackTrackPanelStatus.loaded when !tracks.hasTracks =>
          const _InspectorMessage('没有可切换的音轨或字幕轨。'),
        PlaybackTrackPanelStatus.loaded => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _TrackGroup(
                title: '音轨',
                tracks: tracks.tracksOfType(DomainMediaTrackType.audio),
                activeTrackId: view.playback.activeTracks.audioTrackId,
                enabled: view.surface
                    .hasActiveControl(PlaybackPageControlId.audioTracks),
                onSelect: (PlaybackTrackItemSnapshot track) {
                  unawaited(
                    driver.dispatch(
                      PlaybackPageIntent.selectTrack(
                        trackId: track.id,
                        trackType: DomainMediaTrackType.audio,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(
                height: _ProductionPlaybackPageState._standardGap,
              ),
              _TrackGroup(
                title: '字幕轨',
                tracks: tracks.tracksOfType(DomainMediaTrackType.subtitle),
                activeTrackId: view.playback.activeTracks.subtitleTrackId,
                enabled: view.surface
                    .hasActiveControl(PlaybackPageControlId.subtitleTracks),
                onSelect: (PlaybackTrackItemSnapshot track) {
                  unawaited(
                    driver.dispatch(
                      PlaybackPageIntent.selectTrack(
                        trackId: track.id,
                        trackType: DomainMediaTrackType.subtitle,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
      },
    );
  }
}

class _TrackGroup extends StatelessWidget {
  const _TrackGroup({
    required this.title,
    required this.tracks,
    required this.activeTrackId,
    required this.enabled,
    required this.onSelect,
  });

  final String title;
  final List<PlaybackTrackItemSnapshot> tracks;
  final DomainMediaTrackId? activeTrackId;
  final bool enabled;
  final ValueChanged<PlaybackTrackItemSnapshot> onSelect;

  @override
  Widget build(BuildContext context) {
    if (tracks.isEmpty) {
      return _InspectorMessage('$title：没有可用条目');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          title,
          style: TextStyle(
            color: Colors.white.withValues(
              alpha: _ProductionPlaybackPageState._secondaryTextAlpha,
            ),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: _ProductionPlaybackPageState._itemGap),
        for (final PlaybackTrackItemSnapshot track in tracks)
          Padding(
            padding: const EdgeInsets.only(
              bottom: _ProductionPlaybackPageState._itemGap,
            ),
            child: _TrackButton(
              track: track,
              selected: activeTrackId?.value == track.id.value,
              enabled: enabled,
              onSelect: () => onSelect(track),
            ),
          ),
      ],
    );
  }
}

class _TrackButton extends StatelessWidget {
  const _TrackButton({
    required this.track,
    required this.selected,
    required this.enabled,
    required this.onSelect,
  });

  final PlaybackTrackItemSnapshot track;
  final bool selected;
  final bool enabled;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(
        alpha: selected
            ? _ProductionPlaybackPageState._selectedTrackAlpha
            : _ProductionPlaybackPageState._idleTrackAlpha,
      ),
      borderRadius:
          BorderRadius.circular(_ProductionPlaybackPageState._panelRadius),
      child: InkWell(
        key: ValueKey<String>(UiElementIds.playbackTrack(track.id.value)),
        mouseCursor:
            enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        borderRadius:
            BorderRadius.circular(_ProductionPlaybackPageState._panelRadius),
        onTap: enabled ? onSelect : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal:
                _ProductionPlaybackPageState._trackButtonHorizontalPadding,
            vertical: _ProductionPlaybackPageState._trackButtonVerticalPadding,
          ),
          child: Row(
            children: <Widget>[
              Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: selected
                    ? Colors.white
                    : Colors.white.withValues(
                        alpha: _ProductionPlaybackPageState._mutedTextAlpha,
                      ),
                size: 18,
              ),
              const SizedBox(width: _ProductionPlaybackPageState._standardGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      track.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (track.languageCode != null)
                      Text(
                        track.languageCode!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(
                            alpha:
                                _ProductionPlaybackPageState._subtleTextAlpha,
                          ),
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubtitleSection extends StatelessWidget {
  const _SubtitleSection({
    required this.view,
    required this.visible,
    required this.onToggle,
  });

  final PlaybackPageViewSnapshot view;
  final bool visible;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final PlaybackPageSubtitleOverlayDescriptor subtitles =
        view.surface.subtitleOverlay;
    return _InspectorSection(
      title: '字幕',
      trailing: _PlaybackIconButton(
        tooltip: visible ? '隐藏字幕' : '显示字幕',
        icon: visible ? Icons.visibility : Icons.visibility_off,
        onPressed: onToggle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _MetricLine(label: '当前轨道', value: subtitles.selectedTrackId ?? '未选择'),
          _MetricLine(
              label: '时间偏移', value: _formatSignedDuration(subtitles.offset)),
          if (subtitles.failureReason != null)
            _InspectorMessage('字幕失败：${subtitles.failureReason}'),
          if (!subtitles.hasVisibleCues)
            const _InspectorMessage('当前没有可见字幕。')
          else
            for (final PlaybackPageSubtitleCueDescriptor cue in subtitles.cues)
              _InspectorMessage(cue.text),
        ],
      ),
    );
  }
}

class _DanmakuSection extends StatelessWidget {
  const _DanmakuSection({
    required this.view,
    required this.visible,
    required this.onToggle,
  });

  final PlaybackPageViewSnapshot view;
  final bool visible;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final PlaybackPageDanmakuOverlayDescriptor danmaku =
        view.surface.danmakuOverlay;
    final PlaybackPageMatrixDanmakuOverlayDescriptor matrix =
        view.surface.matrixDanmakuOverlay;
    final int visibleCommentCount = danmaku.lanes.fold<int>(
      0,
      (int count, PlaybackPageDanmakuLaneDescriptor lane) =>
          count + lane.comments.length,
    );
    return _InspectorSection(
      title: '弹幕',
      trailing: _PlaybackIconButton(
        tooltip: visible ? '隐藏弹幕' : '显示弹幕',
        icon: visible ? Icons.visibility : Icons.visibility_off,
        onPressed: onToggle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _MetricLine(
              label: '时钟', value: _formatDuration(danmaku.clockPosition)),
          _MetricLine(label: '可见弹幕', value: visibleCommentCount.toString()),
          if (matrix.rendererSource != null)
            _MetricLine(label: '矩阵渲染', value: matrix.rendererSource!),
          if (matrix.hasVisibleComments)
            _MetricLine(
              label: '矩阵绘制',
              value: matrix.renderedCommentCount.toString(),
            ),
          if (matrix.failureReason != null)
            _InspectorMessage('矩阵弹幕失败：${matrix.failureReason}'),
          if (danmaku.failureReason != null)
            _InspectorMessage('弹幕失败：${danmaku.failureReason}'),
          if (!danmaku.hasVisibleComments)
            const _InspectorMessage('当前没有可见弹幕。')
          else
            for (final PlaybackPageDanmakuLaneDescriptor lane in danmaku.lanes)
              if (lane.comments.isNotEmpty)
                _InspectorMessage(
                  '${_danmakuModeLabel(lane.mode)}：'
                  '${lane.comments.map((PlaybackPageDanmakuCommentDescriptor c) => c.text).join(' / ')}',
                ),
        ],
      ),
    );
  }
}

class _VideoEnhancementSection extends StatelessWidget {
  const _VideoEnhancementSection({
    required this.view,
    required this.driver,
  });

  final PlaybackPageViewSnapshot view;
  final PlaybackPageDriver driver;

  @override
  Widget build(BuildContext context) {
    final PlaybackVideoEnhancementPanelSnapshot enhancement =
        view.videoEnhancement;
    return _InspectorSection(
      key: const ValueKey<String>(UiElementIds.playbackVideoEnhancementPanel),
      title: '视频增强',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _MetricLine(
            label: '当前预设',
            value: videoEnhancementPresetSelectionLabel(
              enhancement.selectedPreset,
            ),
          ),
          DropdownButtonFormField<VideoEnhancementPresetSelection>(
            key: const ValueKey<String>(UiElementIds.playbackAnime4kPresetMenu),
            initialValue: enhancement.selectedPreset,
            dropdownColor: Colors.black87,
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: Colors.white.withValues(
                alpha: _ProductionPlaybackPageState._sectionSurfaceAlpha,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  _ProductionPlaybackPageState._panelRadius,
                ),
                borderSide: BorderSide(
                  color: Colors.white.withValues(
                    alpha: _ProductionPlaybackPageState._sectionBorderAlpha,
                  ),
                ),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  _ProductionPlaybackPageState._panelRadius,
                ),
                borderSide: BorderSide(
                  color: Colors.white.withValues(
                    alpha: _ProductionPlaybackPageState._sectionBorderAlpha,
                  ),
                ),
              ),
            ),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
            items: <DropdownMenuItem<VideoEnhancementPresetSelection>>[
              for (final VideoEnhancementPresetSelection preset
                  in VideoEnhancementPresetSelection.values)
                DropdownMenuItem<VideoEnhancementPresetSelection>(
                  value: preset,
                  child: Text(videoEnhancementPresetSelectionLabel(preset)),
                ),
            ],
            onChanged: enhancement.isPresetSelectionEnabled
                ? (VideoEnhancementPresetSelection? preset) {
                    if (preset == null) return;
                    unawaited(
                      driver.dispatch(
                        PlaybackPageIntent.applyVideoEnhancement(
                          DomainVideoEnhancementProfileDescriptor(
                            preset: preset,
                          ),
                        ),
                      ),
                    );
                  }
                : null,
          ),
          if (enhancement.isApplying) ...<Widget>[
            const SizedBox(height: _ProductionPlaybackPageState._smallGap),
            const _InlineBusyMessage('正在应用 Anime4K 预设'),
          ],
          if (enhancement.unsupportedReason != null) ...<Widget>[
            const SizedBox(height: _ProductionPlaybackPageState._smallGap),
            _InspectorMessage(enhancement.unsupportedReason!),
          ],
          if (enhancement.message != null) ...<Widget>[
            const SizedBox(height: _ProductionPlaybackPageState._smallGap),
            _InspectorMessage(enhancement.message!),
          ],
        ],
      ),
    );
  }
}

class _CapabilitySection extends StatelessWidget {
  const _CapabilitySection({required this.view});

  final PlaybackPageViewSnapshot view;

  @override
  Widget build(BuildContext context) {
    // Capabilities are intentionally read-only here. A row becomes actionable
    // only after the playback domain exposes a concrete command contract for it.
    return _InspectorSection(
      title: '能力状态',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final PlaybackCapabilityItemSnapshot item
              in view.capabilities.items)
            _CapabilityRow(item: item),
        ],
      ),
    );
  }
}

class _CapabilityRow extends StatelessWidget {
  const _CapabilityRow({required this.item});

  final PlaybackCapabilityItemSnapshot item;

  @override
  Widget build(BuildContext context) {
    final bool supported = item.status.isSupported;
    return Padding(
      padding: const EdgeInsets.only(
        bottom: _ProductionPlaybackPageState._smallGap,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            supported ? Icons.check_circle : Icons.cancel,
            color: supported ? Colors.greenAccent : Colors.white38,
            size: _ProductionPlaybackPageState._capabilityIconSize,
          ),
          const SizedBox(width: _ProductionPlaybackPageState._smallGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (!supported && item.status.reason != null)
                  Text(
                    item.status.reason!,
                    style: TextStyle(
                      color: Colors.white.withValues(
                        alpha: _ProductionPlaybackPageState._subtleTextAlpha,
                      ),
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InspectorSection extends StatelessWidget {
  const _InspectorSection({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(
          alpha: _ProductionPlaybackPageState._sectionSurfaceAlpha,
        ),
        borderRadius:
            BorderRadius.circular(_ProductionPlaybackPageState._panelRadius),
        border: Border.all(
          color: Colors.white.withValues(
            alpha: _ProductionPlaybackPageState._sectionBorderAlpha,
          ),
        ),
      ),
      child: Padding(
        padding:
            const EdgeInsets.all(_ProductionPlaybackPageState._sectionPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: _ProductionPlaybackPageState._standardGap),
            child,
          ],
        ),
      ),
    );
  }
}

class _MetricLine extends StatelessWidget {
  const _MetricLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: _ProductionPlaybackPageState._smallGap,
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 78,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(
                  alpha: _ProductionPlaybackPageState._mutedTextAlpha,
                ),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InspectorMessage extends StatelessWidget {
  const _InspectorMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: _ProductionPlaybackPageState._itemGap,
      ),
      child: Text(
        message,
        style: TextStyle(
          color: Colors.white.withValues(
            alpha: _ProductionPlaybackPageState._messageTextAlpha,
          ),
          fontSize: 12,
          height: 1.28,
        ),
      ),
    );
  }
}

class _InlineBusyMessage extends StatelessWidget {
  const _InlineBusyMessage(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const SizedBox.square(
          dimension: _ProductionPlaybackPageState._inlineBusyIndicatorSize,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: _ProductionPlaybackPageState._standardGap),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(
              alpha: _ProductionPlaybackPageState._secondaryTextAlpha,
            ),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _PlaybackBusyIndicator extends StatelessWidget {
  const _PlaybackBusyIndicator({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(
          alpha: _ProductionPlaybackPageState._busySurfaceAlpha,
        ),
        borderRadius:
            BorderRadius.circular(_ProductionPlaybackPageState._panelRadius),
        border: Border.all(
          color: Colors.white.withValues(
            alpha: _ProductionPlaybackPageState._busyBorderAlpha,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: _ProductionPlaybackPageState._wideGap,
          vertical: _ProductionPlaybackPageState._sectionPadding,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox.square(
              dimension: _ProductionPlaybackPageState._busyIndicatorSize,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
            const SizedBox(width: _ProductionPlaybackPageState._mediumGap),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaybackFailurePanel extends StatelessWidget {
  const _PlaybackFailurePanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: _ProductionPlaybackPageState._failurePanelMaxWidth,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(
            alpha: _ProductionPlaybackPageState._failureSurfaceAlpha,
          ),
          borderRadius:
              BorderRadius.circular(_ProductionPlaybackPageState._panelRadius),
          border: Border.all(
            color: Colors.redAccent.withValues(
              alpha: _ProductionPlaybackPageState._failureBorderAlpha,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(
            _ProductionPlaybackPageState._horizontalInset,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.error_outline,
                color: Colors.redAccent,
                size: _ProductionPlaybackPageState._failureIconSize,
              ),
              const SizedBox(
                height: _ProductionPlaybackPageState._standardGap,
              ),
              const Text(
                '加载失败',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: _ProductionPlaybackPageState._smallGap),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(
                    alpha: _ProductionPlaybackPageState._secondaryTextAlpha,
                  ),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundPlaybackButton extends StatelessWidget {
  const _RoundPlaybackButton({
    required this.status,
    required this.onPressed,
  });

  final PlaybackLifecycleStatus status;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final bool playing = status == PlaybackLifecycleStatus.playing;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(
          alpha: _ProductionPlaybackPageState._centerButtonSurfaceAlpha,
        ),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(
            alpha: _ProductionPlaybackPageState._centerButtonBorderAlpha,
          ),
        ),
      ),
      child: SizedBox.square(
        dimension: _ProductionPlaybackPageState._centerButtonSize,
        child: IconButton(
          tooltip: playing ? '暂停' : '播放',
          mouseCursor: SystemMouseCursors.click,
          iconSize: 58,
          icon: Icon(
            playing ? Icons.pause : Icons.play_arrow,
            color: Colors.white,
          ),
          onPressed: onPressed,
        ),
      ),
    );
  }
}

class _PlaybackIconButton extends StatelessWidget {
  const _PlaybackIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.size = _ProductionPlaybackPageState._iconOnlyButtonSize,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox.square(
        dimension: size,
        child: IconButton(
          mouseCursor: onPressed == null
              ? SystemMouseCursors.basic
              : SystemMouseCursors.click,
          icon: Icon(icon, color: Colors.white),
          onPressed: onPressed,
          padding: EdgeInsets.zero,
          splashRadius: size / 2,
        ),
      ),
    );
  }
}

class _PlaybackStatusChip extends StatelessWidget {
  const _PlaybackStatusChip({required this.status});

  final PlaybackLifecycleStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _ProductionPlaybackPageState._statusChipHeight,
      padding: const EdgeInsets.symmetric(
        horizontal: _ProductionPlaybackPageState._standardGap,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(
          alpha: _ProductionPlaybackPageState._statusChipSurfaceAlpha,
        ),
        borderRadius:
            BorderRadius.circular(_ProductionPlaybackPageState._panelRadius),
        border: Border.all(
          color: Colors.white.withValues(
            alpha: _ProductionPlaybackPageState._statusChipBorderAlpha,
          ),
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        _statusLabel(status),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

String _titleForSource(Uri? uri) {
  if (uri == null || uri.pathSegments.isEmpty) return '视频播放';
  return Uri.decodeComponent(uri.pathSegments.last);
}

String _sourceLabel(Uri? uri) {
  if (uri == null) return '未选择媒体源';
  if (uri.scheme == 'file') return uri.toFilePath();
  return uri.toString();
}

String _formatDuration(Duration duration) {
  final int hours = duration.inHours;
  final int minutes = duration.inMinutes.remainder(60);
  final int seconds = duration.inSeconds.remainder(60);
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

String _formatSignedDuration(Duration duration) {
  if (duration == Duration.zero) return '0:00';
  final String sign = duration.isNegative ? '-' : '+';
  return '$sign${_formatDuration(duration.abs())}';
}

String _statusLabel(PlaybackLifecycleStatus status) {
  return switch (status) {
    PlaybackLifecycleStatus.idle => '空闲',
    PlaybackLifecycleStatus.opening => '打开中',
    PlaybackLifecycleStatus.playing => '播放中',
    PlaybackLifecycleStatus.paused => '已暂停',
    PlaybackLifecycleStatus.buffering => '缓冲中',
    PlaybackLifecycleStatus.ended => '已结束',
    PlaybackLifecycleStatus.failed => '失败',
  };
}

String _danmakuModeLabel(DomainDanmakuMode mode) {
  return switch (mode) {
    DomainDanmakuMode.scrolling => '滚动',
    DomainDanmakuMode.top => '顶部',
    DomainDanmakuMode.bottom => '底部',
  };
}

Color _danmakuColor(int? colorArgb) {
  if (colorArgb == null) return Colors.white;
  return Color(colorArgb);
}

double? _normalizedFraction(double? value) {
  if (value == null) return null;
  return value
      .clamp(
        _ProductionPlaybackPageState._fractionMin,
        _ProductionPlaybackPageState._fractionMax,
      )
      .toDouble();
}
