import '../../foundation/cache_invalidation/cache_invalidation_bus.dart';
import '../../foundation/storage/storage_contracts.dart';
import '../../provider/bangumi/bangumi_provider.dart';
import '../../provider/provider_result.dart';
import '../media/media_library.dart';
import '../media/media_library_storage_adapters.dart';
import '../playback/playback_source_handoff.dart';
import '../profile/bangumi_tracking_domain.dart';
import 'video_detail.dart';
import 'video_detail_bootstrap.dart';
import 'video_detail_runtime.dart';

final class StorageBackedVideoDetailRepository
    implements VideoDetailRepository {
  StorageBackedVideoDetailRepository({
    required BangumiProvider metadataProvider,
    required MediaLibraryCatalogRepository catalogRepository,
    required ProviderBindingStore bindingStore,
    required PlaybackHistoryStore historyStore,
    BangumiTrackingProvider? trackingProvider,
    Iterable<BangumiVideoDetailSeed> seeds = const <BangumiVideoDetailSeed>[],
    String providerId = defaultVideoDetailMetadataProviderId,
    MediaLibraryQuery catalogQuery = const MediaLibraryQuery(),
  })  : assert(providerId != '', 'providerId must not be empty.'),
        _metadataProvider = metadataProvider,
        _catalogRepository = catalogRepository,
        _bindingStore = bindingStore,
        _historyStore = historyStore,
        _trackingProvider = trackingProvider,
        _providerId = providerId,
        _catalogQuery = catalogQuery,
        _seedsBySubjectId = <String, BangumiVideoDetailSeed>{
          for (final BangumiVideoDetailSeed seed in seeds)
            seed.subject.id.value: seed,
        };

  final BangumiProvider _metadataProvider;
  final MediaLibraryCatalogRepository _catalogRepository;
  final ProviderBindingStore _bindingStore;
  final PlaybackHistoryStore _historyStore;
  final BangumiTrackingProvider? _trackingProvider;
  final String _providerId;
  final MediaLibraryQuery _catalogQuery;
  final Map<String, BangumiVideoDetailSeed> _seedsBySubjectId;
  bool _disposed = false;

  bool get isDisposed => _disposed;

  void dispose() {
    _disposed = true;
  }

  @override
  Future<VideoDetailViewData> load(VideoDetailId id) async {
    _checkNotDisposed();
    final BangumiSubject subject = await _lookupSubject(id);
    final BangumiVideoDetailSeed? seed = _seedsBySubjectId[subject.id.value];
    final List<MediaLibraryItem> boundItems =
        await _boundCatalogItemsFor(subject.id.value);
    final ProviderBinding? binding =
        await _strongestBindingFor(subject.id.value, boundItems, seed);
    final VideoTrackingStatus trackingStatus =
        await videoTrackingStatusForSubject(
      subjectId: subject.id.value,
      binding: binding,
      trackingProvider: _trackingProvider,
    );
    final List<VideoDetailEpisode> episodes =
        seed != null && seed.episodes.isNotEmpty
            ? await _episodesFromSeed(seed)
            : await _episodesFromCatalog(boundItems);
    final ContinueWatchingState? latestContinue = _latestContinue(episodes);
    final VideoDetailViewData partial = VideoDetailViewData(
      id: VideoDetailId(subject.id.value),
      title: subject.title,
      coverUri: seed?.coverUri,
      summary: subject.summary,
      episodes: List<VideoDetailEpisode>.unmodifiable(episodes),
      continueWatching: latestContinue,
      followState: videoFollowStateFromBinding(binding),
      trackingStatus: trackingStatus,
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
      trackingStatus: partial.trackingStatus,
      binding: partial.binding,
      actions: deriveVideoDetailActions(partial),
    );
  }

  @override
  Stream<VideoDetailViewData> watch(VideoDetailId id) async* {
    yield await load(id);
  }

  Future<BangumiSubject> _lookupSubject(VideoDetailId id) async {
    final AcgProviderResult<BangumiSubject> result =
        await _metadataProvider.lookupSubject(BangumiSubjectId(id.value));
    return switch (result) {
      AcgProviderSuccess<BangumiSubject>(:final value) => value,
      AcgProviderFailure<BangumiSubject>(:final message) =>
        throw StateError(message),
    };
  }

  Future<List<MediaLibraryItem>> _boundCatalogItemsFor(String subjectId) async {
    final List<MediaLibraryItem> items =
        await _catalogRepository.list(query: _catalogQuery);
    final List<MediaLibraryItem> bound = <MediaLibraryItem>[];
    for (final MediaLibraryItem item in items) {
      final ProviderBinding? binding = await _bindingStore.bindingForProvider(
        mediaId: item.identity.id,
        providerId: _providerId,
      );
      if (binding?.subjectId?.value == subjectId) {
        bound.add(item);
      }
    }
    bound.sort(_compareMediaItems);
    return bound;
  }

  Future<List<VideoDetailEpisode>> _episodesFromSeed(
    BangumiVideoDetailSeed seed,
  ) async {
    final List<BangumiEpisode> sorted = <BangumiEpisode>[...seed.episodes]
      ..sort(
        (BangumiEpisode left, BangumiEpisode right) =>
            left.index.compareTo(right.index),
      );
    final List<VideoDetailEpisode> episodes = <VideoDetailEpisode>[];
    for (final BangumiEpisode episode in sorted) {
      final LocalMediaIdentity? localMedia =
          seed.localMediaByEpisodeId[episode.id.value];
      final ContinueWatchingState? continueWatching =
          localMedia == null ? null : await _continueWatchingFor(localMedia.id);
      episodes.add(
        videoDetailEpisodeFromBangumi(
          episode: episode,
          localMedia: localMedia,
          continueWatching: continueWatching,
        ),
      );
    }
    return episodes;
  }

  Future<List<VideoDetailEpisode>> _episodesFromCatalog(
    List<MediaLibraryItem> items,
  ) async {
    final List<VideoDetailEpisode> episodes = <VideoDetailEpisode>[];
    var index = 1;
    for (final MediaLibraryItem item in items) {
      episodes.add(
        VideoDetailEpisode(
          id: VideoEpisodeId(item.identity.id.value),
          index: index,
          title: item.identity.basename,
          localMedia: item.identity,
          localMediaId: item.identity.id,
          continueWatching: await _continueWatchingFor(item.identity.id),
        ),
      );
      index += 1;
    }
    return episodes;
  }

  Future<ProviderBinding?> _strongestBindingFor(
    String subjectId,
    List<MediaLibraryItem> boundItems,
    BangumiVideoDetailSeed? seed,
  ) async {
    ProviderBinding? strongest;
    for (final LocalMediaId mediaId in _candidateMediaIds(boundItems, seed)) {
      final ProviderBinding? binding = await _bindingStore.bindingForProvider(
        mediaId: mediaId,
        providerId: _providerId,
      );
      if (binding?.subjectId?.value != subjectId) continue;
      if (binding != null &&
          (strongest == null || binding.outranks(strongest))) {
        strongest = binding;
      }
    }
    return strongest;
  }

  List<LocalMediaId> _candidateMediaIds(
    List<MediaLibraryItem> boundItems,
    BangumiVideoDetailSeed? seed,
  ) {
    final Map<String, LocalMediaId> ids = <String, LocalMediaId>{
      for (final MediaLibraryItem item in boundItems)
        item.identity.id.value: item.identity.id,
    };
    final LocalMediaId? detailMediaId = seed?.localMediaId;
    if (detailMediaId != null) ids[detailMediaId.value] = detailMediaId;
    for (final LocalMediaIdentity identity
        in seed?.localMediaByEpisodeId.values ?? const <LocalMediaIdentity>[]) {
      ids[identity.id.value] = identity.id;
    }
    return List<LocalMediaId>.unmodifiable(ids.values);
  }

  Future<ContinueWatchingState?> _continueWatchingFor(
    LocalMediaId mediaId,
  ) async {
    final PlaybackHistoryEntry? entry = await _historyStore.latestFor(mediaId);
    if (entry == null) return null;
    return ContinueWatchingState(
      mediaId: mediaId,
      position: entry.position,
      duration: entry.duration,
      updatedAt: entry.updatedAt,
    );
  }

  ContinueWatchingState? _latestContinue(List<VideoDetailEpisode> episodes) {
    ContinueWatchingState? latest;
    for (final VideoDetailEpisode episode in episodes) {
      final ContinueWatchingState? current = episode.continueWatching;
      if (current != null &&
          (latest == null || current.updatedAt.isAfter(latest.updatedAt))) {
        latest = current;
      }
    }
    return latest;
  }

  void _checkNotDisposed() {
    if (_disposed) {
      throw StateError(
          'Storage-backed video detail repository has been disposed.');
    }
  }

  static int _compareMediaItems(MediaLibraryItem left, MediaLibraryItem right) {
    final int name = left.identity.basename.compareTo(right.identity.basename);
    if (name != 0) return name;
    return left.identity.id.value.compareTo(right.identity.id.value);
  }
}

VideoDetailBootstrap storageBackedVideoDetailBootstrap({
  required StorageFoundation storage,
  required BangumiProvider metadataProvider,
  required CacheInvalidationBus invalidationBus,
  PlaybackSourceHandoffContract playbackSourceHandoff =
      const LocalPlaybackSourceHandoff(),
  BangumiTrackingProvider? trackingProvider,
  Iterable<BangumiVideoDetailSeed> seeds = const <BangumiVideoDetailSeed>[],
  String providerId = defaultVideoDetailMetadataProviderId,
  DateTime Function()? now,
  MediaLibraryQuery catalogQuery = const MediaLibraryQuery(),
}) {
  final StorageMediaLibraryCatalogRepository catalog =
      StorageMediaLibraryCatalogRepository(storage.mediaLibrary);
  final StoragePlaybackHistoryStore history =
      StoragePlaybackHistoryStore(storage.playbackHistory);
  final StorageProviderBindingStore binding =
      StorageProviderBindingStore(storage.providerBinding);
  final StorageBackedVideoDetailRepository repository =
      StorageBackedVideoDetailRepository(
    metadataProvider: metadataProvider,
    catalogRepository: catalog,
    bindingStore: binding,
    historyStore: history,
    trackingProvider: trackingProvider,
    seeds: seeds,
    providerId: providerId,
    catalogQuery: catalogQuery,
  );
  final DeterministicVideoDetailActionHandler actionHandler =
      DeterministicVideoDetailActionHandler(
    repository: repository,
    bindingStore: binding,
    playbackSourceHandoff: playbackSourceHandoff,
    invalidationBus: invalidationBus,
    providerId: providerId,
    now: now,
  );
  return VideoDetailBootstrap.withDependencies(
    repository: repository,
    actionHandler: actionHandler,
    disposeRepository: repository.dispose,
    disposeActionHandler: actionHandler.dispose,
  );
}
