import '../../playback/danmaku/danmaku_event.dart';
import '../../playback/danmaku/danmaku_renderer.dart';
import '../../playback/danmaku/danmaku_runtime_state.dart';
import '../../provider/dandanplay/dandanplay_comments.dart';
import '../playback/playback_state.dart';

PlaybackDanmakuStateSnapshot playbackDanmakuStateFromRuntimeSnapshot(
  BasicDanmakuRuntimeSnapshot snapshot,
) {
  return PlaybackDanmakuStateSnapshot(
    clockPosition: snapshot.activeFrame.clock.position,
    lanes: <DomainDanmakuLaneDescriptor>[
      for (final DanmakuRenderLane lane in snapshot.activeFrame.lanes)
        DomainDanmakuLaneDescriptor(
          mode: domainDanmakuModeFromPlayback(lane.mode),
          comments: <DomainDanmakuCommentDescriptor>[
            for (final DanmakuComment comment in lane.comments)
              DomainDanmakuCommentDescriptor(
                id: comment.id.value,
                timestamp: comment.timestamp,
                text: comment.text,
                mode: domainDanmakuModeFromPlayback(comment.mode),
                colorArgb: comment.colorArgb,
              ),
          ],
        ),
    ],
    warnings: snapshot.warnings,
    failureReason: snapshot.failure?.message,
  );
}

DanmakuComment danmakuCommentFromDandanplay(
  DandanplayComment comment, {
  required String idPrefix,
  required int index,
}) {
  return DanmakuComment(
    id: DanmakuCommentId(
      '$idPrefix:${comment.timestamp.inMilliseconds}:$index:${_stableTextHash(comment.text)}',
    ),
    timestamp: comment.timestamp,
    text: comment.text,
    mode: danmakuModeFromDandanplay(comment.mode),
    colorArgb: comment.colorArgb,
  );
}

List<DanmakuComment> danmakuCommentsFromDandanplay(
  Iterable<DandanplayComment> comments, {
  required String idPrefix,
}) {
  var index = 0;
  return List<DanmakuComment>.unmodifiable(<DanmakuComment>[
    for (final DandanplayComment comment in comments)
      danmakuCommentFromDandanplay(
        comment,
        idPrefix: idPrefix,
        index: index++,
      ),
  ]);
}

DanmakuMode danmakuModeFromDandanplay(DandanplayCommentMode mode) {
  return switch (mode) {
    DandanplayCommentMode.scrolling => DanmakuMode.scrolling,
    DandanplayCommentMode.top => DanmakuMode.top,
    DandanplayCommentMode.bottom => DanmakuMode.bottom,
  };
}

DomainDanmakuMode domainDanmakuModeFromPlayback(DanmakuMode mode) {
  return switch (mode) {
    DanmakuMode.scrolling => DomainDanmakuMode.scrolling,
    DanmakuMode.top => DomainDanmakuMode.top,
    DanmakuMode.bottom => DomainDanmakuMode.bottom,
  };
}

String _stableTextHash(String text) {
  var hash = 0x811c9dc5;
  for (final int codeUnit in text.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}
