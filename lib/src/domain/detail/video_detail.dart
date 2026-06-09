import '../media/media_library.dart';

final class VideoDetailId {
  const VideoDetailId(this.value)
      : assert(value != '', 'Video detail id must not be empty.');

  final String value;
}

final class VideoEpisodeId {
  const VideoEpisodeId(this.value)
      : assert(value != '', 'Video episode id must not be empty.');

  final String value;
}

enum VideoFollowState {
  notFollowed,
  followed,
  updating,
}

final class VideoDetailEpisode {
  const VideoDetailEpisode({
    required this.id,
    required this.index,
    required this.title,
    this.localMedia,
    this.localMediaId,
    this.continueWatching,
  })  : assert(index > 0, 'Episode index must be positive.'),
        assert(title != '', 'Episode title must not be empty.');

  final VideoEpisodeId id;
  final int index;
  final String title;
  final LocalMediaIdentity? localMedia;
  final LocalMediaId? localMediaId;
  final ContinueWatchingState? continueWatching;
}

final class VideoDetailViewData {
  const VideoDetailViewData({
    required this.id,
    required this.title,
    required this.episodes,
    required this.followState,
    required this.actions,
    this.coverUri,
    this.summary,
    this.continueWatching,
    this.binding,
  }) : assert(title != '', 'Video title must not be empty.');

  final VideoDetailId id;
  final String title;
  final Uri? coverUri;
  final String? summary;
  final List<VideoDetailEpisode> episodes;
  final ContinueWatchingState? continueWatching;
  final VideoFollowState followState;
  final ProviderBinding? binding;
  final VideoDetailActionSet actions;
}

enum VideoDetailActionKind {
  continuePlayback,
  selectEpisode,
  follow,
  unfollow,
  openBinding,
  refreshMetadata,
}

final class VideoDetailAction {
  const VideoDetailAction({
    required this.kind,
    required this.label,
    this.episodeId,
    this.primary = false,
  }) : assert(label != '', 'Action label must not be empty.');

  final VideoDetailActionKind kind;
  final String label;
  final VideoEpisodeId? episodeId;
  final bool primary;
}

final class VideoDetailActionSet {
  const VideoDetailActionSet({required this.actions});

  final List<VideoDetailAction> actions;

  List<VideoDetailAction> get primary =>
      actions.where((action) => action.primary).toList(growable: false);

  List<VideoDetailAction> get secondary =>
      actions.where((action) => !action.primary).toList(growable: false);

  bool get hasValidPrimaryCount => primary.length <= 2;
}

enum VideoDetailActionResultKind {
  success,
  ignored,
  unsupported,
  unavailable,
  failed,
}

final class VideoDetailActionFailure {
  const VideoDetailActionFailure({required this.message, this.code})
      : assert(message != '',
            'Video detail action failure message must not be empty.');

  final String message;
  final String? code;
}

final class VideoDetailActionResult {
  const VideoDetailActionResult._({required this.kind, this.failure});

  const VideoDetailActionResult.success()
      : this._(kind: VideoDetailActionResultKind.success, failure: null);

  VideoDetailActionResult.ignored(String message)
      : this._(
            kind: VideoDetailActionResultKind.ignored,
            failure: VideoDetailActionFailure(message: message));

  VideoDetailActionResult.unsupported(String message)
      : this._(
            kind: VideoDetailActionResultKind.unsupported,
            failure: VideoDetailActionFailure(message: message));

  VideoDetailActionResult.unavailable(String message)
      : this._(
            kind: VideoDetailActionResultKind.unavailable,
            failure: VideoDetailActionFailure(message: message));

  VideoDetailActionResult.failed(String message, {String? code})
      : this._(
            kind: VideoDetailActionResultKind.failed,
            failure: VideoDetailActionFailure(message: message, code: code));

  final VideoDetailActionResultKind kind;
  final VideoDetailActionFailure? failure;

  bool get isSuccess => kind == VideoDetailActionResultKind.success;
}

abstract interface class VideoDetailRepository {
  Future<VideoDetailViewData> load(VideoDetailId id);

  Stream<VideoDetailViewData> watch(VideoDetailId id);
}

abstract interface class VideoDetailActionHandler {
  Future<VideoDetailActionResult> perform(
      VideoDetailId id, VideoDetailAction action);

  Future<VideoDetailActionResult> continuePlayback(VideoDetailId id);

  Future<VideoDetailActionResult> selectEpisode(
      VideoDetailId id, VideoEpisodeId episodeId);

  Future<VideoDetailActionResult> follow(VideoDetailId id);

  Future<VideoDetailActionResult> unfollow(VideoDetailId id);
}

final class VideoDetailController {
  const VideoDetailController({
    required VideoDetailRepository repository,
    required VideoDetailActionHandler actions,
  })  : _repository = repository,
        _actions = actions;

  final VideoDetailRepository _repository;
  final VideoDetailActionHandler _actions;

  Future<VideoDetailViewData> load(VideoDetailId id) => _repository.load(id);

  Stream<VideoDetailViewData> watch(VideoDetailId id) => _repository.watch(id);

  Future<VideoDetailActionResult> continuePlayback(VideoDetailId id) =>
      _actions.continuePlayback(id);

  Future<VideoDetailActionResult> perform(
          VideoDetailId id, VideoDetailAction action) =>
      _actions.perform(id, action);

  Future<VideoDetailActionResult> selectEpisode(
          VideoDetailId id, VideoEpisodeId episodeId) =>
      _actions.selectEpisode(id, episodeId);

  Future<VideoDetailActionResult> follow(VideoDetailId id) =>
      _actions.follow(id);

  Future<VideoDetailActionResult> unfollow(VideoDetailId id) =>
      _actions.unfollow(id);
}
