import 'package:flutter/material.dart';
import '../../domain/playback/playback_controller.dart';
import '../../domain/playback/playback_state.dart';
import '../theme/elaina_theme.dart';
import 'playback_page_contract.dart';

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

class _ProductionPlaybackPageState extends State<ProductionPlaybackPage>
    implements PlaybackStateObserver {
  late final PlaybackPageContract _pageContract;
  bool _areControlsVisible = true;

  @override
  void initState() {
    super.initState();
    _pageContract = PlaybackPageContract(controller: widget.controller);
    widget.controller.addPlaybackStateObserver(this);
  }

  @override
  void dispose() {
    widget.controller.removePlaybackStateObserver(this);
    super.dispose();
  }

  @override
  void onPlaybackState(PlaybackStateSnapshot snapshot) {
    if (mounted) {
      setState(() {});
    }
  }

  String _formatDuration(Duration duration) {
    final int minutes = duration.inMinutes;
    final int seconds = duration.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final PlaybackStateSnapshot snapshot = widget.controller.currentState;
    final PlaybackPageSurfaceDescriptor surface =
        _pageContract.resolveSurface();
    final ElainaThemeData theme = ElainaTheme.of(context);

    final Duration position = snapshot.timeline.position;
    final Duration duration = snapshot.timeline.duration ?? Duration.zero;
    final double sliderValue = position.inMilliseconds.toDouble();
    final double sliderMax =
        duration.inMilliseconds.toDouble().clamp(1.0, double.infinity);

    final String title = snapshot.sourceUri != null
        ? Uri.decodeComponent(snapshot.sourceUri!.pathSegments.last)
        : '视频播放';

    return Theme(
      data: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark().copyWith(
          primary: theme.primary,
          secondary: theme.secondary,
          surface: theme.surface,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: <Widget>[
            // Video Surface
            Center(
              child: widget.videoSurface,
            ),

            // Gesture detector to toggle controls visibility
            Positioned.fill(
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () {
                    setState(() {
                      _areControlsVisible = !_areControlsVisible;
                    });
                  },
                ),
              ),
            ),

            // Top Bar Controls
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              top: _areControlsVisible ? 0 : -80,
              left: 0,
              right: 0,
              child: Container(
                height: 80,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[Colors.black87, Colors.transparent],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: <Widget>[
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () async {
                        await _pageContract
                            .dispatch(const PlaybackPageIntent.stop());
                      },
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Center Buffering / PlayPause Overlay
            if (_areControlsVisible || snapshot.buffering.isBuffering)
              Center(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: _areControlsVisible ? 1.0 : 0.0,
                  child: snapshot.buffering.isBuffering
                      ? CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(theme.primary),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            shape: BoxShape.circle,
                            border: Border.all(color: theme.border, width: 1.5),
                          ),
                          child: IconButton(
                            iconSize: 64,
                            icon: Icon(
                              snapshot.status == PlaybackLifecycleStatus.playing
                                  ? Icons.pause
                                  : Icons.play_arrow,
                              color: Colors.white,
                            ),
                            onPressed: () async {
                              if (snapshot.status ==
                                  PlaybackLifecycleStatus.playing) {
                                await _pageContract
                                    .dispatch(const PlaybackPageIntent.pause());
                              } else {
                                await _pageContract
                                    .dispatch(const PlaybackPageIntent.play());
                              }
                            },
                          ),
                        ),
                ),
              ),

            // Bottom Bar Controls
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              bottom: _areControlsVisible ? 0 : -100,
              left: 0,
              right: 0,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[Colors.transparent, Colors.black87],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    // Progress Slider
                    if (surface
                            .hasActiveControl(PlaybackPageControlId.progress) ||
                        surface.hasActiveControl(PlaybackPageControlId.seek))
                      Row(
                        children: <Widget>[
                          Text(
                            _formatDuration(position),
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12),
                          ),
                          Expanded(
                            child: Slider(
                              value: sliderValue.clamp(0.0, sliderMax),
                              max: sliderMax,
                              activeColor: theme.primary,
                              inactiveColor: Colors.white24,
                              onChanged: surface.hasActiveControl(
                                      PlaybackPageControlId.seek)
                                  ? (double value) {
                                      _pageContract.dispatch(
                                        PlaybackPageIntent.seek(
                                          Duration(milliseconds: value.toInt()),
                                        ),
                                      );
                                    }
                                  : null,
                            ),
                          ),
                          Text(
                            _formatDuration(duration),
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),

                    const SizedBox(height: 10),

                    // Controls Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            if (surface.hasActiveControl(
                                PlaybackPageControlId.playPause))
                              IconButton(
                                icon: Icon(
                                  snapshot.status ==
                                          PlaybackLifecycleStatus.playing
                                      ? Icons.pause
                                      : Icons.play_arrow,
                                  color: Colors.white,
                                ),
                                onPressed: () async {
                                  if (snapshot.status ==
                                      PlaybackLifecycleStatus.playing) {
                                    await _pageContract.dispatch(
                                        const PlaybackPageIntent.pause());
                                  } else {
                                    await _pageContract.dispatch(
                                        const PlaybackPageIntent.play());
                                  }
                                },
                              ),
                            if (surface
                                .hasActiveControl(PlaybackPageControlId.stop))
                              IconButton(
                                icon:
                                    const Icon(Icons.stop, color: Colors.white),
                                onPressed: () async {
                                  await _pageContract.dispatch(
                                      const PlaybackPageIntent.stop());
                                },
                              ),
                          ],
                        ),

                        // Track Selection Indicator placeholders if supported
                        Row(
                          children: <Widget>[
                            if (surface.hasActiveControl(
                                PlaybackPageControlId.audioTracks))
                              IconButton(
                                icon: const Icon(Icons.audiotrack,
                                    color: Colors.white),
                                onPressed: () {
                                  // Open audio track switcher if available
                                },
                              ),
                            if (surface.hasActiveControl(
                                PlaybackPageControlId.subtitleTracks))
                              IconButton(
                                icon: const Icon(Icons.subtitles,
                                    color: Colors.white),
                                onPressed: () {
                                  // Open subtitle track switcher if available
                                },
                              ),
                          ],
                        ),
                      ],
                    ),
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
