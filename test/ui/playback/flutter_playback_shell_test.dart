import 'package:celesteria/celesteria.dart';
import 'package:celesteria/src/ui/playback/flutter_playback_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders playback state and active surface controls', (WidgetTester tester) async {
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

  testWidgets('dispatches mock intents and updates rendered state', (WidgetTester tester) async {
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

  testWidgets('hides controls absent from the surface descriptor', (WidgetTester tester) async {
    final MockFlutterPlaybackShellDriver driver = MockFlutterPlaybackShellDriver(
      initialSnapshot: const PlaybackStateSnapshot(status: PlaybackLifecycleStatus.idle),
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
}

Widget _host(MockFlutterPlaybackShellDriver driver) {
  return MaterialApp(
    home: Scaffold(
      body: FlutterPlaybackPage(driver: driver),
    ),
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
