import '../player_clock.dart';
import 'danmaku_event.dart';
import 'danmaku_filter.dart';

final class DanmakuRenderLane {
  DanmakuRenderLane(
      {required this.mode, required Iterable<DanmakuComment> comments})
      : comments = List<DanmakuComment>.unmodifiable(comments);

  final DanmakuMode mode;
  final List<DanmakuComment> comments;
}

final class DanmakuRenderFrame {
  DanmakuRenderFrame(
      {required this.clock, required Iterable<DanmakuRenderLane> lanes})
      : lanes = List<DanmakuRenderLane>.unmodifiable(lanes);

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

final class DeterministicBasicDanmakuRenderer implements BasicDanmakuRenderer {
  const DeterministicBasicDanmakuRenderer();

  @override
  DanmakuRenderFrame frameFor({
    required PlayerClockSnapshot clock,
    required Iterable<DanmakuComment> comments,
    required DanmakuFilter filter,
    required DanmakuDensityPolicy densityPolicy,
  }) {
    if (densityPolicy.window <= Duration.zero) {
      throw ArgumentError.value(
        densityPolicy.window,
        'densityPolicy.window',
        'must be positive',
      );
    }
    final Duration windowStart = clock.position - densityPolicy.window;
    final List<DanmakuComment> eligible = <DanmakuComment>[
      for (final DanmakuComment comment in comments)
        if (comment.timestamp >= windowStart &&
            comment.timestamp <= clock.position &&
            filter.allows(comment))
          comment,
    ]..sort(_compareComments);
    final Iterable<DanmakuComment> visible =
        densityPolicy.maxCommentsPerWindow == 0
            ? const <DanmakuComment>[]
            : eligible.take(densityPolicy.maxCommentsPerWindow);
    final Map<DanmakuMode, List<DanmakuComment>> grouped =
        <DanmakuMode, List<DanmakuComment>>{
      for (final DanmakuMode mode in DanmakuMode.values)
        mode: <DanmakuComment>[],
    };
    for (final DanmakuComment comment in visible) {
      grouped[comment.mode]!.add(comment);
    }
    return DanmakuRenderFrame(
      clock: clock,
      lanes: <DanmakuRenderLane>[
        for (final DanmakuMode mode in DanmakuMode.values)
          DanmakuRenderLane(mode: mode, comments: grouped[mode]!),
      ],
    );
  }

  int _compareComments(DanmakuComment left, DanmakuComment right) {
    final int timestamp = left.timestamp.compareTo(right.timestamp);
    if (timestamp != 0) return timestamp;
    return left.id.value.compareTo(right.id.value);
  }
}
