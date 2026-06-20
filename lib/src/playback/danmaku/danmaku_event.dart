enum DanmakuMode {
  scrolling,
  top,
  bottom,
}

final class DanmakuCommentId {
  const DanmakuCommentId(this.value)
      : assert(value != '', 'Danmaku comment id must not be empty.');

  final String value;
}

final class DanmakuComment {
  const DanmakuComment({
    required this.id,
    required this.timestamp,
    required this.text,
    required this.mode,
    this.colorArgb,
  });

  final DanmakuCommentId id;
  final Duration timestamp;
  final String text;
  final DanmakuMode mode;
  final int? colorArgb;
}
