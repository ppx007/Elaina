import 'danmaku_event.dart';

final class DanmakuFilter {
  const DanmakuFilter({
    this.hiddenModes = const <DanmakuMode>{},
    this.blockedKeywords = const <String>{},
  });

  final Set<DanmakuMode> hiddenModes;
  final Set<String> blockedKeywords;

  bool allows(DanmakuComment comment) {
    if (hiddenModes.contains(comment.mode)) {
      return false;
    }
    for (final String keyword in blockedKeywords) {
      if (comment.text.contains(keyword)) {
        return false;
      }
    }
    return true;
  }
}

final class DanmakuDensityPolicy {
  const DanmakuDensityPolicy({required this.maxCommentsPerWindow, required this.window})
      : assert(maxCommentsPerWindow >= 0, 'maxCommentsPerWindow must not be negative.'),
        assert(window > Duration.zero, 'window must be positive.');

  final int maxCommentsPerWindow;
  final Duration window;
}
