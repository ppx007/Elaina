import '../media/media_library.dart';

final class VideoDetailId {
  const VideoDetailId(this.value) : assert(value != '', 'Video detail id must not be empty.');

  final String value;
}

final class VideoEpisodeId {
  const VideoEpisodeId(this.value) : assert(value != '', 'Video episode id must not be empty.');

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
    this.localMediaId,
    this.continueWatching,
  })  : assert(index > 0, 'Episode index must be positive.'),
        assert(title != '', 'Episode title must not be empty.');

  final VideoEpisodeId id;
  final int index;
  final String title;
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

  List<VideoDetailAction> get primary => actions.where((action) => action.primary).toList(growable: false);

  List<VideoDetailAction> get secondary => actions.where((action) => !action.primary).toList(growable: false);

  bool get hasValidPrimaryCount => primary.length <= 2;
}

abstract interface class VideoDetailRepository {
  Future<VideoDetailViewData> load(VideoDetailId id);

  Stream<VideoDetailViewData> watch(VideoDetailId id);
}

abstract interface class VideoDetailActionHandler {
  Future<void> perform(VideoDetailId id, VideoDetailAction action);

  Future<void> continuePlayback(VideoDetailId id);

  Future<void> selectEpisode(VideoDetailId id, VideoEpisodeId episodeId);

  Future<void> follow(VideoDetailId id);

  Future<void> unfollow(VideoDetailId id);
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

  Future<void> continuePlayback(VideoDetailId id) => _actions.continuePlayback(id);

  Future<void> perform(VideoDetailId id, VideoDetailAction action) => _actions.perform(id, action);

  Future<void> selectEpisode(VideoDetailId id, VideoEpisodeId episodeId) => _actions.selectEpisode(id, episodeId);

  Future<void> follow(VideoDetailId id) => _actions.follow(id);

  Future<void> unfollow(VideoDetailId id) => _actions.unfollow(id);
}
