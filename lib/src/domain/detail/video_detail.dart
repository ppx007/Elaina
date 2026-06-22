import '../media/media_library.dart';

/// Video detail defaults point to Bangumi today, but remain provider-labelled so
/// future metadata providers can be added without changing UI state models.
const String bangumiVideoDetailProviderId = bangumiProviderBindingProviderId;
const String defaultVideoDetailMetadataProviderId =
    bangumiVideoDetailProviderId;

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

enum VideoTrackingStatus {
  notTracked,
  planned,
  watching,
  completed,
  onHold,
  dropped,
}

enum VideoTrackingConflictResolution {
  localToRemote,
  remoteToLocal,
}

enum VideoDetailMetadataSection {
  staff,
  characters,
  relations,
}

final class VideoDetailMetadataFailure {
  const VideoDetailMetadataFailure({
    required this.section,
    required this.message,
  }) : assert(message != '',
            'Video detail metadata failure message must not be empty.');

  final VideoDetailMetadataSection section;
  final String message;
}

final class VideoDetailMetadataStats {
  const VideoDetailMetadataStats({
    this.rank,
    this.score,
    this.collectionTotal,
    this.episodeCount,
  })  : assert(rank == null || rank > 0, 'Rank must be positive.'),
        assert(score == null || score >= 0, 'Score must not be negative.'),
        assert(collectionTotal == null || collectionTotal >= 0,
            'Collection total must not be negative.'),
        assert(episodeCount == null || episodeCount >= 0,
            'Episode count must not be negative.');

  final int? rank;
  final double? score;
  final int? collectionTotal;
  final int? episodeCount;

  bool get isEmpty =>
      rank == null &&
      score == null &&
      collectionTotal == null &&
      episodeCount == null;
}

final class VideoDetailCredit {
  const VideoDetailCredit({
    required this.id,
    required this.name,
    required this.role,
    this.imageUri,
    this.careers = const <String>[],
    this.episodeRange,
  })  : assert(id != '', 'Video detail credit id must not be empty.'),
        assert(name != '', 'Video detail credit name must not be empty.'),
        assert(role != '', 'Video detail credit role must not be empty.');

  final String id;
  final String name;
  final String role;
  final Uri? imageUri;
  final List<String> careers;
  final String? episodeRange;
}

final class VideoDetailVoiceActor {
  const VideoDetailVoiceActor({
    required this.id,
    required this.name,
    this.imageUri,
    this.careers = const <String>[],
  })  : assert(id != '', 'Video detail voice actor id must not be empty.'),
        assert(name != '', 'Video detail voice actor name must not be empty.');

  final String id;
  final String name;
  final Uri? imageUri;
  final List<String> careers;
}

final class VideoDetailCharacter {
  const VideoDetailCharacter({
    required this.id,
    required this.name,
    required this.role,
    this.summary,
    this.imageUri,
    this.voiceActors = const <VideoDetailVoiceActor>[],
  })  : assert(id != '', 'Video detail character id must not be empty.'),
        assert(name != '', 'Video detail character name must not be empty.'),
        assert(role != '', 'Video detail character role must not be empty.');

  final String id;
  final String name;
  final String role;
  final String? summary;
  final Uri? imageUri;
  final List<VideoDetailVoiceActor> voiceActors;
}

final class VideoDetailRelatedSubject {
  const VideoDetailRelatedSubject({
    required this.id,
    required this.title,
    required this.relation,
    this.coverUri,
    this.type,
  })  : assert(id != '', 'Video detail related subject id must not be empty.'),
        assert(title != '',
            'Video detail related subject title must not be empty.'),
        assert(relation != '',
            'Video detail related subject relation must not be empty.');

  final String id;
  final String title;
  final String relation;
  final Uri? coverUri;
  final int? type;
}

final class VideoTrackingConflict {
  const VideoTrackingConflict({
    required this.subjectId,
    required this.title,
    required this.localStatus,
    required this.remoteStatus,
    required this.localUpdatedAt,
    this.remoteUpdatedAt,
  })  : assert(subjectId != '',
            'Video tracking conflict subject id must not be empty.'),
        assert(title != '', 'Video tracking conflict title must not be empty.');

  final String subjectId;
  final String title;
  final VideoTrackingStatus localStatus;
  final VideoTrackingStatus remoteStatus;
  final DateTime localUpdatedAt;
  final DateTime? remoteUpdatedAt;
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

/// Complete read model consumed by the detail page.
///
/// It merges provider metadata, local playback binding, tracking state, and
/// partial table failures so UI never reaches into Bangumi JSON or storage rows.
final class VideoDetailViewData {
  const VideoDetailViewData({
    required this.id,
    required this.title,
    required this.episodes,
    required this.followState,
    required this.actions,
    VideoTrackingStatus? trackingStatus,
    this.metadataStats = const VideoDetailMetadataStats(),
    this.credits = const <VideoDetailCredit>[],
    this.characters = const <VideoDetailCharacter>[],
    this.relations = const <VideoDetailRelatedSubject>[],
    this.metadataFailures = const <VideoDetailMetadataFailure>[],
    this.coverUri,
    this.summary,
    this.continueWatching,
    this.binding,
    this.trackingConflict,
  })  : trackingStatus = trackingStatus ??
            (followState == VideoFollowState.followed
                ? VideoTrackingStatus.watching
                : VideoTrackingStatus.notTracked),
        assert(title != '', 'Video title must not be empty.');

  final VideoDetailId id;
  final String title;
  final Uri? coverUri;
  final String? summary;
  final VideoDetailMetadataStats metadataStats;
  final List<VideoDetailCredit> credits;
  final List<VideoDetailCharacter> characters;
  final List<VideoDetailRelatedSubject> relations;
  final List<VideoDetailMetadataFailure> metadataFailures;
  final List<VideoDetailEpisode> episodes;
  final ContinueWatchingState? continueWatching;
  final VideoFollowState followState;
  final VideoTrackingStatus trackingStatus;
  final VideoTrackingConflict? trackingConflict;
  final ProviderBinding? binding;
  final VideoDetailActionSet actions;
}

enum VideoDetailActionKind {
  continuePlayback,
  selectEpisode,
  follow,
  setTrackingStatus,
  openBinding,
  refreshMetadata,
}

final class VideoDetailAction {
  const VideoDetailAction({
    required this.kind,
    required this.label,
    this.episodeId,
    this.trackingStatus,
    this.primary = false,
  }) : assert(label != '', 'Action label must not be empty.');

  final VideoDetailActionKind kind;
  final String label;
  final VideoEpisodeId? episodeId;
  final VideoTrackingStatus? trackingStatus;
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

  Future<VideoDetailActionResult> setTrackingStatus(
      VideoDetailId id, VideoTrackingStatus status);

  Future<VideoDetailActionResult> resolveTrackingConflict(
    VideoDetailId id,
    VideoTrackingConflictResolution resolution,
  );
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

  Future<VideoDetailActionResult> setTrackingStatus(
          VideoDetailId id, VideoTrackingStatus status) =>
      _actions.setTrackingStatus(id, status);

  Future<VideoDetailActionResult> resolveTrackingConflict(
          VideoDetailId id, VideoTrackingConflictResolution resolution) =>
      _actions.resolveTrackingConflict(id, resolution);
}
