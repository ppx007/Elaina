import '../lib/elaina.dart';
import 'dandanplay_runtime_check.dart';

Future<void> main() async {
  await verifyBasicDanmakuRuntimeContract();
}

Future<void> verifyBasicDanmakuRuntimeContract() async {
  final BasicDanmakuRuntime runtime = BasicDanmakuRuntime(
    densityPolicy: const DanmakuDensityPolicy(
      maxCommentsPerWindow: 2,
      window: Duration(seconds: 3),
    ),
  );
  final List<DanmakuComment> comments = danmakuCommentsFromDandanplay(
    const <DandanplayComment>[
      DandanplayComment(
        timestamp: Duration(seconds: 2),
        text: 'runtime-scroll',
        mode: DandanplayCommentMode.scrolling,
      ),
      DandanplayComment(
        timestamp: Duration(seconds: 2),
        text: 'runtime-top',
        mode: DandanplayCommentMode.top,
      ),
    ],
    idPrefix: 'runtime-episode',
  );

  final BasicDanmakuLoadResult loaded = runtime.load(comments);
  _expect(loaded.isSuccess, 'Danmaku runtime must load comments.');
  final BasicDanmakuRuntimeSnapshot runtimeSnapshot = runtime.resolveFrame(
    const PlayerClockSnapshot(
      position: Duration(seconds: 2),
      isPlaying: true,
      playbackSpeed: 1,
    ),
  );
  _expect(
    runtimeSnapshot.activeFrame.lanes
        .any((DanmakuRenderLane lane) => lane.comments.isNotEmpty),
    'Danmaku runtime must expose visible frame lanes.',
  );

  final PlaybackDanmakuStateSnapshot domainState =
      playbackDanmakuStateFromRuntimeSnapshot(runtimeSnapshot);
  _expect(
    domainState.hasVisibleComments,
    'Domain danmaku projection must expose visible comments.',
  );
  final PlaybackPageSurfaceDescriptor surface =
      PlaybackPageSurfaceDescriptor.fromState(
    const PlaybackSurfaceState(
      visibleControls: <PlaybackSurfaceControl>{
        PlaybackSurfaceControl.progress
      },
      availablePanels: <PlaybackSurfacePanel>{},
    ),
    danmaku: domainState,
  );
  _expect(
    surface.danmakuOverlay.hasVisibleComments,
    'Playback page surface must expose danmaku overlay descriptors.',
  );

  await verifyDandanplayRuntimeContract();
}

void _expect(bool condition, String message) {
  if (!condition) throw StateError(message);
}
