import 'package:elaina/elaina.dart';
import 'package:elaina/src/ui/playback/flutter_playback_shell.dart';
import 'package:elaina/src/ui/playback/production_playback_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../framework/elaina_finders.dart';
import '../../support/widget_test_waiters.dart';

void main() {
  testWidgets('renders playback state and active surface controls',
      (WidgetTester tester) async {
    final MockFlutterPlaybackShellDriver driver = _driver();

    await tester.pumpWidget(_host(driver));

    expect(find.text('Status: paused'), findsOneWidget);
    expect(find.text('Position: 1:20'), findsOneWidget);
    expect(find.text('Duration: 24:00'), findsOneWidget);
    expect(find.text('Progress'), findsOneWidget);
    expect(find.text('Buffering'), findsOneWidget);
    expect(find.text('Play'), findsOneWidget);
    expect(find.text('Seek'), findsOneWidget);
    expect(find.text('Stop'), findsOneWidget);
    expect(find.text('Tracks'), findsOneWidget);
  });

  testWidgets('dispatches mock intents and updates rendered state',
      (WidgetTester tester) async {
    final MockFlutterPlaybackShellDriver driver = _driver();

    await tester.pumpWidget(_host(driver));

    await tester.tap(find.text('Play'));
    await tester.pump();
    expect(find.text('Status: playing'), findsOneWidget);

    await tester.tap(find.text('Seek'));
    await tester.pump();
    expect(find.text('Position: 0:42'), findsOneWidget);

    await tester.tap(find.text('Tracks'));
    await tester.pump();
    expect(find.text('Panel: tracks'), findsOneWidget);

    await tester.tap(find.text('Audio'));
    await tester.pump();
    expect(find.text('Audio: audio-main'), findsOneWidget);

    await tester.tap(find.text('Subtitle'));
    await tester.pump();
    expect(find.text('Subtitle: subtitle-ja'), findsOneWidget);
  });

  testWidgets('renders controller-driven state and dispatches through driver',
      (WidgetTester tester) async {
    final ControllerDrivenFlutterPlaybackShellDriver driver =
        ControllerDrivenFlutterPlaybackShellDriver(
      controller: MockPlaybackController(
        matrix: _matrix(),
        initialState: const PlaybackStateSnapshot(
          status: PlaybackLifecycleStatus.paused,
          timeline: PlaybackTimelineState(
              position: Duration(seconds: 5), duration: Duration(minutes: 2)),
        ),
      ),
    );

    await tester.pumpWidget(_host(driver));

    expect(find.text('Status: paused'), findsOneWidget);
    expect(find.text('Position: 0:05'), findsOneWidget);

    await tester.tap(find.text('Play'));
    await tester.pump();
    expect(find.text('Status: playing'), findsOneWidget);

    await tester.tap(find.text('Seek'));
    await tester.pump();
    expect(find.text('Position: 0:42'), findsOneWidget);

    await tester.tap(find.text('Audio'));
    await tester.pump();
    expect(find.text('Audio: audio-main'), findsOneWidget);

    driver.dispose();
  });

  test(
      'controller-driven driver notifies once with fresh result after dispatch',
      () async {
    final ControllerDrivenFlutterPlaybackShellDriver driver =
        ControllerDrivenFlutterPlaybackShellDriver(
      controller: MockPlaybackController(
        matrix: _matrix(),
        initialState:
            const PlaybackStateSnapshot(status: PlaybackLifecycleStatus.paused),
      ),
    );
    final List<PlaybackLifecycleStatus> statuses = <PlaybackLifecycleStatus>[];
    final List<PlaybackPageIntentOutcome?> outcomes =
        <PlaybackPageIntentOutcome?>[];
    driver.addListener(() {
      statuses.add(driver.snapshot.status);
      outcomes.add(driver.lastIntentResult?.outcome);
    });

    await driver.dispatch(const PlaybackPageIntent.play());

    expect(
        statuses, <PlaybackLifecycleStatus>[PlaybackLifecycleStatus.playing]);
    expect(outcomes,
        <PlaybackPageIntentOutcome?>[PlaybackPageIntentOutcome.executed]);

    driver.dispose();
  });

  testWidgets('hides controls absent from the surface descriptor',
      (WidgetTester tester) async {
    final MockFlutterPlaybackShellDriver driver =
        MockFlutterPlaybackShellDriver(
      initialSnapshot:
          const PlaybackStateSnapshot(status: PlaybackLifecycleStatus.idle),
      surface: const PlaybackPageSurfaceDescriptor(
        controls: <PlaybackPageControlDescriptor>[
          PlaybackPageControlDescriptor(id: PlaybackPageControlId.playPause),
        ],
        panels: <PlaybackPagePanelDescriptor>[],
      ),
    );

    await tester.pumpWidget(_host(driver));

    expect(find.text('Play'), findsOneWidget);
    expect(find.text('Seek'), findsNothing);
    expect(find.text('Stop'), findsNothing);
    expect(find.text('Progress'), findsNothing);
    expect(find.text('Tracks'), findsNothing);
  });

  testWidgets('production page renders transport overlays and metadata',
      (WidgetTester tester) async {
    final MockPlaybackController controller = _productionController();

    await tester.pumpWidget(_productionHost(controller));

    expect(ElainaFinders.playbackPage, findsOneWidget);
    expect(ElainaFinders.playbackPlayPause, findsOneWidget);
    expect(ElainaFinders.playbackSeekBar, findsOneWidget);
    expect(ElainaFinders.playbackSubtitleOverlay, findsOneWidget);
    expect(ElainaFinders.playbackDanmakuOverlay, findsOneWidget);
    expect(find.text('主字幕对白'), findsWidgets);
    expect(find.text('滚动弹幕'), findsOneWidget);
    expect(find.text('episode-1.mkv'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('production inspector discovers and switches tracks',
      (WidgetTester tester) async {
    final MockPlaybackController controller = _productionController();

    await tester.pumpWidget(_productionHost(controller));
    await tester.tap(find.byTooltip('打开播放信息'));
    await tester.pumpAndSettle();
    await tester.pumpUntilFound(ElainaFinders.playbackTrack('audio-main'));

    await tester.tap(ElainaFinders.playbackTrack('audio-main'));
    await tester.pump();

    expect(
        controller.currentState.activeTracks.audioTrackId?.value, 'audio-main');
    expect(ElainaFinders.playbackTrackPanel, findsOneWidget);
    expect(find.text('音轨'), findsWidgets);
    expect(find.text('字幕轨'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('production page exposes failure state',
      (WidgetTester tester) async {
    final MockPlaybackController controller = MockPlaybackController(
      matrix: _productionMatrix(),
      initialState: const PlaybackStateSnapshot(
        status: PlaybackLifecycleStatus.failed,
        failureReason: '解码器初始化失败',
      ),
    );

    await tester.pumpWidget(_productionHost(controller));

    expect(find.text('加载失败'), findsOneWidget);
    expect(find.text('解码器初始化失败'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _host(FlutterPlaybackShellDriver driver) {
  return MaterialApp(
    home: Scaffold(
      body: FlutterPlaybackPage(driver: driver),
    ),
  );
}

PlaybackCapabilityMatrix _matrix() {
  return PlaybackCapabilityMatrix(
    capabilities: const <PlaybackCapability, CapabilityStatus>{
      PlaybackCapability.playPause: CapabilityStatus.supported(),
      PlaybackCapability.seek: CapabilityStatus.supported(),
      PlaybackCapability.stop: CapabilityStatus.supported(),
      PlaybackCapability.progressReporting: CapabilityStatus.supported(),
      PlaybackCapability.audioTrackSwitching: CapabilityStatus.supported(),
      PlaybackCapability.subtitleTrackSwitching: CapabilityStatus.supported(),
      PlaybackCapability.secondaryPanels: CapabilityStatus.supported(),
    },
  );
}

MockFlutterPlaybackShellDriver _driver() {
  return MockFlutterPlaybackShellDriver(
    initialSnapshot: const PlaybackStateSnapshot(
      status: PlaybackLifecycleStatus.paused,
      timeline: PlaybackTimelineState(
        position: Duration(minutes: 1, seconds: 20),
        duration: Duration(minutes: 24),
      ),
      buffering: PlaybackBufferingState(
        isBuffering: true,
        bufferedPosition: Duration(minutes: 2),
        bufferedFraction: 0.2,
      ),
    ),
    surface: const PlaybackPageSurfaceDescriptor(
      controls: <PlaybackPageControlDescriptor>[
        PlaybackPageControlDescriptor(id: PlaybackPageControlId.playPause),
        PlaybackPageControlDescriptor(id: PlaybackPageControlId.seek),
        PlaybackPageControlDescriptor(id: PlaybackPageControlId.stop),
        PlaybackPageControlDescriptor(id: PlaybackPageControlId.progress),
        PlaybackPageControlDescriptor(id: PlaybackPageControlId.audioTracks),
        PlaybackPageControlDescriptor(id: PlaybackPageControlId.subtitleTracks),
      ],
      panels: <PlaybackPagePanelDescriptor>[
        PlaybackPagePanelDescriptor(id: PlaybackPagePanelId.tracks),
      ],
    ),
  );
}

Widget _productionHost(MockPlaybackController controller) {
  return MaterialApp(
    home: ProductionPlaybackPage(
      controller: controller,
      videoSurface: const ColoredBox(color: Colors.black),
    ),
  );
}

MockPlaybackController _productionController() {
  return MockPlaybackController(
    matrix: _productionMatrix(),
    initialState: PlaybackStateSnapshot(
      status: PlaybackLifecycleStatus.paused,
      sourceUri: Uri.file('D:/Anime/episode-1.mkv'),
      timeline: const PlaybackTimelineState(
        position: Duration(minutes: 1, seconds: 20),
        duration: Duration(minutes: 24),
      ),
      buffering: const PlaybackBufferingState(
        isBuffering: false,
        bufferedFraction: 0.4,
      ),
      subtitles: PlaybackSubtitleStateSnapshot(
        selectedTrackId: 'subtitle-ja',
        activeCues: <DomainSubtitleCueDescriptor>[
          DomainSubtitleCueDescriptor(
            start: Duration(minutes: 1, seconds: 19),
            end: Duration(minutes: 1, seconds: 24),
            text: '主字幕对白',
          ),
        ],
      ),
      danmaku: PlaybackDanmakuStateSnapshot(
        clockPosition: const Duration(minutes: 1, seconds: 20),
        lanes: <DomainDanmakuLaneDescriptor>[
          DomainDanmakuLaneDescriptor(
            mode: DomainDanmakuMode.scrolling,
            comments: const <DomainDanmakuCommentDescriptor>[
              DomainDanmakuCommentDescriptor(
                id: 'comment-1',
                timestamp: Duration(minutes: 1, seconds: 20),
                text: '滚动弹幕',
                mode: DomainDanmakuMode.scrolling,
              ),
            ],
          ),
        ],
      ),
    ),
    tracks: const <MediaTrackDescriptor>[
      MediaTrackDescriptor(
        id: MediaTrackId('audio-main'),
        type: MediaTrackType.audio,
        label: '日语主音轨',
        languageCode: 'ja',
      ),
      MediaTrackDescriptor(
        id: MediaTrackId('subtitle-ja'),
        type: MediaTrackType.subtitle,
        label: '日语字幕',
        languageCode: 'ja',
      ),
    ],
  );
}

PlaybackCapabilityMatrix _productionMatrix() {
  return PlaybackCapabilityMatrix(
    capabilities: const <PlaybackCapability, CapabilityStatus>{
      PlaybackCapability.localFilePlayback: CapabilityStatus.supported(),
      PlaybackCapability.playPause: CapabilityStatus.supported(),
      PlaybackCapability.seek: CapabilityStatus.supported(),
      PlaybackCapability.stop: CapabilityStatus.supported(),
      PlaybackCapability.progressReporting: CapabilityStatus.supported(),
      PlaybackCapability.audioTrackDiscovery: CapabilityStatus.supported(),
      PlaybackCapability.audioTrackSwitching: CapabilityStatus.supported(),
      PlaybackCapability.subtitleTrackDiscovery: CapabilityStatus.supported(),
      PlaybackCapability.subtitleTrackSwitching: CapabilityStatus.supported(),
      PlaybackCapability.secondaryPanels: CapabilityStatus.supported(),
      PlaybackCapability.danmakuRendering: CapabilityStatus.supported(),
      PlaybackCapability.videoEnhancement: CapabilityStatus.supported(),
      PlaybackCapability.avSyncGuard:
          CapabilityStatus.unsupported('当前后端未上报音画同步指标。'),
      PlaybackCapability.fallbackAdapter:
          CapabilityStatus.unsupported('未配置备用播放后端。'),
    },
  );
}
