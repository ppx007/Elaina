import '../../foundation/cache_invalidation/cache_invalidation_bus.dart';
import '../../provider/bangumi/bangumi_provider.dart';
import '../../provider/provider_result.dart';
import '../media/media_library.dart';
import '../playback/playback_source_handoff.dart';
import '../profile/bangumi_tracking_domain.dart';
import '../profile/bangumi_tracking_local_store.dart';
import 'video_detail.dart';

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
    this.persons = const <BangumiRelatedPerson>[],
    this.characters = const <BangumiRelatedCharacter>[],
    this.relations = const <BangumiRelatedSubject>[],
  });

  final BangumiSubject subject;
  final List<BangumiEpisode> episodes;
  final Uri? coverUri;
  final LocalMediaId? localMediaId;
  final Map<String, LocalMediaIdentity> localMediaByEpisodeId;
  final List<BangumiRelatedPerson> persons;
  final List<BangumiRelatedCharacter> characters;
  final List<BangumiRelatedSubject> relations;
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

VideoTrackingStatus videoTrackingStatusFromBinding(ProviderBinding? binding) {
  return videoFollowStateFromBinding(binding) == VideoFollowState.followed
      ? VideoTrackingStatus.watching
      : VideoTrackingStatus.notTracked;
}

VideoTrackingStatus videoTrackingStatusFromBangumiTracking(
  BangumiTrackingStatus status,
) {
  return switch (status) {
    BangumiTrackingStatus.planned => VideoTrackingStatus.planned,
    BangumiTrackingStatus.completed => VideoTrackingStatus.completed,
    BangumiTrackingStatus.watching => VideoTrackingStatus.watching,
    BangumiTrackingStatus.onHold => VideoTrackingStatus.onHold,
    BangumiTrackingStatus.dropped => VideoTrackingStatus.dropped,
  };
}

BangumiTrackingStatus bangumiTrackingStatusFromVideoTracking(
  VideoTrackingStatus status,
) {
  return switch (status) {
    VideoTrackingStatus.planned => BangumiTrackingStatus.planned,
    VideoTrackingStatus.completed => BangumiTrackingStatus.completed,
    VideoTrackingStatus.watching => BangumiTrackingStatus.watching,
    VideoTrackingStatus.onHold => BangumiTrackingStatus.onHold,
    VideoTrackingStatus.dropped => BangumiTrackingStatus.dropped,
    VideoTrackingStatus.notTracked =>
      throw ArgumentError('notTracked is not a Bangumi tracking status.'),
  };
}

VideoDetailMetadataStats videoDetailMetadataStatsFromBangumiSubject(
  BangumiSubject subject,
) {
  return VideoDetailMetadataStats(
    rank: subject.rank,
    score: subject.score,
    collectionTotal: subject.collectionTotal,
    episodeCount: subject.episodeCount,
  );
}

VideoDetailCredit videoDetailCreditFromBangumiRelatedPerson(
  BangumiRelatedPerson person,
) {
  return VideoDetailCredit(
    id: person.id.value,
    name: person.name,
    role: person.relation,
    imageUri: person.imageUri,
    careers: person.careers,
    episodeRange: person.episodeRange,
  );
}

VideoDetailVoiceActor videoDetailVoiceActorFromBangumi(
  BangumiVoiceActor actor,
) {
  return VideoDetailVoiceActor(
    id: actor.id.value,
    name: actor.name,
    imageUri: actor.imageUri,
    careers: actor.careers,
  );
}

VideoDetailCharacter videoDetailCharacterFromBangumiRelatedCharacter(
  BangumiRelatedCharacter character,
) {
  return VideoDetailCharacter(
    id: character.id.value,
    name: character.name,
    role: character.relation,
    summary: character.summary,
    imageUri: character.imageUri,
    voiceActors: character.actors
        .map(videoDetailVoiceActorFromBangumi)
        .toList(growable: false),
  );
}

VideoDetailRelatedSubject videoDetailRelatedSubjectFromBangumi(
  BangumiRelatedSubject subject,
) {
  return VideoDetailRelatedSubject(
    id: subject.id.value,
    title: subject.title,
    relation: subject.relation,
    coverUri: subject.coverUri,
    type: subject.type,
  );
}

VideoFollowState videoFollowStateFromTrackingStatus(
  VideoTrackingStatus status,
) {
  return status == VideoTrackingStatus.notTracked
      ? VideoFollowState.notFollowed
      : VideoFollowState.followed;
}

final class VideoTrackingProjection {
  const VideoTrackingProjection({
    required this.status,
    this.conflict,
  });

  final VideoTrackingStatus status;
  final VideoTrackingConflict? conflict;
}

final class VideoDetailMetadataProjection {
  const VideoDetailMetadataProjection({
    required this.credits,
    required this.characters,
    required this.relations,
    required this.failures,
  });

  final List<VideoDetailCredit> credits;
  final List<VideoDetailCharacter> characters;
  final List<VideoDetailRelatedSubject> relations;
  final List<VideoDetailMetadataFailure> failures;
}

final class _MetadataTableResult<T> {
  const _MetadataTableResult({
    required this.data,
    this.failure,
  });

  final T data;
  final VideoDetailMetadataFailure? failure;
}

Future<VideoTrackingProjection> videoTrackingProjectionForSubject({
  required String subjectId,
  required String title,
  required ProviderBinding? binding,
  BangumiTrackingProvider? trackingProvider,
  BangumiLocalTrackingStore? localTrackingStore,
}) async {
  final BangumiLocalTrackingRecord? localTracking =
      await localTrackingStore?.findBySubjectId(subjectId);
  final BangumiTrackingProvider? provider = trackingProvider;
  if (provider == null) {
    return VideoTrackingProjection(
      status: localTracking == null
          ? videoTrackingStatusFromBinding(binding)
          : videoTrackingStatusFromBangumiTracking(localTracking.status),
    );
  }

  final BangumiTrackingSnapshot snapshot =
      await provider.currentAnimeCollection();
  if (snapshot.status != BangumiTrackingLoadStatus.loaded) {
    return VideoTrackingProjection(
      status: localTracking == null
          ? videoTrackingStatusFromBinding(binding)
          : videoTrackingStatusFromBangumiTracking(localTracking.status),
    );
  }

  BangumiTrackingItem? remoteItem;
  for (final BangumiTrackingItem item in snapshot.items) {
    if (item.subjectId == subjectId) {
      remoteItem = item;
      break;
    }
  }
  final VideoTrackingStatus remoteStatus = remoteItem == null
      ? VideoTrackingStatus.notTracked
      : videoTrackingStatusFromBangumiTracking(remoteItem.status);
  if (localTracking == null) {
    return VideoTrackingProjection(status: remoteStatus);
  }

  final VideoTrackingStatus localStatus =
      videoTrackingStatusFromBangumiTracking(localTracking.status);
  return VideoTrackingProjection(
    status: remoteStatus,
    conflict: localStatus == remoteStatus
        ? null
        : VideoTrackingConflict(
            subjectId: subjectId,
            title: remoteItem?.title ?? localTracking.title,
            localStatus: localStatus,
            remoteStatus: remoteStatus,
            localUpdatedAt: localTracking.updatedAt,
            remoteUpdatedAt: remoteItem?.updatedAt,
    ),
  );
}

Future<VideoDetailMetadataProjection> videoDetailMetadataProjectionForSubject({
  required BangumiProvider metadataProvider,
  required BangumiSubjectId subjectId,
  BangumiVideoDetailSeed? seed,
}) async {
  _MetadataTableResult<List<VideoDetailCredit>>? creditsResult;
  _MetadataTableResult<List<VideoDetailCharacter>>? charactersResult;
  _MetadataTableResult<List<VideoDetailRelatedSubject>>? relationsResult;

  await Future.wait<void>(<Future<void>>[
    _creditsForSubject(metadataProvider, subjectId, seed).then(
      (value) => creditsResult = value,
    ),
    _charactersForSubject(metadataProvider, subjectId, seed).then(
      (value) => charactersResult = value,
    ),
    _relationsForSubject(metadataProvider, subjectId, seed).then(
      (value) => relationsResult = value,
    ),
  ]);

  final List<VideoDetailMetadataFailure> failures =
      <VideoDetailMetadataFailure>[];
  final VideoDetailMetadataFailure? creditsFailure = creditsResult?.failure;
  if (creditsFailure != null) failures.add(creditsFailure);
  final VideoDetailMetadataFailure? charactersFailure =
      charactersResult?.failure;
  if (charactersFailure != null) failures.add(charactersFailure);
  final VideoDetailMetadataFailure? relationsFailure = relationsResult?.failure;
  if (relationsFailure != null) failures.add(relationsFailure);

  return VideoDetailMetadataProjection(
    credits: creditsResult?.data ?? const <VideoDetailCredit>[],
    characters: charactersResult?.data ?? const <VideoDetailCharacter>[],
    relations: relationsResult?.data ?? const <VideoDetailRelatedSubject>[],
    failures: List<VideoDetailMetadataFailure>.unmodifiable(failures),
  );
}

Future<_MetadataTableResult<List<VideoDetailCredit>>> _creditsForSubject(
  BangumiProvider metadataProvider,
  BangumiSubjectId subjectId,
  BangumiVideoDetailSeed? seed,
) async {
  if (seed != null && seed.persons.isNotEmpty) {
    return _MetadataTableResult<List<VideoDetailCredit>>(
      data: seed.persons
          .map(videoDetailCreditFromBangumiRelatedPerson)
          .toList(growable: false),
    );
  }
  final AcgProviderResult<List<BangumiRelatedPerson>> result =
      await metadataProvider.listSubjectPersons(subjectId);
  return switch (result) {
    AcgProviderSuccess<List<BangumiRelatedPerson>>(:final value) =>
      _MetadataTableResult<List<VideoDetailCredit>>(
        data: value
            .map(videoDetailCreditFromBangumiRelatedPerson)
            .toList(growable: false),
      ),
    AcgProviderFailure<List<BangumiRelatedPerson>>(:final message) =>
      _MetadataTableResult<List<VideoDetailCredit>>(
        data: const <VideoDetailCredit>[],
        failure: VideoDetailMetadataFailure(
          section: VideoDetailMetadataSection.staff,
          message: message,
        ),
      ),
  };
}

Future<_MetadataTableResult<List<VideoDetailCharacter>>> _charactersForSubject(
  BangumiProvider metadataProvider,
  BangumiSubjectId subjectId,
  BangumiVideoDetailSeed? seed,
) async {
  if (seed != null && seed.characters.isNotEmpty) {
    return _MetadataTableResult<List<VideoDetailCharacter>>(
      data: seed.characters
          .map(videoDetailCharacterFromBangumiRelatedCharacter)
          .toList(growable: false),
    );
  }
  final AcgProviderResult<List<BangumiRelatedCharacter>> result =
      await metadataProvider.listSubjectCharacters(subjectId);
  return switch (result) {
    AcgProviderSuccess<List<BangumiRelatedCharacter>>(:final value) =>
      _MetadataTableResult<List<VideoDetailCharacter>>(
        data: value
            .map(videoDetailCharacterFromBangumiRelatedCharacter)
            .toList(growable: false),
      ),
    AcgProviderFailure<List<BangumiRelatedCharacter>>(:final message) =>
      _MetadataTableResult<List<VideoDetailCharacter>>(
        data: const <VideoDetailCharacter>[],
        failure: VideoDetailMetadataFailure(
          section: VideoDetailMetadataSection.characters,
          message: message,
        ),
      ),
  };
}

Future<_MetadataTableResult<List<VideoDetailRelatedSubject>>>
    _relationsForSubject(
  BangumiProvider metadataProvider,
  BangumiSubjectId subjectId,
  BangumiVideoDetailSeed? seed,
) async {
  if (seed != null && seed.relations.isNotEmpty) {
    return _MetadataTableResult<List<VideoDetailRelatedSubject>>(
      data: seed.relations
          .map(videoDetailRelatedSubjectFromBangumi)
          .toList(growable: false),
    );
  }
  final AcgProviderResult<List<BangumiRelatedSubject>> result =
      await metadataProvider.listSubjectRelations(subjectId);
  return switch (result) {
    AcgProviderSuccess<List<BangumiRelatedSubject>>(:final value) =>
      _MetadataTableResult<List<VideoDetailRelatedSubject>>(
        data: value
            .map(videoDetailRelatedSubjectFromBangumi)
            .toList(growable: false),
      ),
    AcgProviderFailure<List<BangumiRelatedSubject>>(:final message) =>
      _MetadataTableResult<List<VideoDetailRelatedSubject>>(
        data: const <VideoDetailRelatedSubject>[],
        failure: VideoDetailMetadataFailure(
          section: VideoDetailMetadataSection.relations,
          message: message,
        ),
      ),
  };
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
    BangumiTrackingProvider? trackingProvider,
    BangumiLocalTrackingStore? localTrackingStore,
    Iterable<BangumiVideoDetailSeed> seeds = const <BangumiVideoDetailSeed>[],
    String providerId = defaultVideoDetailMetadataProviderId,
  })  : _metadataProvider = metadataProvider,
        _bindingStore = bindingStore,
        _historyStore = historyStore,
        _trackingProvider = trackingProvider,
        _localTrackingStore = localTrackingStore,
        _providerId = providerId,
        _seedsBySubjectId = <String, BangumiVideoDetailSeed>{
          for (final BangumiVideoDetailSeed seed in seeds)
            seed.subject.id.value: seed,
        };

  final BangumiProvider _metadataProvider;
  final ProviderBindingStore _bindingStore;
  final PlaybackHistoryStore _historyStore;
  final BangumiTrackingProvider? _trackingProvider;
  final BangumiLocalTrackingStore? _localTrackingStore;
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
    final List<BangumiEpisode> episodes =
        await _episodesForSubject(subject.id, seed);
    final VideoDetailMetadataProjection metadataProjection =
        await _metadataForSubject(subject.id, seed);
    final ProviderBinding? binding = await _strongestBindingFor(seed);
    final Uri? coverUri = seed?.coverUri ?? subject.coverUri;
    final VideoTrackingProjection trackingProjection =
        await videoTrackingProjectionForSubject(
      subjectId: subject.id.value,
      title: subject.title,
      binding: binding,
      trackingProvider: _trackingProvider,
      localTrackingStore: _localTrackingStore,
    );
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
      coverUri: coverUri,
      summary: subject.summary,
      metadataStats: videoDetailMetadataStatsFromBangumiSubject(subject),
      credits: metadataProjection.credits,
      characters: metadataProjection.characters,
      relations: metadataProjection.relations,
      metadataFailures: metadataProjection.failures,
      episodes: List<VideoDetailEpisode>.unmodifiable(detailEpisodes),
      continueWatching: latestContinue,
      followState: videoFollowStateFromTrackingStatus(
        trackingProjection.status,
      ),
      trackingStatus: trackingProjection.status,
      trackingConflict: trackingProjection.conflict,
      binding: binding,
      actions: const VideoDetailActionSet(actions: <VideoDetailAction>[]),
    );
    return VideoDetailViewData(
      id: partial.id,
      title: partial.title,
      coverUri: partial.coverUri,
      summary: partial.summary,
      metadataStats: partial.metadataStats,
      credits: partial.credits,
      characters: partial.characters,
      relations: partial.relations,
      metadataFailures: partial.metadataFailures,
      episodes: partial.episodes,
      continueWatching: partial.continueWatching,
      followState: partial.followState,
      trackingStatus: partial.trackingStatus,
      trackingConflict: partial.trackingConflict,
      binding: partial.binding,
      actions: deriveVideoDetailActions(partial),
    );
  }

  @override
  Stream<VideoDetailViewData> watch(VideoDetailId id) async* {
    yield await load(id);
  }

  Future<List<BangumiEpisode>> _episodesForSubject(
    BangumiSubjectId subjectId,
    BangumiVideoDetailSeed? seed,
  ) async {
    final List<BangumiEpisode> seededEpisodes = <BangumiEpisode>[
      ...(seed?.episodes ?? const <BangumiEpisode>[])
    ];
    if (seededEpisodes.isNotEmpty) {
      seededEpisodes.sort((BangumiEpisode left, BangumiEpisode right) =>
          left.index.compareTo(right.index));
      return List<BangumiEpisode>.unmodifiable(seededEpisodes);
    }
    final AcgProviderResult<List<BangumiEpisode>> result =
        await _metadataProvider.listEpisodes(subjectId);
    if (result is AcgProviderFailure<List<BangumiEpisode>>) {
      return const <BangumiEpisode>[];
    }
    final List<BangumiEpisode> episodes = <BangumiEpisode>[
      ...(result as AcgProviderSuccess<List<BangumiEpisode>>).value
    ]..sort((BangumiEpisode left, BangumiEpisode right) =>
        left.index.compareTo(right.index));
    return List<BangumiEpisode>.unmodifiable(episodes);
  }

  Future<VideoDetailMetadataProjection> _metadataForSubject(
    BangumiSubjectId subjectId,
    BangumiVideoDetailSeed? seed,
  ) async {
    return videoDetailMetadataProjectionForSubject(
      metadataProvider: _metadataProvider,
      subjectId: subjectId,
      seed: seed,
    );
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
    BangumiLocalTrackingStore? localTrackingStore,
    BangumiTrackingSyncProvider? trackingSyncProvider,
    String providerId = defaultVideoDetailMetadataProviderId,
    DateTime Function()? now,
  })  : _repository = repository,
        _bindingStore = bindingStore,
        _playbackSourceHandoff = playbackSourceHandoff,
        _invalidationBus = invalidationBus,
        _localTrackingStore = localTrackingStore,
        _trackingSyncProvider = trackingSyncProvider,
        _providerId = providerId,
        _now = now;

  final VideoDetailRepository _repository;
  final ProviderBindingStore _bindingStore;
  final PlaybackSourceHandoffContract _playbackSourceHandoff;
  final CacheInvalidationBus _invalidationBus;
  final BangumiLocalTrackingStore? _localTrackingStore;
  final BangumiTrackingSyncProvider? _trackingSyncProvider;
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
      VideoDetailActionKind.setTrackingStatus => action.trackingStatus == null
          ? Future<VideoDetailActionResult>.value(
              VideoDetailActionResult.unsupported(
                  'Tracking status action is missing a target status.'))
          : setTrackingStatus(id, action.trackingStatus!),
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
    return setTrackingStatus(id, VideoTrackingStatus.watching);
  }

  @override
  Future<VideoDetailActionResult> setTrackingStatus(
    VideoDetailId id,
    VideoTrackingStatus status,
  ) async {
    if (status == VideoTrackingStatus.notTracked) {
      return VideoDetailActionResult.unsupported(
        'notTracked 不是可用的详情页操作。',
      );
    }
    return _withLoadedData(id, (VideoDetailViewData data) async {
      final BangumiTrackingSyncProvider? syncProvider = _trackingSyncProvider;
      if (syncProvider == null) {
        return _saveLocalFallbackTracking(data, status);
      }

      final BangumiTrackingSyncResult syncResult =
          await syncProvider.syncTrackingStatus(
        subjectId: data.id.value,
        status: bangumiTrackingStatusFromVideoTracking(status),
      );
      if (syncResult.kind == BangumiTrackingSyncResultKind.success) {
        await _saveLocalTracking(
          data: data,
          status: status,
          syncState: BangumiLocalTrackingSyncState.synced,
        );
        await _confirmBindingForTrackedLocalMedia(data, status);
        return const VideoDetailActionResult.success();
      }
      if (syncResult.kind == BangumiTrackingSyncResultKind.unauthenticated) {
        return _saveLocalFallbackTracking(data, status);
      }
      return VideoDetailActionResult.failed(
        syncResult.message ?? 'Bangumi 追番状态同步失败。',
      );
    });
  }

  @override
  Future<VideoDetailActionResult> resolveTrackingConflict(
    VideoDetailId id,
    VideoTrackingConflictResolution resolution,
  ) async {
    return _withLoadedData(id, (VideoDetailViewData data) async {
      final VideoTrackingConflict? conflict = data.trackingConflict;
      if (conflict == null) {
        return VideoDetailActionResult.ignored('当前没有追番状态冲突。');
      }
      return switch (resolution) {
        VideoTrackingConflictResolution.localToRemote =>
          _syncConflictLocalToRemote(data, conflict),
        VideoTrackingConflictResolution.remoteToLocal =>
          _syncConflictRemoteToLocal(data, conflict),
      };
    });
  }

  Future<VideoDetailActionResult> _syncConflictLocalToRemote(
    VideoDetailViewData data,
    VideoTrackingConflict conflict,
  ) async {
    final BangumiTrackingSyncProvider? syncProvider = _trackingSyncProvider;
    if (syncProvider == null) {
      return VideoDetailActionResult.unavailable('Bangumi 追番同步不可用。');
    }
    final BangumiTrackingSyncResult syncResult =
        await syncProvider.syncTrackingStatus(
      subjectId: conflict.subjectId,
      status: bangumiTrackingStatusFromVideoTracking(conflict.localStatus),
    );
    if (syncResult.kind == BangumiTrackingSyncResultKind.success) {
      await _saveLocalTracking(
        data: data,
        status: conflict.localStatus,
        syncState: BangumiLocalTrackingSyncState.synced,
      );
      await _confirmBindingForTrackedLocalMedia(data, conflict.localStatus);
      return const VideoDetailActionResult.success();
    }
    if (syncResult.kind == BangumiTrackingSyncResultKind.unauthenticated) {
      return VideoDetailActionResult.unavailable(
        syncResult.message ?? '需要登录 Bangumi 后才能同步到云端。',
      );
    }
    return VideoDetailActionResult.failed(
      syncResult.message ?? 'Bangumi 追番状态同步失败。',
    );
  }

  Future<VideoDetailActionResult> _syncConflictRemoteToLocal(
    VideoDetailViewData data,
    VideoTrackingConflict conflict,
  ) async {
    final BangumiLocalTrackingStore? localTrackingStore = _localTrackingStore;
    if (localTrackingStore == null) {
      return VideoDetailActionResult.unavailable('本地追番备用存储不可用。');
    }
    if (conflict.remoteStatus == VideoTrackingStatus.notTracked) {
      await localTrackingStore.remove(conflict.subjectId);
      await _downgradeBindingIfPresent(data);
      return const VideoDetailActionResult.success();
    }
    await _saveLocalTracking(
      data: data,
      status: conflict.remoteStatus,
      syncState: BangumiLocalTrackingSyncState.synced,
    );
    await _confirmBindingForTrackedLocalMedia(data, conflict.remoteStatus);
    return const VideoDetailActionResult.success();
  }

  Future<VideoDetailActionResult> _saveLocalFallbackTracking(
    VideoDetailViewData data,
    VideoTrackingStatus status,
  ) async {
    final BangumiLocalTrackingStore? localTrackingStore = _localTrackingStore;
    if (localTrackingStore == null) {
      return VideoDetailActionResult.unavailable(
        '追番状态变更需要 Bangumi 同步或本地备用存储。',
      );
    }
    await _saveLocalTracking(
      data: data,
      status: status,
      syncState: BangumiLocalTrackingSyncState.pending,
    );
    await _confirmBindingForTrackedLocalMedia(data, status);
    return const VideoDetailActionResult.success();
  }

  Future<void> _saveLocalTracking({
    required VideoDetailViewData data,
    required VideoTrackingStatus status,
    required BangumiLocalTrackingSyncState syncState,
  }) async {
    final BangumiLocalTrackingStore? localTrackingStore = _localTrackingStore;
    if (localTrackingStore == null) return;
    await localTrackingStore.save(
      BangumiLocalTrackingRecord(
        subjectId: data.id.value,
        title: data.title,
        status: bangumiTrackingStatusFromVideoTracking(status),
        coverUri: data.coverUri,
        updatedAt: (_now ?? DateTime.now)(),
        syncState: syncState,
      ),
    );
  }

  Future<void> _confirmBindingForTrackedLocalMedia(
    VideoDetailViewData data,
    VideoTrackingStatus status,
  ) async {
    if (status != VideoTrackingStatus.watching) return;
    if (_primaryMediaId(data) == null) return;
    await _saveBindingIfMediaAvailable(data);
  }

  Future<VideoDetailActionResult> _saveBindingIfMediaAvailable(
      VideoDetailViewData data) async {
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
  }

  Future<VideoDetailActionResult> _downgradeBindingIfPresent(
      VideoDetailViewData data) async {
    final ProviderBinding? binding = data.binding;
    if (binding == null) {
      return const VideoDetailActionResult.success();
    }
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
    BangumiTrackingProvider? trackingProvider,
    BangumiLocalTrackingStore? localTrackingStore,
    BangumiTrackingSyncProvider? trackingSyncProvider,
    Iterable<BangumiVideoDetailSeed> seeds = const <BangumiVideoDetailSeed>[],
    String providerId = defaultVideoDetailMetadataProviderId,
    DateTime Function()? now,
  }) {
    final DeterministicVideoDetailRepository repository =
        DeterministicVideoDetailRepository(
      metadataProvider: metadataProvider,
      bindingStore: bindingStore,
      historyStore: historyStore,
      trackingProvider: trackingProvider,
      localTrackingStore: localTrackingStore,
      seeds: seeds,
      providerId: providerId,
    );
    final DeterministicVideoDetailActionHandler actionHandler =
        DeterministicVideoDetailActionHandler(
      repository: repository,
      bindingStore: bindingStore,
      playbackSourceHandoff: playbackSourceHandoff,
      invalidationBus: invalidationBus,
      localTrackingStore: localTrackingStore,
      trackingSyncProvider: trackingSyncProvider,
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
