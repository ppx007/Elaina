import '../../foundation/cache_invalidation/cache_invalidation_bus.dart';
import '../../provider/bangumi/bangumi_provider.dart';
import '../../provider/provider_result.dart';
import '../media/media_library.dart';
import '../playback/playback_source_handoff.dart';
import 'video_detail.dart';

const String defaultVideoDetailMetadataProviderId = 'bangumi';

enum VideoDetailRuntimeStatus {
  idle,
  ready,
  failed,
  disposed,
}

enum VideoDetailRuntimeFailureKind {
  disposed,
  metadataUnavailable,
  actionUnavailable,
  playbackHandoffFailed,
}

final class VideoDetailRuntimeFailure {
  const VideoDetailRuntimeFailure({required this.kind, required this.message})
      : assert(message != '',
            'Video detail runtime failure message must not be empty.');

  final VideoDetailRuntimeFailureKind kind;
  final String message;
}

final class VideoDetailRuntimeSnapshot {
  VideoDetailRuntimeSnapshot({
    required this.status,
    this.activeDetail,
    Iterable<VideoDetailRuntimeFailure> failures =
        const <VideoDetailRuntimeFailure>[],
  }) : failures = List<VideoDetailRuntimeFailure>.unmodifiable(failures);

  const VideoDetailRuntimeSnapshot.idle()
      : status = VideoDetailRuntimeStatus.idle,
        activeDetail = null,
        failures = const <VideoDetailRuntimeFailure>[];

  final VideoDetailRuntimeStatus status;
  final VideoDetailViewData? activeDetail;
  final List<VideoDetailRuntimeFailure> failures;
}

abstract interface class VideoDetailRuntimeObserver {
  void onVideoDetailRuntimeSnapshot(VideoDetailRuntimeSnapshot snapshot);
}

final class BangumiVideoDetailSeed {
  const BangumiVideoDetailSeed({
    required this.subject,
    required this.episodes,
    this.coverUri,
    this.localMediaId,
    this.localMediaByEpisodeId = const <String, LocalMediaIdentity>{},
  });

  final BangumiSubject subject;
  final List<BangumiEpisode> episodes;
  final Uri? coverUri;
  final LocalMediaId? localMediaId;
  final Map<String, LocalMediaIdentity> localMediaByEpisodeId;
}

VideoDetailEpisode videoDetailEpisodeFromBangumi({
  required BangumiEpisode episode,
  LocalMediaIdentity? localMedia,
  ContinueWatchingState? continueWatching,
}) {
  return VideoDetailEpisode(
    id: VideoEpisodeId(episode.id.value),
    index: episode.index,
    title: episode.title,
    localMedia: localMedia,
    localMediaId: localMedia?.id,
    continueWatching: continueWatching,
  );
}

VideoFollowState videoFollowStateFromBinding(ProviderBinding? binding) {
  if (binding == null) return VideoFollowState.notFollowed;
  return binding.authority == ProviderBindingAuthority.userConfirmed
      ? VideoFollowState.followed
      : VideoFollowState.notFollowed;
}

VideoDetailActionSet deriveVideoDetailActions(VideoDetailViewData data) {
  final List<VideoDetailAction> actions = <VideoDetailAction>[];
  if (data.continueWatching != null) {
    actions.add(const VideoDetailAction(
      kind: VideoDetailActionKind.continuePlayback,
      label: 'Continue Watching',
      primary: true,
    ));
  }
  if (data.continueWatching == null && data.episodes.isNotEmpty) {
    actions.add(VideoDetailAction(
      kind: VideoDetailActionKind.selectEpisode,
      label: data.episodes.first.title,
      episodeId: data.episodes.first.id,
      primary: true,
    ));
  }
  if (data.followState == VideoFollowState.followed) {
    actions.add(const VideoDetailAction(
        kind: VideoDetailActionKind.unfollow, label: 'Unfollow'));
  } else {
    actions.add(const VideoDetailAction(
        kind: VideoDetailActionKind.follow, label: 'Follow'));
  }
  if (data.binding != null) {
    actions.add(const VideoDetailAction(
        kind: VideoDetailActionKind.openBinding, label: 'Open Binding'));
  }
  actions.add(const VideoDetailAction(
      kind: VideoDetailActionKind.refreshMetadata, label: 'Refresh Metadata'));
  for (final VideoDetailEpisode episode in data.episodes.skip(1)) {
    actions.add(VideoDetailAction(
        kind: VideoDetailActionKind.selectEpisode,
        label: episode.title,
        episodeId: episode.id));
  }
  return VideoDetailActionSet(
      actions: List<VideoDetailAction>.unmodifiable(actions));
}

final class DeterministicVideoDetailRepository
    implements VideoDetailRepository {
  DeterministicVideoDetailRepository({
    required BangumiProvider metadataProvider,
    required ProviderBindingStore bindingStore,
    required PlaybackHistoryStore historyStore,
    Iterable<BangumiVideoDetailSeed> seeds = const <BangumiVideoDetailSeed>[],
    String providerId = defaultVideoDetailMetadataProviderId,
  })  : _metadataProvider = metadataProvider,
        _bindingStore = bindingStore,
        _historyStore = historyStore,
        _providerId = providerId,
        _seedsBySubjectId = <String, BangumiVideoDetailSeed>{
          for (final BangumiVideoDetailSeed seed in seeds)
            seed.subject.id.value: seed,
        };

  final BangumiProvider _metadataProvider;
  final ProviderBindingStore _bindingStore;
  final PlaybackHistoryStore _historyStore;
  final String _providerId;
  final Map<String, BangumiVideoDetailSeed> _seedsBySubjectId;
  bool _disposed = false;

  bool get isDisposed => _disposed;

  void dispose() {
    _disposed = true;
  }

  @override
  Future<VideoDetailViewData> load(VideoDetailId id) async {
    _checkNotDisposed();
    final AcgProviderResult<BangumiSubject> result =
        await _metadataProvider.lookupSubject(BangumiSubjectId(id.value));
    if (result is AcgProviderFailure<BangumiSubject>) {
      throw StateError(result.message);
    }
    final BangumiSubject subject =
        (result as AcgProviderSuccess<BangumiSubject>).value;
    final BangumiVideoDetailSeed? seed = _seedsBySubjectId[subject.id.value];
    final List<BangumiEpisode> episodes = <BangumiEpisode>[
      ...(seed?.episodes ?? const <BangumiEpisode>[])
    ]..sort((BangumiEpisode left, BangumiEpisode right) =>
        left.index.compareTo(right.index));
    final ProviderBinding? binding = await _strongestBindingFor(seed);
    final List<VideoDetailEpisode> detailEpisodes = <VideoDetailEpisode>[];
    ContinueWatchingState? latestContinue;
    for (final BangumiEpisode episode in episodes) {
      final LocalMediaIdentity? localMedia =
          seed?.localMediaByEpisodeId[episode.id.value];
      final ContinueWatchingState? episodeContinue =
          localMedia == null ? null : await _continueWatchingFor(localMedia.id);
      if (episodeContinue != null &&
          (latestContinue == null ||
              episodeContinue.updatedAt.isAfter(latestContinue.updatedAt))) {
        latestContinue = episodeContinue;
      }
      detailEpisodes.add(videoDetailEpisodeFromBangumi(
          episode: episode,
          localMedia: localMedia,
          continueWatching: episodeContinue));
    }
    final VideoDetailViewData partial = VideoDetailViewData(
      id: VideoDetailId(subject.id.value),
      title: subject.title,
      coverUri: seed?.coverUri,
      summary: subject.summary,
      episodes: List<VideoDetailEpisode>.unmodifiable(detailEpisodes),
      continueWatching: latestContinue,
      followState: videoFollowStateFromBinding(binding),
      binding: binding,
      actions: const VideoDetailActionSet(actions: <VideoDetailAction>[]),
    );
    return VideoDetailViewData(
      id: partial.id,
      title: partial.title,
      coverUri: partial.coverUri,
      summary: partial.summary,
      episodes: partial.episodes,
      continueWatching: partial.continueWatching,
      followState: partial.followState,
      binding: partial.binding,
      actions: deriveVideoDetailActions(partial),
    );
  }

  @override
  Stream<VideoDetailViewData> watch(VideoDetailId id) async* {
    yield await load(id);
  }

  LocalMediaId? _firstLocalMediaId(BangumiVideoDetailSeed? seed) {
    if (seed == null || seed.localMediaByEpisodeId.isEmpty) return null;
    return seed.localMediaByEpisodeId.values.first.id;
  }

  Future<ProviderBinding?> _strongestBindingFor(
      BangumiVideoDetailSeed? seed) async {
    ProviderBinding? strongest;
    for (final LocalMediaId mediaId in _seedMediaIds(seed)) {
      final ProviderBinding? binding = await _bindingStore.bindingForProvider(
          mediaId: mediaId, providerId: _providerId);
      if (binding != null &&
          (strongest == null || binding.outranks(strongest))) {
        strongest = binding;
      }
    }
    return strongest;
  }

  List<LocalMediaId> _seedMediaIds(BangumiVideoDetailSeed? seed) {
    if (seed == null) return const <LocalMediaId>[];
    final Map<String, LocalMediaId> mediaIds = <String, LocalMediaId>{};
    final LocalMediaId? detailMediaId =
        seed.localMediaId ?? _firstLocalMediaId(seed);
    if (detailMediaId != null) mediaIds[detailMediaId.value] = detailMediaId;
    for (final LocalMediaIdentity identity
        in seed.localMediaByEpisodeId.values) {
      mediaIds[identity.id.value] = identity.id;
    }
    return List<LocalMediaId>.unmodifiable(mediaIds.values);
  }

  Future<ContinueWatchingState?> _continueWatchingFor(
      LocalMediaId mediaId) async {
    final PlaybackHistoryEntry? entry = await _historyStore.latestFor(mediaId);
    if (entry == null) return null;
    return ContinueWatchingState(
        mediaId: mediaId,
        position: entry.position,
        duration: entry.duration,
        updatedAt: entry.updatedAt);
  }

  void _checkNotDisposed() {
    if (_disposed)
      throw StateError('Video detail repository has been disposed.');
  }
}

final class DeterministicVideoDetailActionHandler
    implements VideoDetailActionHandler {
  DeterministicVideoDetailActionHandler({
    required VideoDetailRepository repository,
    required ProviderBindingStore bindingStore,
    required PlaybackSourceHandoffContract playbackSourceHandoff,
    required CacheInvalidationBus invalidationBus,
    String providerId = defaultVideoDetailMetadataProviderId,
    DateTime Function()? now,
  })  : _repository = repository,
        _bindingStore = bindingStore,
        _playbackSourceHandoff = playbackSourceHandoff,
        _invalidationBus = invalidationBus,
        _providerId = providerId,
        _now = now;

  final VideoDetailRepository _repository;
  final ProviderBindingStore _bindingStore;
  final PlaybackSourceHandoffContract _playbackSourceHandoff;
  final CacheInvalidationBus _invalidationBus;
  final String _providerId;
  final DateTime Function()? _now;
  bool _disposed = false;

  bool get isDisposed => _disposed;

  void dispose() {
    _disposed = true;
  }

  @override
  Future<VideoDetailActionResult> perform(
      VideoDetailId id, VideoDetailAction action) {
    return switch (action.kind) {
      VideoDetailActionKind.continuePlayback => continuePlayback(id),
      VideoDetailActionKind.selectEpisode => action.episodeId == null
          ? Future<VideoDetailActionResult>.value(
              VideoDetailActionResult.unsupported(
                  'Episode action is missing an episode id.'))
          : selectEpisode(id, action.episodeId!),
      VideoDetailActionKind.follow => follow(id),
      VideoDetailActionKind.unfollow => unfollow(id),
      VideoDetailActionKind.openBinding =>
        Future<VideoDetailActionResult>.value(VideoDetailActionResult.ignored(
            'Open binding is a UI navigation action.')),
      VideoDetailActionKind.refreshMetadata => _refreshMetadata(id),
    };
  }

  @override
  Future<VideoDetailActionResult> continuePlayback(VideoDetailId id) async {
    return _withLoadedData(id, (VideoDetailViewData data) async {
      final ContinueWatchingState? continueWatching = data.continueWatching;
      if (continueWatching == null)
        return VideoDetailActionResult.unavailable(
            'No continue-watching state is available.');
      final VideoDetailEpisode? episode =
          _episodeForMedia(data, continueWatching.mediaId);
      if (episode == null)
        return VideoDetailActionResult.unavailable(
            'Continue-watching media is not attached to an episode.');
      return _prepareEpisode(data, episode);
    });
  }

  @override
  Future<VideoDetailActionResult> selectEpisode(
      VideoDetailId id, VideoEpisodeId episodeId) async {
    return _withLoadedData(id, (VideoDetailViewData data) async {
      final VideoDetailEpisode? episode = data.episodes
          .where(
              (VideoDetailEpisode value) => value.id.value == episodeId.value)
          .firstOrNull;
      if (episode == null)
        return VideoDetailActionResult.unavailable(
            'Selected episode was not found.');
      return _prepareEpisode(data, episode);
    });
  }

  @override
  Future<VideoDetailActionResult> follow(VideoDetailId id) async {
    return _withLoadedData(id, (VideoDetailViewData data) async {
      final LocalMediaId? mediaId = _primaryMediaId(data);
      if (mediaId == null)
        return VideoDetailActionResult.unavailable(
            'Cannot follow a detail without local media.');
      final ProviderBinding binding = ProviderBinding(
        id: ProviderBindingId('${mediaId.value}:$_providerId:${data.id.value}'),
        localMediaId: mediaId,
        providerId: _providerId,
        subjectId: ProviderSubjectId(data.id.value),
        authority: ProviderBindingAuthority.userConfirmed,
        confidence: 1,
        createdAt: (_now ?? DateTime.now)(),
      );
      final ProviderBinding saved =
          await _bindingStore.saveUserConfirmed(binding);
      _invalidationBus.publish(BindingChanged(
          occurredAt: saved.createdAt,
          localMediaId: saved.localMediaId.value,
          providerId: saved.providerId,
          providerSubjectId: saved.subjectId?.value));
      return const VideoDetailActionResult.success();
    });
  }

  @override
  Future<VideoDetailActionResult> unfollow(VideoDetailId id) async {
    return _withLoadedData(id, (VideoDetailViewData data) async {
      final ProviderBinding? binding = data.binding;
      if (binding == null)
        return VideoDetailActionResult.ignored('Detail is not followed.');
      final ProviderBinding automatic = ProviderBinding(
        id: binding.id,
        localMediaId: binding.localMediaId,
        providerId: binding.providerId,
        subjectId: binding.subjectId,
        authority: ProviderBindingAuthority.automatic,
        confidence: 0,
        createdAt: (_now ?? DateTime.now)(),
      );
      await _bindingStore.saveUserConfirmed(automatic);
      _invalidationBus.publish(BindingChanged(
          occurredAt: automatic.createdAt,
          localMediaId: automatic.localMediaId.value,
          providerId: automatic.providerId,
          providerSubjectId: automatic.subjectId?.value));
      return const VideoDetailActionResult.success();
    });
  }

  Future<VideoDetailActionResult> _refreshMetadata(VideoDetailId id) async {
    return _withLoadedData(id, (VideoDetailViewData data) async {
      final LocalMediaId? mediaId = _primaryMediaId(data);
      if (mediaId == null)
        return VideoDetailActionResult.unavailable(
            'Cannot refresh metadata without local media.');
      _invalidationBus.publish(BindingChanged(
          occurredAt: (_now ?? DateTime.now)(),
          localMediaId: mediaId.value,
          providerId: _providerId,
          providerSubjectId: id.value));
      return const VideoDetailActionResult.success();
    });
  }

  Future<VideoDetailActionResult> _prepareEpisode(
      VideoDetailViewData data, VideoDetailEpisode episode) async {
    final LocalMediaIdentity? identity = episode.localMedia;
    if (identity == null)
      return VideoDetailActionResult.unavailable(
          'Episode has no local media identity.');
    final PlaybackSourceHandoffResult result = _playbackSourceHandoff
        .prepare(PlaybackSourceHandoffInput.localMediaIdentity(identity));
    if (!result.isSuccess) {
      return VideoDetailActionResult.unsupported(
          result.failure?.message ?? 'Playback source handoff failed.');
    }
    _invalidationBus.publish(HistoryRecorded(
        occurredAt: (_now ?? DateTime.now)(), localMediaId: identity.id.value));
    return const VideoDetailActionResult.success();
  }

  VideoDetailEpisode? _episodeForMedia(
      VideoDetailViewData data, LocalMediaId mediaId) {
    for (final VideoDetailEpisode episode in data.episodes) {
      if (episode.localMediaId?.value == mediaId.value) return episode;
    }
    return null;
  }

  LocalMediaId? _primaryMediaId(VideoDetailViewData data) {
    if (data.continueWatching != null) return data.continueWatching!.mediaId;
    for (final VideoDetailEpisode episode in data.episodes) {
      if (episode.localMediaId != null) return episode.localMediaId;
    }
    return data.binding?.localMediaId;
  }

  Future<VideoDetailActionResult> _withLoadedData(
      VideoDetailId id,
      Future<VideoDetailActionResult> Function(VideoDetailViewData data)
          action) async {
    if (_disposed) return _disposedResult();
    final VideoDetailViewData data;
    try {
      data = await _repository.load(id);
    } on StateError catch (error) {
      return VideoDetailActionResult.failed(error.message);
    }
    return action(data);
  }

  VideoDetailActionResult _disposedResult() {
    return VideoDetailActionResult.unavailable(
        'Video detail action handler has been disposed.');
  }
}

final class VideoDetailRuntime {
  factory VideoDetailRuntime({
    required BangumiProvider metadataProvider,
    required ProviderBindingStore bindingStore,
    required PlaybackHistoryStore historyStore,
    required PlaybackSourceHandoffContract playbackSourceHandoff,
    required CacheInvalidationBus invalidationBus,
    Iterable<BangumiVideoDetailSeed> seeds = const <BangumiVideoDetailSeed>[],
    String providerId = defaultVideoDetailMetadataProviderId,
    DateTime Function()? now,
  }) {
    final DeterministicVideoDetailRepository repository =
        DeterministicVideoDetailRepository(
      metadataProvider: metadataProvider,
      bindingStore: bindingStore,
      historyStore: historyStore,
      seeds: seeds,
      providerId: providerId,
    );
    final DeterministicVideoDetailActionHandler actionHandler =
        DeterministicVideoDetailActionHandler(
      repository: repository,
      bindingStore: bindingStore,
      playbackSourceHandoff: playbackSourceHandoff,
      invalidationBus: invalidationBus,
      providerId: providerId,
      now: now,
    );
    return VideoDetailRuntime.withDependencies(
      repository: repository,
      actionHandler: actionHandler,
      disposeRepository: repository.dispose,
      disposeActionHandler: actionHandler.dispose,
    );
  }

  VideoDetailRuntime.withDependencies({
    required this.repository,
    required this.actionHandler,
    void Function()? disposeRepository,
    void Function()? disposeActionHandler,
  })  : _disposeRepository = disposeRepository,
        _disposeActionHandler = disposeActionHandler {
    controller =
        VideoDetailController(repository: repository, actions: actionHandler);
  }

  final VideoDetailRepository repository;
  final VideoDetailActionHandler actionHandler;
  final void Function()? _disposeRepository;
  final void Function()? _disposeActionHandler;
  late final VideoDetailController controller;
  final List<VideoDetailRuntimeObserver> _observers =
      <VideoDetailRuntimeObserver>[];
  VideoDetailRuntimeSnapshot _snapshot =
      const VideoDetailRuntimeSnapshot.idle();
  bool _disposed = false;

  bool get isDisposed => _disposed;

  VideoDetailRuntimeSnapshot get currentSnapshot => _snapshot;

  void addObserver(VideoDetailRuntimeObserver observer) {
    if (_disposed) throw StateError('VideoDetailRuntime has been disposed.');
    if (!_observers.contains(observer)) _observers.add(observer);
  }

  void removeObserver(VideoDetailRuntimeObserver observer) {
    _observers.remove(observer);
  }

  Future<VideoDetailViewData> load(VideoDetailId id) async {
    if (_disposed) throw StateError('VideoDetailRuntime has been disposed.');
    final VideoDetailViewData detail = await repository.load(id);
    _publish(VideoDetailRuntimeSnapshot(
        status: VideoDetailRuntimeStatus.ready, activeDetail: detail));
    return detail;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _disposeRepository?.call();
    _disposeActionHandler?.call();
    _publish(VideoDetailRuntimeSnapshot(
      status: VideoDetailRuntimeStatus.disposed,
      activeDetail: _snapshot.activeDetail,
      failures: const <VideoDetailRuntimeFailure>[
        VideoDetailRuntimeFailure(
            kind: VideoDetailRuntimeFailureKind.disposed,
            message: 'VideoDetailRuntime has been disposed.'),
      ],
    ));
    _observers.clear();
  }

  void _publish(VideoDetailRuntimeSnapshot snapshot) {
    _snapshot = snapshot;
    for (final VideoDetailRuntimeObserver observer
        in List<VideoDetailRuntimeObserver>.of(_observers)) {
      observer.onVideoDetailRuntimeSnapshot(snapshot);
    }
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final Iterator<T> iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
