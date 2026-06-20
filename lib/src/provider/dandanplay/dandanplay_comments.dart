import '../provider_result.dart';
import 'dandanplay_provider.dart';

enum DandanplayCommentMode {
  scrolling,
  top,
  bottom,
}

final class DandanplayComment {
  const DandanplayComment({
    required this.timestamp,
    required this.text,
    required this.mode,
    this.colorArgb,
  });

  final Duration timestamp;
  final String text;
  final DandanplayCommentMode mode;
  final int? colorArgb;
}

final class DandanplayCommentPost {
  const DandanplayCommentPost({
    required this.episodeId,
    required this.comment,
  });

  final DandanplayEpisodeId episodeId;
  final DandanplayComment comment;
}

abstract interface class DandanplayCommentProvider {
  Future<AcgProviderResult<List<DandanplayComment>>> commentsForEpisode(
      DandanplayEpisodeId episodeId);

  Future<AcgProviderResult<void>> postComment(DandanplayCommentPost post);
}
