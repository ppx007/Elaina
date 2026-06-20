import 'package:elaina/elaina.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('renderer resolves eligible comments by clock filter density and mode',
      () {
    const DeterministicBasicDanmakuRenderer renderer =
        DeterministicBasicDanmakuRenderer();
    final DanmakuRenderFrame frame = renderer.frameFor(
      clock: const PlayerClockSnapshot(
        position: Duration(seconds: 10),
        isPlaying: true,
        playbackSpeed: 1,
      ),
      comments: <DanmakuComment>[
        _comment('old', 1, 'too old', DanmakuMode.scrolling),
        _comment('blocked', 8, 'hide me', DanmakuMode.scrolling),
        _comment('scroll', 9, 'scrolling', DanmakuMode.scrolling),
        _comment('top', 10, 'top', DanmakuMode.top),
        _comment('bottom', 10, 'bottom', DanmakuMode.bottom),
      ],
      filter: const DanmakuFilter(blockedKeywords: <String>{'hide'}),
      densityPolicy: const DanmakuDensityPolicy(
        maxCommentsPerWindow: 2,
        window: Duration(seconds: 3),
      ),
    );

    expect(frame.clock.position, const Duration(seconds: 10));
    expect(
      frame.lanes
          .singleWhere(
              (DanmakuRenderLane lane) => lane.mode == DanmakuMode.scrolling)
          .comments
          .single
          .text,
      'scrolling',
    );
    expect(
      frame.lanes
          .singleWhere(
              (DanmakuRenderLane lane) => lane.mode == DanmakuMode.bottom)
          .comments
          .single
          .text,
      'bottom',
    );
    expect(
      frame.lanes
          .singleWhere((DanmakuRenderLane lane) => lane.mode == DanmakuMode.top)
          .comments,
      isEmpty,
    );
  });

  test('runtime loads resolves publishes immutable snapshots and disposes', () {
    final BasicDanmakuRuntime runtime = BasicDanmakuRuntime(
      densityPolicy: const DanmakuDensityPolicy(
        maxCommentsPerWindow: 3,
        window: Duration(seconds: 5),
      ),
    );
    final _DanmakuObserver observer = _DanmakuObserver();
    runtime.addObserver(observer);

    final BasicDanmakuLoadResult load = runtime.load(<DanmakuComment>[
      _comment('scroll', 2, 'scrolling', DanmakuMode.scrolling),
      _comment('top', 3, 'top', DanmakuMode.top),
      _comment('bottom', 4, 'bottom', DanmakuMode.bottom),
    ]);
    final BasicDanmakuRuntimeSnapshot snapshot = runtime.resolveFrame(
      const PlayerClockSnapshot(
        position: Duration(seconds: 4),
        isPlaying: true,
        playbackSpeed: 1,
      ),
    );

    expect(load.isSuccess, isTrue);
    expect(observer.snapshots, isNotEmpty);
    expect(snapshot.status, BasicDanmakuRuntimeStatus.ready);
    expect(snapshot.activeFrame.lanes, hasLength(3));
    expect(
      () => snapshot.loadedComments.add(_comment('x', 4, 'x', DanmakuMode.top)),
      throwsUnsupportedError,
    );

    runtime.dispose();
    final BasicDanmakuRuntimeSnapshot disposed = runtime.resolveFrame(
      const PlayerClockSnapshot(
        position: Duration(seconds: 5),
        isPlaying: true,
        playbackSpeed: 1,
      ),
    );
    expect(disposed.status, BasicDanmakuRuntimeStatus.disposed);
    expect(disposed.failure?.kind, BasicDanmakuRuntimeFailureKind.disposed);
  });

  test('renderer rejects non-positive density windows at resolution time', () {
    const DeterministicBasicDanmakuRenderer renderer =
        DeterministicBasicDanmakuRenderer();

    expect(
      () => renderer.frameFor(
        clock: const PlayerClockSnapshot(
          position: Duration(seconds: 1),
          isPlaying: true,
          playbackSpeed: 1,
        ),
        comments: const <DanmakuComment>[],
        filter: const DanmakuFilter(),
        densityPolicy: const DanmakuDensityPolicy(
          maxCommentsPerWindow: 1,
          window: Duration.zero,
        ),
      ),
      throwsArgumentError,
    );
  });

  test('domain projection surface descriptor and dandanplay bridge are stable',
      () {
    const List<DandanplayComment> sourceComments = <DandanplayComment>[
      DandanplayComment(
        timestamp: Duration(seconds: 1),
        text: 'provider-scroll',
        mode: DandanplayCommentMode.scrolling,
        colorArgb: 0x00ffffff,
      ),
      DandanplayComment(
        timestamp: Duration(seconds: 1),
        text: 'provider-top',
        mode: DandanplayCommentMode.top,
      ),
    ];
    final List<DanmakuComment> comments = danmakuCommentsFromDandanplay(
      sourceComments,
      idPrefix: 'episode-1',
    );
    final BasicDanmakuRuntime runtime = BasicDanmakuRuntime();
    runtime.load(comments);
    final BasicDanmakuRuntimeSnapshot runtimeSnapshot = runtime.resolveFrame(
      const PlayerClockSnapshot(
        position: Duration(seconds: 1),
        isPlaying: true,
        playbackSpeed: 1,
      ),
    );

    final PlaybackDanmakuStateSnapshot domainState =
        playbackDanmakuStateFromRuntimeSnapshot(runtimeSnapshot);
    final PlaybackPageSurfaceDescriptor surface =
        PlaybackPageSurfaceDescriptor.fromState(
      const PlaybackSurfaceState(
        visibleControls: <PlaybackSurfaceControl>{
          PlaybackSurfaceControl.progress
        },
        availablePanels: <PlaybackSurfacePanel>{},
      ),
      subtitles: const PlaybackSubtitleStateSnapshot.none(),
      danmaku: domainState,
    );

    expect(comments.first.id.value, startsWith('episode-1:1000:0:'));
    expect(comments.first.mode, DanmakuMode.scrolling);
    expect(domainState.hasVisibleComments, isTrue);
    expect(surface.danmakuOverlay.hasVisibleComments, isTrue);
    expect(
      surface.danmakuOverlay.lanes
          .singleWhere(
            (PlaybackPageDanmakuLaneDescriptor lane) =>
                lane.mode == DomainDanmakuMode.scrolling,
          )
          .comments
          .single
          .text,
      'provider-scroll',
    );
  });
}

DanmakuComment _comment(
  String id,
  int seconds,
  String text,
  DanmakuMode mode,
) {
  return DanmakuComment(
    id: DanmakuCommentId(id),
    timestamp: Duration(seconds: seconds),
    text: text,
    mode: mode,
  );
}

final class _DanmakuObserver implements BasicDanmakuRuntimeObserver {
  final List<BasicDanmakuRuntimeSnapshot> snapshots =
      <BasicDanmakuRuntimeSnapshot>[];

  @override
  void onDanmakuRuntimeSnapshot(BasicDanmakuRuntimeSnapshot snapshot) {
    snapshots.add(snapshot);
  }
}
