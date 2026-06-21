import '../../domain/detail/video_detail.dart';

final class VideoDetailPageContract {
  const VideoDetailPageContract({required VideoDetailController controller})
      : _controller = controller;

  final VideoDetailController _controller;

  Future<VideoDetailViewData> load(VideoDetailId id) => _controller.load(id);

  Stream<VideoDetailViewData> watch(VideoDetailId id) => _controller.watch(id);

  Future<VideoDetailActionResult> continuePlayback(VideoDetailId id) =>
      _controller.continuePlayback(id);

  Future<VideoDetailActionResult> perform(
          VideoDetailId id, VideoDetailAction action) =>
      _controller.perform(id, action);

  Future<VideoDetailActionResult> selectEpisode(
          VideoDetailId id, VideoEpisodeId episodeId) =>
      _controller.selectEpisode(id, episodeId);

  Future<VideoDetailActionResult> follow(VideoDetailId id) =>
      _controller.follow(id);

  Future<VideoDetailActionResult> setTrackingStatus(
          VideoDetailId id, VideoTrackingStatus status) =>
      _controller.setTrackingStatus(id, status);

  Future<VideoDetailActionResult> resolveTrackingConflict(
    VideoDetailId id,
    VideoTrackingConflictResolution resolution,
  ) =>
      _controller.resolveTrackingConflict(id, resolution);
}
