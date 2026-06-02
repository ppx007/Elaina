import '../../domain/detail/video_detail.dart';

final class VideoDetailPageContract {
  const VideoDetailPageContract({required VideoDetailController controller}) : _controller = controller;

  final VideoDetailController _controller;

  Future<VideoDetailViewData> load(VideoDetailId id) => _controller.load(id);

  Stream<VideoDetailViewData> watch(VideoDetailId id) => _controller.watch(id);

  Future<void> continuePlayback(VideoDetailId id) => _controller.continuePlayback(id);

  Future<void> perform(VideoDetailId id, VideoDetailAction action) => _controller.perform(id, action);

  Future<void> selectEpisode(VideoDetailId id, VideoEpisodeId episodeId) => _controller.selectEpisode(id, episodeId);

  Future<void> follow(VideoDetailId id) => _controller.follow(id);

  Future<void> unfollow(VideoDetailId id) => _controller.unfollow(id);
}
