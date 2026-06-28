// Legacy playback shell tests remain as a compatibility safety net. New
// production playback behavior belongs in the redesigned playback page tests.
// Avoid adding new visual behavior here unless the legacy shell itself changes.
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
    expect(ElainaFinders.playbackMatrixDanmakuOverlay, findsOneWidget);
    expect(ElainaFinders.playbackDanmakuOverlay, findsNothing);
    expect(find.text('主字幕对白'), findsWidgets);
    expect(find.text('episode-1.mkv'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('production page auto-hides controls while playing',
      (WidgetTester tester) async {
    final MockPlaybackController controller = _productionController(
      status: PlaybackLifecycleStatus.playing,
    );

    await tester.pumpWidget(_productionHost(controller));
    await tester.pump();
    expect(tester.getTopLeft(ElainaFinders.playbackTopControls).dy,
        greaterThanOrEqualTo(0));

    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 250));

    expect(
        tester.getTopLeft(ElainaFinders.playbackTopControls).dy, lessThan(0));
    expect(ElainaFinders.playbackControlsWakeLayer, findsOneWidget);
    expect(
      tester.getSize(ElainaFinders.playbackControlsWakeLayer),
      const Size(800, 600),
    );

    await tester.tapAt(const Offset(400, 300));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(tester.getTopLeft(ElainaFinders.playbackTopControls).dy,
        greaterThanOrEqualTo(0));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('production page keeps controls visible while paused',
      (WidgetTester tester) async {
    final MockPlaybackController controller = _productionController();

    await tester.pumpWidget(_productionHost(controller));
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(ElainaFinders.playbackTopControls).dy,
        greaterThanOrEqualTo(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('production timeline uses a single slider track',
      (WidgetTester tester) async {
    final MockPlaybackController controller = _productionController();

    await tester.pumpWidget(_productionHost(controller));

    expect(ElainaFinders.playbackSeekBar, findsOneWidget);
    expect(tester.widget<Slider>(ElainaFinders.playbackSeekBar), isA<Slider>());
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('production subtitle overlay uses saved default style',
      (WidgetTester tester) async {
    final FakeSettingsRuntime settingsRuntime = FakeSettingsRuntime();
    await settingsRuntime.setPreference(
      key: SettingsPreferenceKeys.subtitleStyleProfile,
      value: SubtitleStyleSettings.serialize(
        SubtitleStyleProfile.defaults.copyWith(fontSize: 30),
      ),
    );
    final MockPlaybackController controller = _productionController();

    await tester.pumpWidget(
      _productionHost(controller, settingsRuntime: settingsRuntime),
    );
    await tester.pumpAndSettle();

    final Text subtitle = tester.widget<Text>(
      find.text('主字幕对白').first,
    );
    expect(subtitle.style?.fontSize, 30);
    expect(tester.takeException(), isNull);
  });

  testWidgets('production subtitle overlay draws background only when enabled',
      (WidgetTester tester) async {
    final MockPlaybackController controller = _productionController();

    await tester.pumpWidget(_productionHost(controller));
    await tester.pumpAndSettle();

    expect(_textHasDecoratedBoxAncestor(tester, '主字幕对白'), isFalse);

    final FakeSettingsRuntime settingsRuntime = FakeSettingsRuntime();
    await settingsRuntime.setPreference(
      key: SettingsPreferenceKeys.subtitleStyleProfile,
      value: SubtitleStyleSettings.serialize(
        SubtitleStyleProfile.defaults.copyWith(backgroundEnabled: true),
      ),
    );

    await tester.pumpWidget(
      _productionHost(controller, settingsRuntime: settingsRuntime),
    );
    await tester.pumpAndSettle();

    expect(_textHasDecoratedBoxAncestor(tester, '主字幕对白'), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'production page falls back to basic danmaku when matrix is unsupported',
      (WidgetTester tester) async {
    final MockPlaybackController controller = _productionController(
      matrix: _productionMatrix(matrixDanmakuSupported: false),
    );

    await tester.pumpWidget(_productionHost(controller));

    expect(ElainaFinders.playbackMatrixDanmakuOverlay, findsNothing);
    expect(ElainaFinders.playbackDanmakuOverlay, findsOneWidget);
    expect(find.text('滚动弹幕'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('production inspector discovers and switches tracks',
      (WidgetTester tester) async {
    final MockPlaybackController controller = _productionController(
      initialSelectedSubtitleTrackId: null,
    );

    await tester.pumpWidget(_productionHost(controller));
    await tester.tap(find.byTooltip('打开播放信息'));
    await tester.pumpAndSettle();
    await tester.pumpUntilFound(ElainaFinders.playbackTrack('audio-main'));

    await tester.tap(ElainaFinders.playbackTrack('audio-main'));
    await tester.pump();

    expect(
        controller.currentState.activeTracks.audioTrackId?.value, 'audio-main');
    await tester.tap(ElainaFinders.playbackTrack('subtitle-ja'));
    await tester.pump();

    expect(controller.currentState.activeTracks.subtitleTrackId?.value,
        'subtitle-ja');
    expect(controller.currentState.subtitles.selectedTrackId, 'subtitle-ja');
    expect(find.text('subtitle-ja'), findsOneWidget);
    expect(ElainaFinders.playbackTrackPanel, findsOneWidget);
    expect(find.text('音轨'), findsWidgets);
    expect(find.text('字幕轨'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('production inspector applies Anime4K preset through controller',
      (WidgetTester tester) async {
    final MockPlaybackController controller = _productionController();

    await tester.pumpWidget(_productionHost(controller));
    await tester.tap(find.byTooltip('打开播放信息'));
    await tester.pumpAndSettle();
    await tester.pumpUntilFound(ElainaFinders.playbackVideoEnhancementPanel);

    expect(ElainaFinders.playbackAnime4kPresetMenu, findsOneWidget);
    final DropdownButtonFormField<VideoEnhancementPresetSelection> menu =
        tester.widget<DropdownButtonFormField<VideoEnhancementPresetSelection>>(
      ElainaFinders.playbackAnime4kPresetMenu,
    );

    expect(menu.initialValue, VideoEnhancementPresetSelection.off);
    menu.onChanged!(VideoEnhancementPresetSelection.restoreAndUpscale);
    await tester.pumpAndSettle();

    expect(
      controller.activeVideoEnhancementPreset,
      VideoEnhancementPresetSelection.restoreAndUpscale,
    );
    expect(find.text('Restore + Upscale'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('production inspector disables Anime4K menu when unsupported',
      (WidgetTester tester) async {
    final MockPlaybackController controller = _productionController(
      matrix: _productionMatrix(anime4kSupported: false),
    );

    await tester.pumpWidget(_productionHost(controller));
    await tester.tap(find.byTooltip('打开播放信息'));
    await tester.pumpAndSettle();
    await tester.pumpUntilFound(ElainaFinders.playbackVideoEnhancementPanel);

    final DropdownButtonFormField<VideoEnhancementPresetSelection> menu =
        tester.widget<DropdownButtonFormField<VideoEnhancementPresetSelection>>(
      ElainaFinders.playbackAnime4kPresetMenu,
    );

    expect(menu.onChanged, isNull);
    expect(find.textContaining('Anime4K shader manifest is incomplete.'),
        findsWidgets);
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
  testWidgets('production page keeps video surface mounted after pause',
      (WidgetTester tester) async {
    const ValueKey<String> videoSurfaceKey =
        ValueKey<String>('production-video-surface');
    final MockPlaybackController controller = _productionController(
      status: PlaybackLifecycleStatus.playing,
    );

    await tester.pumpWidget(
      _productionHost(
        controller,
        videoSurface: const ColoredBox(
          key: videoSurfaceKey,
          color: Color(0xFF244C7A),
        ),
      ),
    );
    expect(find.byKey(videoSurfaceKey), findsOneWidget);

    await tester.tap(ElainaFinders.playbackPlayPause);
    await tester.pump();

    expect(controller.currentState.status, PlaybackLifecycleStatus.paused);
    expect(find.byKey(videoSurfaceKey), findsOneWidget);
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

Widget _productionHost(
  MockPlaybackController controller, {
  Widget videoSurface = const ColoredBox(color: Colors.black),
  SettingsRuntime? settingsRuntime,
}) {
  return MaterialApp(
    home: ProductionPlaybackPage(
      controller: controller,
      videoSurface: videoSurface,
      settingsRuntime: settingsRuntime,
    ),
  );
}

bool _textHasDecoratedBoxAncestor(WidgetTester tester, String text) {
  bool hasDecoratedBox = false;
  tester.element(find.text(text).first).visitAncestorElements(
    (Element ancestor) {
      if (ancestor.widget is DecoratedBox) {
        hasDecoratedBox = true;
        return false;
      }
      return true;
    },
  );
  return hasDecoratedBox;
}

MockPlaybackController _productionController({
  PlaybackLifecycleStatus status = PlaybackLifecycleStatus.paused,
  PlaybackCapabilityMatrix? matrix,
  String? initialSelectedSubtitleTrackId = 'subtitle-ja',
}) {
  return MockPlaybackController(
    matrix: matrix ?? _productionMatrix(),
    initialState: PlaybackStateSnapshot(
      status: status,
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
        selectedTrackId: initialSelectedSubtitleTrackId,
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

PlaybackCapabilityMatrix _productionMatrix({
  bool matrixDanmakuSupported = true,
  bool anime4kSupported = true,
}) {
  return PlaybackCapabilityMatrix(
    capabilities: <PlaybackCapability, CapabilityStatus>{
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
      PlaybackCapability.matrixDanmaku: matrixDanmakuSupported
          ? const CapabilityStatus.supported()
          : const CapabilityStatus.unsupported(
              'Matrix4 danmaku overlay renderer is not available.',
            ),
      PlaybackCapability.videoEnhancement: CapabilityStatus.supported(),
      PlaybackCapability.anime4kPreset: anime4kSupported
          ? const CapabilityStatus.supported()
          : const CapabilityStatus.unsupported(
              'Anime4K shader manifest is incomplete.',
            ),
      PlaybackCapability.avSyncGuard:
          CapabilityStatus.unsupported('当前后端未上报音画同步指标。'),
      PlaybackCapability.fallbackAdapter:
          CapabilityStatus.unsupported('未配置备用播放后端。'),
    },
  );
}
