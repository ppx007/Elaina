// Video detail runtime contract validates provider metadata, local playback
// bindings, and tracking actions without depending on Flutter widgets.
// Page layout assertions belong in the detail-page widget suite.
import '../../lib/elaina.dart';
import 'danmaku_runtime_contract.dart';

Future<void> main() async {
  await verifyVideoDetailRuntimeContract();
}

Future<void> verifyVideoDetailRuntimeContract() async {
  await _verifyStorageBackedVideoDetailRuntime();

  final DateTime now = DateTime.utc(2026, 1, 3, 9);
  final LocalMediaIdentity firstMedia = LocalMediaIdentity(
    id: const LocalMediaId('detail-check-media-1'),
    uri: Uri.file('/library/detail-check-1.mkv'),
    basename: 'detail-check-1.mkv',
  );
  final LocalMediaIdentity secondMedia = LocalMediaIdentity(
    id: const LocalMediaId('detail-check-media-2'),
    uri: Uri.file('/library/detail-check-2.mkv'),
    basename: 'detail-check-2.mkv',
  );
  const BangumiSubject subject = BangumiSubject(
    id: BangumiSubjectId('detail-check-subject'),
    title: 'Detail Runtime Check',
    summary: 'Smoke contract subject.',
  );
  final DeterministicPlaybackHistoryStore historyStore =
      DeterministicPlaybackHistoryStore();
  await historyStore.record(PlaybackHistoryEntry(
    id: const PlaybackHistoryEntryId('detail-check-history'),
    mediaId: secondMedia.id,
    position: const Duration(minutes: 7),
    duration: const Duration(minutes: 24),
    updatedAt: now,
  ));
  final DeterministicProviderBindingStore bindingStore =
      DeterministicProviderBindingStore();
  await bindingStore.saveAutomaticIfAllowed(ProviderBinding(
    id: const ProviderBindingId('detail-check-auto-binding'),
    localMediaId: firstMedia.id,
    providerId: defaultVideoDetailMetadataProviderId,
    subjectId: const ProviderSubjectId('detail-check-subject'),
    authority: ProviderBindingAuthority.automatic,
    confidence: 0.7,
    createdAt: now,
  ));

  final VideoDetailBootstrap bootstrap = VideoDetailBootstrap(
    metadataProvider: _CheckBangumiProvider(subject),
    bindingStore: bindingStore,
    historyStore: historyStore,
    playbackSourceHandoff: const LocalPlaybackSourceHandoff(),
    invalidationBus: StreamCacheInvalidationBus(),
    localTrackingStore: SettingsBangumiLocalTrackingStore(
      DeterministicSettingsStore(),
    ),
    seeds: <BangumiVideoDetailSeed>[
      BangumiVideoDetailSeed(
        subject: subject,
        localMediaId: firstMedia.id,
        episodes: <BangumiEpisode>[
          const BangumiEpisode(
              id: BangumiEpisodeId('detail-check-episode-2'),
              subjectId: BangumiSubjectId('detail-check-subject'),
              index: 2,
              title: 'Episode 2'),
          const BangumiEpisode(
              id: BangumiEpisodeId('detail-check-episode-1'),
              subjectId: BangumiSubjectId('detail-check-subject'),
              index: 1,
              title: 'Episode 1'),
        ],
        localMediaByEpisodeId: <String, LocalMediaIdentity>{
          'detail-check-episode-1': firstMedia,
          'detail-check-episode-2': secondMedia,
        },
      ),
    ],
    now: () => now,
  );

  final VideoDetailViewData detail =
      await bootstrap.load(const VideoDetailId('detail-check-subject'));
  _expect(
      detail.episodes
              .map((VideoDetailEpisode episode) => episode.index)
              .join(',') ==
          '1,2',
      'Video detail runtime must sort episodes by index.');
  _expect(detail.continueWatching?.mediaId.value == secondMedia.id.value,
      'Video detail runtime must surface latest continue-watching state.');
  _expect(detail.actions.hasValidPrimaryCount,
      'Video detail runtime must enforce primary action limits.');
  _expect(detail.actions.primary.isNotEmpty,
      'Video detail runtime must expose at least one primary action.');
  _expect(detail.binding?.authority == ProviderBindingAuthority.automatic,
      'Video detail runtime must preserve automatic provider binding precedence before follow.');

  final VideoDetailActionResult select = await bootstrap.controller
      .selectEpisode(const VideoDetailId('detail-check-subject'),
          const VideoEpisodeId('detail-check-episode-1'));
  _expect(select.isSuccess,
      'Video detail runtime must route episode selection through playback handoff.');
  final VideoDetailActionResult follow = await bootstrap.controller
      .follow(const VideoDetailId('detail-check-subject'));
  _expect(follow.isSuccess,
      'Video detail runtime must update follow state through binding store.');
  final VideoDetailViewData followed =
      await bootstrap.load(const VideoDetailId('detail-check-subject'));
  _expect(followed.followState == VideoFollowState.followed,
      'Video detail runtime must promote user-confirmed follow state.');

  bootstrap.dispose();
  await verifyBasicDanmakuRuntimeContract();
}

Future<void> _verifyStorageBackedVideoDetailRuntime() async {
  final DateTime now = DateTime.utc(2026, 6, 18, 12);
  final SqliteStorageFoundation storage = SqliteStorageFoundation.inMemory();
  try {
    await storage.mediaLibrary.store(StoredMediaLibraryItemRecord(
      id: 'detail-storage-item-1',
      localMediaId: 'detail-storage-media-1',
      uri: Uri.file('/library/detail-storage-1.mkv'),
      basename: 'detail-storage-1.mkv',
      addedAt: now,
      duration: const Duration(minutes: 24),
    ));
    await storage.mediaLibrary.store(StoredMediaLibraryItemRecord(
      id: 'detail-storage-item-2',
      localMediaId: 'detail-storage-media-2',
      uri: Uri.file('/library/detail-storage-2.mkv'),
      basename: 'detail-storage-2.mkv',
      addedAt: now.add(const Duration(minutes: 1)),
      duration: const Duration(minutes: 24),
    ));
    await storage.playbackHistory.record(StoredPlaybackHistoryRecord(
      id: 'detail-storage-history-2',
      localMediaId: 'detail-storage-media-2',
      position: const Duration(minutes: 11),
      duration: const Duration(minutes: 24),
      updatedAt: now.add(const Duration(minutes: 2)),
    ));
    await storage.providerBinding.saveAutomaticIfAllowed(
      StoredProviderBindingRecord(
        id: 'detail-storage-binding-1',
        localMediaId: 'detail-storage-media-1',
        providerId: defaultVideoDetailMetadataProviderId,
        providerSubjectId: 'detail-storage-subject',
        authority: storageProviderBindingAuthorityAutomatic,
        confidence: 0.7,
        createdAt: now,
      ),
    );
    await storage.providerBinding.saveAutomaticIfAllowed(
      StoredProviderBindingRecord(
        id: 'detail-storage-binding-2',
        localMediaId: 'detail-storage-media-2',
        providerId: defaultVideoDetailMetadataProviderId,
        providerSubjectId: 'detail-storage-subject',
        authority: storageProviderBindingAuthorityAutomatic,
        confidence: 0.8,
        createdAt: now.add(const Duration(minutes: 1)),
      ),
    );

    const BangumiSubject subject = BangumiSubject(
      id: BangumiSubjectId('detail-storage-subject'),
      title: 'Storage Detail Runtime Check',
      summary: 'Storage-backed smoke subject.',
    );
    final VideoDetailBootstrap bootstrap = storageBackedVideoDetailBootstrap(
      storage: storage,
      metadataProvider: _CheckBangumiProvider(subject),
      invalidationBus: StreamCacheInvalidationBus(),
      now: () => now,
    );
    try {
      final VideoDetailViewData detail =
          await bootstrap.load(const VideoDetailId('detail-storage-subject'));
      _expect(
          detail.episodes.length == 2 &&
              detail.episodes.first.localMediaId?.value ==
                  'detail-storage-media-1',
          'Storage-backed video detail runtime must project bound local media episodes.');
      _expect(
          detail.continueWatching?.mediaId.value == 'detail-storage-media-2',
          'Storage-backed video detail runtime must replay latest history.');
      _expect(detail.binding?.authority == ProviderBindingAuthority.automatic,
          'Storage-backed video detail runtime must preserve binding state.');
      final VideoDetailActionResult follow = await bootstrap.controller
          .follow(const VideoDetailId('detail-storage-subject'));
      _expect(follow.isSuccess,
          'Storage-backed video detail runtime must reuse detail action handler.');
    } finally {
      bootstrap.dispose();
    }
  } finally {
    storage.dispose();
  }
}

void _expect(bool condition, String message) {
  if (!condition) throw StateError(message);
}

final class _CheckBangumiProvider implements BangumiProvider {
  const _CheckBangumiProvider(this.subject);

  final BangumiSubject subject;

  @override
  String get id => defaultVideoDetailMetadataProviderId;

  @override
  String get displayName => 'Check Bangumi';

  @override
  ProviderKind get kind => ProviderKind.metadata;

  @override
  ProviderGateway get gateway => throw UnsupportedError(
      'Smoke checker does not expose a provider gateway.');

  @override
  ProviderRegistration get registration => const ProviderRegistration(
        providerId: ProviderId(defaultVideoDetailMetadataProviderId),
        ratePolicy:
            ProviderRatePolicy(maxRequests: 1, window: Duration(seconds: 1)),
        retryPolicy:
            ProviderRetryPolicy(maxAttempts: 1, initialBackoff: Duration.zero),
      );

  @override
  Future<ProviderGatewayResponse<T>> executeGatewayRequest<T>({
    required String cacheKey,
    required Future<T> Function() load,
    ProviderCachePolicy cachePolicy = ProviderCachePolicy.networkOnly,
  }) {
    throw UnsupportedError(
        'Smoke checker does not execute provider gateway requests.');
  }

  @override
  Future<AcgProviderResult<BangumiEpisode>> lookupEpisode(BangumiEpisodeId id) {
    return Future<AcgProviderResult<BangumiEpisode>>.value(
        const AcgProviderFailure<BangumiEpisode>(
            kind: AcgProviderFailureKind.notFound,
            message: 'Episode lookup is outside this smoke check.'));
  }

  @override
  Future<AcgProviderResult<List<BangumiEpisode>>> listEpisodes(
    BangumiSubjectId subjectId,
  ) {
    return Future<AcgProviderResult<List<BangumiEpisode>>>.value(
      AcgProviderSuccess<List<BangumiEpisode>>(
        <BangumiEpisode>[
          BangumiEpisode(
            id: const BangumiEpisodeId('check-episode'),
            subjectId: subjectId,
            index: 1,
            title: 'Episode 1',
          ),
        ],
      ),
    );
  }

  @override
  Future<AcgProviderResult<List<BangumiRelatedPerson>>> listSubjectPersons(
    BangumiSubjectId subjectId,
  ) {
    return Future<AcgProviderResult<List<BangumiRelatedPerson>>>.value(
      const AcgProviderSuccess<List<BangumiRelatedPerson>>(
        <BangumiRelatedPerson>[
          BangumiRelatedPerson(
            id: BangumiPersonId('detail-check-person'),
            name: 'Check Director',
            relation: '导演',
          ),
        ],
      ),
    );
  }

  @override
  Future<AcgProviderResult<List<BangumiRelatedCharacter>>>
      listSubjectCharacters(
    BangumiSubjectId subjectId,
  ) {
    return Future<AcgProviderResult<List<BangumiRelatedCharacter>>>.value(
      const AcgProviderSuccess<List<BangumiRelatedCharacter>>(
        <BangumiRelatedCharacter>[
          BangumiRelatedCharacter(
            id: BangumiCharacterId('detail-check-character'),
            name: 'Check Character',
            relation: '主角',
            actors: <BangumiVoiceActor>[
              BangumiVoiceActor(
                id: BangumiPersonId('detail-check-actor'),
                name: 'Check Actor',
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Future<AcgProviderResult<List<BangumiRelatedSubject>>> listSubjectRelations(
    BangumiSubjectId subjectId,
  ) {
    return Future<AcgProviderResult<List<BangumiRelatedSubject>>>.value(
      const AcgProviderSuccess<List<BangumiRelatedSubject>>(
        <BangumiRelatedSubject>[
          BangumiRelatedSubject(
            id: BangumiSubjectId('detail-check-related'),
            title: 'Check Related Subject',
            relation: '续集',
          ),
        ],
      ),
    );
  }

  @override
  Future<AcgProviderResult<BangumiSubject>> lookupSubject(BangumiSubjectId id) {
    if (id.value != subject.id.value) {
      return Future<AcgProviderResult<BangumiSubject>>.value(
          const AcgProviderFailure<BangumiSubject>(
              kind: AcgProviderFailureKind.notFound,
              message: 'Subject not seeded.'));
    }
    return Future<AcgProviderResult<BangumiSubject>>.value(
        AcgProviderSuccess<BangumiSubject>(subject));
  }

  @override
  ProviderRequestKey requestKey(String cacheKey) => ProviderRequestKey(
      providerId: const ProviderId(defaultVideoDetailMetadataProviderId),
      cacheKey: cacheKey);

  @override
  Future<AcgProviderResult<List<BangumiSubject>>> searchSubjects(String query) {
    return Future<AcgProviderResult<List<BangumiSubject>>>.value(
        AcgProviderSuccess<List<BangumiSubject>>(<BangumiSubject>[subject]));
  }
}
