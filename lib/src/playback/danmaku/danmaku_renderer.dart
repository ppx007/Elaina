import '../player_clock.dart';
import 'danmaku_event.dart';
import 'danmaku_filter.dart';

final class DanmakuRenderLane {
  const DanmakuRenderLane({required this.mode, required this.comments});

  final DanmakuMode mode;
  final List<DanmakuComment> comments;
}

final class DanmakuRenderFrame {
  const DanmakuRenderFrame({required this.clock, required this.lanes});

  final PlayerClockSnapshot clock;
  final List<DanmakuRenderLane> lanes;
}

abstract interface class BasicDanmakuRenderer {
  DanmakuRenderFrame frameFor({
    required PlayerClockSnapshot clock,
    required Iterable<DanmakuComment> comments,
    required DanmakuFilter filter,
    required DanmakuDensityPolicy densityPolicy,
  });
}
