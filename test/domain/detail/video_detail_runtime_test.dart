import 'dart:io';

import 'package:elaina/elaina.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/provider_test_fakes.dart';
import '../../support/runtime_test_fakes.dart';

// Contract-level coverage for VideoDetailRuntime.
//
// These tests intentionally exercise domain projections, tracking conflict
// rules, and playback handoff without depending on the widget layout.
void main() {
  test('runtime assembles ordered metadata continue state binding and actions',
      () async {
    final DateTime older = DateTime.utc(2026, 1, 1, 10);
    final DateTime newer = DateTime.utc(2026, 1, 1, 11);
    final LocalMediaIdentity firstMedia = _media('media-1', 'Episode 1.mkv');
    final LocalMediaIdentity secondMedia = _media('media-2', 'Episode 2.mkv');
    final DeterministicPlaybackHistoryStore historyStore =
        DeterministicPlaybackHistoryStore();
    await historyStore.record(PlaybackHistoryEntry(
      id: const PlaybackHistoryEntryId('history-1'),
      mediaId: firstMedia.id,
      position: const Duration(minutes: 3),
      duration: const Duration(minutes: 24),
      updatedAt: older,
    ));
    await historyStore.record(PlaybackHistoryEntry(
      id: const PlaybackHistoryEntryId('history-2'),
      mediaId: secondMedia.id,
      position: const Duration(minutes: 8),
      duration: const Duration(minutes: 24),
      updatedAt: newer,
    ));

    final DeterministicProviderBindingStore bindingStore =
        DeterministicProviderBindingStore();
    await bindingStore.saveUserConfirmed(ProviderBinding(
      id: const ProviderBindingId('binding-2'),
      localMediaId: secondMedia.id,
      providerId: defaultVideoDetailMetadataProviderId,
      subjectId: const ProviderSubjectId('subject-1'),
      authority: ProviderBindingAuthority.userConfirmed,
      confidence: 1,
      createdAt: older,
    ));

    final VideoDetailRuntime runtime = _runtime(
      bindingStore: bindingStore,
      historyStore: historyStore,
      subject: _subject(),
      seed: BangumiVideoDetailSeed(
        subject: _subject(),
        localMediaId: secondMedia.id,
        coverUri: Uri.parse('https://metadata.example/cover.jpg'),
        episodes: <BangumiEpisode>[
          _episode('episode-2', 2),
          _episode('episode-1', 1)
        ],
        localMediaByEpisodeId: <String, LocalMediaIdentity>{
          'episode-1': firstMedia,
          'episode-2': secondMedia,
        },
      ),
    );

    final _RuntimeObserver observer = _RuntimeObserver();
    runtime.addObserver(observer);
    final VideoDetailViewData detail =
        await runtime.load(const VideoDetailId('subject-1'));
    final VideoDetailViewData watched =
        await runtime.controller.watch(const VideoDetailId('subject-1')).first;

    expect(detail.title, 'Subject Title');
    expect(detail.coverUri.toString(), 'https://metadata.example/cover.jpg');
    expect(detail.episodes.map((VideoDetailEpisode episode) => episode.index),
        <int>[1, 2]);
    expect(detail.episodes.first.localMedia, firstMedia);
    expect(detail.continueWatching?.mediaId.value, 'media-2');
    expect(detail.continueWatching?.position, const Duration(minutes: 8));
    expect(detail.followState, VideoFollowState.followed);
    expect(detail.binding?.id.value, 'binding-2');
    expect(detail.actions.hasValidPrimaryCount, isTrue);
    expect(detail.actions.primary.single.kind,
        VideoDetailActionKind.continuePlayback);
    expect(
        detail.actions.secondary.map((VideoDetailAction action) => action.kind),
        contains(VideoDetailActionKind.refreshMetadata));
    expect(watched.title, detail.title);
    expect(runtime.currentSnapshot.status, VideoDetailRuntimeStatus.ready);
    expect(observer.snapshots.single.activeDetail?.id.value, 'subject-1');

    runtime.dispose();
  });

  test('runtime loads remote Bangumi detail and episodes without local seed',
      () async {
    final BangumiSubject subject = BangumiSubject(
      id: const BangumiSubjectId('subject-remote'),
      title: 'Remote Subject',
      summary: 'Remote summary',
      coverUri: Uri.parse('https://metadata.example/remote-cover.jpg'),
    );
    final VideoDetailRuntime runtime = _runtime(
      subject: subject,
      episodesBySubjectId: <String, List<BangumiEpisode>>{
        'subject-remote': <BangumiEpisode>[
          const BangumiEpisode(
            id: BangumiEpisodeId('remote-episode-2'),
            subjectId: BangumiSubjectId('subject-remote'),
            index: 2,
            title: 'Remote Episode 2',
          ),
          const BangumiEpisode(
            id: BangumiEpisodeId('remote-episode-1'),
            subjectId: BangumiSubjectId('subject-remote'),
            index: 1,
            title: 'Remote Episode 1',
          ),
        ],
      },
    );

    final VideoDetailViewData detail =
        await runtime.load(const VideoDetailId('subject-remote'));

    expect(detail.title, 'Remote Subject');
    expect(detail.summary, 'Remote summary');
    expect(
      detail.coverUri,
      Uri.parse('https://metadata.example/remote-cover.jpg'),
    );
    expect(
      detail.episodes.map((VideoDetailEpisode episode) => episode.title),
      <String>['Remote Episode 1', 'Remote Episode 2'],
    );
    expect(detail.followState, VideoFollowState.notFollowed);
    expect(
      detail.actions.primary.single.kind,
      VideoDetailActionKind.selectEpisode,
    );

    runtime.dispose();
  });

  test('runtime projects Bangumi stats credits characters and relations',
      () async {
    const BangumiSubjectId subjectId = BangumiSubjectId('subject-rich');
    final BangumiSubject subject = BangumiSubject(
      id: subjectId,
      title: 'Rich Subject',
      summary: 'Rich summary',
      coverUri: Uri.parse('https://metadata.example/rich-cover.jpg'),
      rank: 12,
      score: 8.7,
      collectionTotal: 34567,
      episodeCount: 13,
    );
    final VideoDetailRuntime runtime = _runtime(
      subject: subject,
      personsBySubjectId: <String, List<BangumiRelatedPerson>>{
        subjectId.value: <BangumiRelatedPerson>[
          BangumiRelatedPerson(
            id: const BangumiPersonId('person-1'),
            name: 'Series Director',
            relation: '导演',
            imageUri: Uri.parse('https://metadata.example/person.jpg'),
            careers: const <String>['director'],
            episodeRange: '1-13',
          ),
        ],
      },
      charactersBySubjectId: <String, List<BangumiRelatedCharacter>>{
        subjectId.value: <BangumiRelatedCharacter>[
          BangumiRelatedCharacter(
            id: const BangumiCharacterId('character-1'),
            name: 'Lead Character',
            relation: '主角',
            summary: 'Lead summary',
            imageUri: Uri.parse('https://metadata.example/character.jpg'),
            actors: <BangumiVoiceActor>[
              BangumiVoiceActor(
                id: const BangumiPersonId('actor-1'),
                name: 'Lead Voice',
                imageUri: Uri.parse('https://metadata.example/actor.jpg'),
                careers: const <String>['seiyu'],
              ),
            ],
          ),
        ],
      },
      relationsBySubjectId: <String, List<BangumiRelatedSubject>>{
        subjectId.value: <BangumiRelatedSubject>[
          BangumiRelatedSubject(
            id: const BangumiSubjectId('subject-related'),
            title: 'Rich Related',
            relation: '续集',
            coverUri: Uri.parse('https://metadata.example/related.jpg'),
            type: bangumiAnimeSubjectType,
          ),
        ],
      },
    );

    final VideoDetailViewData detail =
        await runtime.load(const VideoDetailId('subject-rich'));

    expect(detail.metadataStats.score, 8.7);
    expect(detail.metadataStats.rank, 12);
    expect(detail.metadataStats.collectionTotal, 34567);
    expect(detail.metadataStats.episodeCount, 13);
    expect(
        detail.coverUri, Uri.parse('https://metadata.example/rich-cover.jpg'));
    expect(detail.credits.single.name, 'Series Director');
    expect(detail.credits.single.role, '导演');
    expect(detail.credits.single.careers, <String>['director']);
    expect(detail.characters.single.name, 'Lead Character');
    expect(detail.characters.single.voiceActors.single.name, 'Lead Voice');
    expect(
        detail.characters.single.voiceActors.single.careers, <String>['seiyu']);
    expect(detail.relations.single.title, 'Rich Related');
    expect(detail.relations.single.relation, '续集');
    expect(detail.metadataFailures, isEmpty);

    runtime.dispose();
  });

  test('runtime isolates optional Bangumi metadata table failures', () async {
    final BangumiSubject subject = BangumiSubject(
      id: const BangumiSubjectId('subject-partial'),
      title: 'Partial Subject',
      summary: 'Partial summary',
      coverUri: Uri.parse('https://metadata.example/partial-cover.jpg'),
    );
    final VideoDetailRuntime runtime = _runtime(
      subject: subject,
      personsBySubjectId: const <String, List<BangumiRelatedPerson>>{
        'subject-partial': <BangumiRelatedPerson>[
          BangumiRelatedPerson(
            id: BangumiPersonId('person-partial'),
            name: 'Partial Director',
            relation: '导演',
          ),
        ],
      },
      failCharacters: true,
    );

    final VideoDetailViewData detail =
        await runtime.load(const VideoDetailId('subject-partial'));

    expect(detail.title, 'Partial Subject');
    expect(detail.credits.single.name, 'Partial Director');
    expect(detail.characters, isEmpty);
    expect(detail.relations, isEmpty);
    expect(detail.metadataFailures, hasLength(1));
    expect(
      detail.metadataFailures.single.section,
      VideoDetailMetadataSection.characters,
    );
    expect(detail.metadataFailures.single.message, 'Characters failed.');

    runtime.dispose();
  });

  test('runtime consumes remote Bangumi tracking status for detail state',
      () async {
    final BangumiSubject subject = BangumiSubject(
      id: const BangumiSubjectId('subject-tracked'),
      title: 'Tracked Subject',
      summary: 'Remote summary',
      coverUri: Uri.parse('https://metadata.example/tracked-cover.jpg'),
    );
    final VideoDetailRuntime runtime = _runtime(
      subject: subject,
      trackingProvider: FakeBangumiTrackingProvider(
        BangumiTrackingSnapshot.loaded(
          const <BangumiTrackingItem>[
            BangumiTrackingItem(
              subjectId: 'subject-tracked',
              title: 'Tracked Subject',
              status: BangumiTrackingStatus.watching,
              watchedEpisodes: 3,
              totalEpisodes: 12,
            ),
          ],
        ),
      ),
    );

    final VideoDetailViewData detail =
        await runtime.load(const VideoDetailId('subject-tracked'));

    expect(detail.followState, VideoFollowState.followed);
    expect(detail.trackingStatus, VideoTrackingStatus.watching);
    expect(
      detail.actions.actions.map((VideoDetailAction action) => action.kind),
      isNot(contains(VideoDetailActionKind.follow)),
    );

    runtime.dispose();
  });

  test('tracking actions persist remote-only detail locally while offline',
      () async {
    final DateTime now = DateTime.utc(2026, 6, 21, 10);
    final SettingsBangumiLocalTrackingStore localTrackingStore =
        SettingsBangumiLocalTrackingStore(DeterministicSettingsStore());
    final BangumiSubject subject = BangumiSubject(
      id: const BangumiSubjectId('subject-offline'),
      title: 'Offline Subject',
      summary: 'Remote-only summary',
      coverUri: Uri.parse('https://metadata.example/offline-cover.jpg'),
    );
    final VideoDetailRuntime runtime = _runtime(
      subject: subject,
      localTrackingStore: localTrackingStore,
      trackingProvider: CloudFirstBangumiTrackingProvider(
        localStore: localTrackingStore,
        remoteProvider: const FakeBangumiTrackingProvider(
          BangumiTrackingSnapshot.unauthenticated('missing token'),
        ),
      ),
      now: () => now,
    );

    final VideoDetailActionResult result = await runtime.controller
        .setTrackingStatus(const VideoDetailId('subject-offline'),
            VideoTrackingStatus.dropped);
    final VideoDetailViewData detail =
        await runtime.load(const VideoDetailId('subject-offline'));
    final BangumiLocalTrackingRecord? record =
        await localTrackingStore.findBySubjectId('subject-offline');

    expect(result.isSuccess, isTrue);
    expect(detail.trackingStatus, VideoTrackingStatus.dropped);
    expect(detail.followState, VideoFollowState.followed);
    expect(record?.status, BangumiTrackingStatus.dropped);
    expect(record?.syncState, BangumiLocalTrackingSyncState.pending);
    expect(record?.coverUri,
        Uri.parse('https://metadata.example/offline-cover.jpg'));

    runtime.dispose();
  });

  test('remote tracking is primary and exposes local conflict details',
      () async {
    final SettingsBangumiLocalTrackingStore localTrackingStore =
        SettingsBangumiLocalTrackingStore(DeterministicSettingsStore());
    await localTrackingStore.save(BangumiLocalTrackingRecord(
      subjectId: 'subject-conflict',
      title: 'Local Conflict Subject',
      status: BangumiTrackingStatus.dropped,
      updatedAt: DateTime.utc(2026, 6, 21, 9),
      syncState: BangumiLocalTrackingSyncState.pending,
    ));
    final BangumiSubject subject = BangumiSubject(
      id: const BangumiSubjectId('subject-conflict'),
      title: 'Remote Conflict Subject',
      summary: 'Remote summary',
      coverUri: Uri.parse('https://metadata.example/conflict-cover.jpg'),
    );
    final VideoDetailRuntime runtime = _runtime(
      subject: subject,
      localTrackingStore: localTrackingStore,
      trackingProvider: FakeBangumiTrackingProvider(
        BangumiTrackingSnapshot.loaded(
          <BangumiTrackingItem>[
            BangumiTrackingItem(
              subjectId: 'subject-conflict',
              title: 'Remote Conflict Subject',
              status: BangumiTrackingStatus.watching,
              watchedEpisodes: 4,
              totalEpisodes: 12,
              updatedAt: DateTime.utc(2026, 6, 21, 12),
            ),
          ],
        ),
      ),
    );

    final VideoDetailViewData detail =
        await runtime.load(const VideoDetailId('subject-conflict'));

    expect(detail.trackingStatus, VideoTrackingStatus.watching);
    expect(detail.followState, VideoFollowState.followed);
    expect(detail.trackingConflict?.localStatus, VideoTrackingStatus.dropped);
    expect(detail.trackingConflict?.remoteStatus, VideoTrackingStatus.watching);
    expect(
      detail.trackingConflict?.remoteUpdatedAt,
      DateTime.utc(2026, 6, 21, 12),
    );

    runtime.dispose();
  });

  test('tracking conflict resolution syncs the selected source', () async {
    final SettingsBangumiLocalTrackingStore localToRemoteStore =
        SettingsBangumiLocalTrackingStore(DeterministicSettingsStore());
    await localToRemoteStore.save(BangumiLocalTrackingRecord(
      subjectId: 'subject-conflict',
      title: 'Local Conflict Subject',
      status: BangumiTrackingStatus.dropped,
      updatedAt: DateTime.utc(2026, 6, 21, 9),
      syncState: BangumiLocalTrackingSyncState.pending,
    ));
    final RecordingBangumiTrackingSyncProvider syncProvider =
        RecordingBangumiTrackingSyncProvider();
    final BangumiSubject subject = BangumiSubject(
      id: const BangumiSubjectId('subject-conflict'),
      title: 'Remote Conflict Subject',
      summary: 'Remote summary',
      coverUri: Uri.parse('https://metadata.example/conflict-cover.jpg'),
    );
    final BangumiTrackingProvider remoteWatching = FakeBangumiTrackingProvider(
      BangumiTrackingSnapshot.loaded(
        <BangumiTrackingItem>[
          BangumiTrackingItem(
            subjectId: 'subject-conflict',
            title: 'Remote Conflict Subject',
            status: BangumiTrackingStatus.watching,
            watchedEpisodes: 4,
            totalEpisodes: 12,
            updatedAt: DateTime.utc(2026, 6, 21, 12),
          ),
        ],
      ),
    );
    final VideoDetailRuntime localToRemoteRuntime = _runtime(
      subject: subject,
      localTrackingStore: localToRemoteStore,
      trackingProvider: remoteWatching,
      trackingSyncProvider: syncProvider,
    );

    final VideoDetailActionResult localToRemoteResult =
        await localToRemoteRuntime.controller.resolveTrackingConflict(
      const VideoDetailId('subject-conflict'),
      VideoTrackingConflictResolution.localToRemote,
    );

    expect(localToRemoteResult.isSuccess, isTrue);
    expect(syncProvider.calls, <String>['subject-conflict:dropped']);
    expect(
      (await localToRemoteStore.findBySubjectId('subject-conflict'))?.syncState,
      BangumiLocalTrackingSyncState.synced,
    );
    localToRemoteRuntime.dispose();

    final SettingsBangumiLocalTrackingStore remoteToLocalStore =
        SettingsBangumiLocalTrackingStore(DeterministicSettingsStore());
    await remoteToLocalStore.save(BangumiLocalTrackingRecord(
      subjectId: 'subject-conflict',
      title: 'Local Conflict Subject',
      status: BangumiTrackingStatus.dropped,
      updatedAt: DateTime.utc(2026, 6, 21, 9),
      syncState: BangumiLocalTrackingSyncState.pending,
    ));
    final VideoDetailRuntime remoteToLocalRuntime = _runtime(
      subject: subject,
      localTrackingStore: remoteToLocalStore,
      trackingProvider: remoteWatching,
    );

    final VideoDetailActionResult remoteToLocalResult =
        await remoteToLocalRuntime.controller.resolveTrackingConflict(
      const VideoDetailId('subject-conflict'),
      VideoTrackingConflictResolution.remoteToLocal,
    );
    final BangumiLocalTrackingRecord? remoteToLocalRecord =
        await remoteToLocalStore.findBySubjectId('subject-conflict');

    expect(remoteToLocalResult.isSuccess, isTrue);
    expect(remoteToLocalRecord?.status, BangumiTrackingStatus.watching);
    expect(
        remoteToLocalRecord?.syncState, BangumiLocalTrackingSyncState.synced);
    remoteToLocalRuntime.dispose();
  });

  test('actions route playback through handoff and publish invalidation events',
      () async {
    final DateTime now = DateTime.utc(2026, 1, 2, 12);
    final LocalMediaIdentity firstMedia =
        _media('media-action-1', 'Action 1.mkv');
    final LocalMediaIdentity secondMedia =
        _media('media-action-2', 'Action 2.mkv');
    final DeterministicPlaybackHistoryStore historyStore =
        DeterministicPlaybackHistoryStore();
    await historyStore.record(PlaybackHistoryEntry(
      id: const PlaybackHistoryEntryId('history-action'),
      mediaId: secondMedia.id,
      position: const Duration(minutes: 5),
      duration: const Duration(minutes: 24),
      updatedAt: now,
    ));
    final DeterministicProviderBindingStore bindingStore =
        DeterministicProviderBindingStore();
    final RecordingCacheInvalidationBus invalidationBus =
        RecordingCacheInvalidationBus();
    final RecordingPlaybackSourceHandoff handoff =
        RecordingPlaybackSourceHandoff();
    final RecordingBangumiTrackingSyncProvider syncProvider =
        RecordingBangumiTrackingSyncProvider();
    final VideoDetailRuntime runtime = _runtime(
      bindingStore: bindingStore,
      historyStore: historyStore,
      invalidationBus: invalidationBus,
      handoff: handoff,
      trackingSyncProvider: syncProvider,
      now: () => now,
      subject: _subject(),
      seed: BangumiVideoDetailSeed(
        subject: _subject(),
        localMediaId: firstMedia.id,
        episodes: <BangumiEpisode>[
          _episode('episode-1', 1),
          _episode('episode-2', 2)
        ],
        localMediaByEpisodeId: <String, LocalMediaIdentity>{
          'episode-1': firstMedia,
          'episode-2': secondMedia,
        },
      ),
    );

    final VideoDetailActionResult continueResult = await runtime.controller
        .continuePlayback(const VideoDetailId('subject-1'));
    final VideoDetailActionResult selectResult = await runtime.controller
        .selectEpisode(const VideoDetailId('subject-1'),
            const VideoEpisodeId('episode-1'));
    final VideoDetailActionResult followResult =
        await runtime.controller.follow(const VideoDetailId('subject-1'));
    final VideoDetailActionResult refreshResult =
        await runtime.controller.perform(
      const VideoDetailId('subject-1'),
      const VideoDetailAction(
          kind: VideoDetailActionKind.refreshMetadata, label: 'Refresh'),
    );
    final VideoDetailViewData followed =
        await runtime.load(const VideoDetailId('subject-1'));

    expect(continueResult.isSuccess, isTrue);
    expect(selectResult.isSuccess, isTrue);
    expect(followResult.isSuccess, isTrue);
    expect(refreshResult.isSuccess, isTrue);
    expect(syncProvider.calls, <String>['subject-1:watching']);
    expect(
        handoff.inputs.map(
            (LocalMediaIdentity identity) => identity.uri.pathSegments.last),
        <String>['Action 2.mkv', 'Action 1.mkv']);
    expect(invalidationBus.publishedEvents.whereType<HistoryRecorded>(),
        hasLength(2));
    expect(invalidationBus.publishedEvents.whereType<BindingChanged>(),
        hasLength(2));
    expect(followed.followState, VideoFollowState.followed);

    runtime.dispose();
    final VideoDetailActionResult disposed =
        await runtime.controller.follow(const VideoDetailId('subject-1'));
    expect(disposed.kind, VideoDetailActionResultKind.unavailable);
  });

  test('actions normalize missing media and unsupported handoff outcomes',
      () async {
    final VideoDetailRuntime missingMediaRuntime = _runtime(
      subject: _subject(),
      seed: BangumiVideoDetailSeed(
          subject: _subject(),
          episodes: <BangumiEpisode>[_episode('episode-1', 1)]),
    );
    final VideoDetailActionResult missingMedia =
        await missingMediaRuntime.controller.selectEpisode(
            const VideoDetailId('subject-1'),
            const VideoEpisodeId('episode-1'));
    expect(missingMedia.kind, VideoDetailActionResultKind.unavailable);

    final LocalMediaIdentity remoteMedia = LocalMediaIdentity(
      id: const LocalMediaId('remote-media'),
      uri: Uri.parse('https://media.example/remote.mkv'),
      basename: 'remote.mkv',
    );
    final VideoDetailRuntime unsupportedRuntime = _runtime(
      subject: _subject(),
      seed: BangumiVideoDetailSeed(
        subject: _subject(),
        episodes: <BangumiEpisode>[_episode('episode-1', 1)],
        localMediaByEpisodeId: <String, LocalMediaIdentity>{
          'episode-1': remoteMedia
        },
      ),
    );
    final VideoDetailActionResult unsupported =
        await unsupportedRuntime.controller.selectEpisode(
            const VideoDetailId('subject-1'),
            const VideoEpisodeId('episode-1'));
    expect(unsupported.kind, VideoDetailActionResultKind.unsupported);
    expect(unsupported.failure?.message, contains('Only file URI'));

    missingMediaRuntime.dispose();
    unsupportedRuntime.dispose();
  });

  test('actions return typed failure when detail data cannot load', () async {
    final VideoDetailRuntime runtime = VideoDetailRuntime(
      metadataProvider: FakeBangumiProvider(
        subjectsById: const <String, BangumiSubject>{},
        providerId: defaultVideoDetailMetadataProviderId,
      ),
      bindingStore: DeterministicProviderBindingStore(),
      historyStore: DeterministicPlaybackHistoryStore(),
      playbackSourceHandoff: const LocalPlaybackSourceHandoff(),
      invalidationBus: RecordingCacheInvalidationBus(),
    );

    final VideoDetailActionResult result =
        await runtime.controller.follow(const VideoDetailId('missing-subject'));

    expect(result.kind, VideoDetailActionResultKind.failed);
    expect(result.failure?.message, 'Missing subject.');

    runtime.dispose();
  });

  test('storage-backed detail runtime replays catalog history and bindings',
      () async {
    final File databaseFile = await _tempDatabaseFile();
    addTearDown(() async {
      if (databaseFile.parent.existsSync()) {
        await databaseFile.parent.delete(recursive: true);
      }
    });
    final DateTime now = DateTime.utc(2026, 6, 18, 10);
    final SqliteStorageFoundation first =
        SqliteStorageFoundation.open(databaseFile.path);
    await first.mediaLibrary.store(_storedMedia(
      id: 'item-storage-1',
      localMediaId: 'detail-storage-1',
      basename: 'Storage Episode 1.mkv',
      addedAt: now,
    ));
    await first.mediaLibrary.store(_storedMedia(
      id: 'item-storage-2',
      localMediaId: 'detail-storage-2',
      basename: 'Storage Episode 2.mkv',
      addedAt: now.add(const Duration(minutes: 1)),
    ));
    await first.playbackHistory.record(StoredPlaybackHistoryRecord(
      id: 'history-storage-2',
      localMediaId: 'detail-storage-2',
      position: const Duration(minutes: 9),
      duration: const Duration(minutes: 24),
      updatedAt: now.add(const Duration(minutes: 2)),
    ));
    await first.providerBinding.saveAutomaticIfAllowed(_storedBinding(
      id: 'binding-storage-1',
      localMediaId: 'detail-storage-1',
      subjectId: 'subject-1',
      createdAt: now,
    ));
    await first.providerBinding.saveAutomaticIfAllowed(_storedBinding(
      id: 'binding-storage-2',
      localMediaId: 'detail-storage-2',
      subjectId: 'subject-1',
      createdAt: now.add(const Duration(minutes: 1)),
    ));
    first.dispose();

    final SqliteStorageFoundation second =
        SqliteStorageFoundation.open(databaseFile.path);
    addTearDown(second.dispose);
    final RecordingCacheInvalidationBus invalidationBus =
        RecordingCacheInvalidationBus();
    final SettingsBangumiLocalTrackingStore localTrackingStore =
        SettingsBangumiLocalTrackingStore(second.settings);
    final VideoDetailBootstrap bootstrap = storageBackedVideoDetailBootstrap(
      storage: second,
      metadataProvider: FakeBangumiProvider(
        subjectsById: <String, BangumiSubject>{'subject-1': _subject()},
        providerId: defaultVideoDetailMetadataProviderId,
      ),
      invalidationBus: invalidationBus,
      localTrackingStore: localTrackingStore,
      now: () => now,
    );
    addTearDown(bootstrap.dispose);

    final VideoDetailViewData detail =
        await bootstrap.load(const VideoDetailId('subject-1'));
    final VideoDetailActionResult select = await bootstrap.controller
        .selectEpisode(const VideoDetailId('subject-1'),
            const VideoEpisodeId('detail-storage-1'));
    final VideoDetailActionResult follow =
        await bootstrap.controller.follow(const VideoDetailId('subject-1'));
    final VideoDetailViewData followed =
        await bootstrap.load(const VideoDetailId('subject-1'));

    expect(detail.title, 'Subject Title');
    expect(
      detail.episodes.map((VideoDetailEpisode episode) => episode.title),
      <String>['Storage Episode 1.mkv', 'Storage Episode 2.mkv'],
    );
    expect(detail.continueWatching?.mediaId.value, 'detail-storage-2');
    expect(detail.binding?.authority, ProviderBindingAuthority.automatic);
    expect(detail.followState, VideoFollowState.notFollowed);
    expect(detail.actions.primary.single.kind,
        VideoDetailActionKind.continuePlayback);
    expect(select.isSuccess, isTrue);
    expect(follow.isSuccess, isTrue);
    expect(followed.followState, VideoFollowState.followed);
    expect(invalidationBus.publishedEvents.whereType<HistoryRecorded>(),
        hasLength(1));
    expect(invalidationBus.publishedEvents.whereType<BindingChanged>(),
        hasLength(1));
  });
}

VideoDetailRuntime _runtime({
  BangumiSubject? subject,
  BangumiVideoDetailSeed? seed,
  Map<String, List<BangumiEpisode>> episodesBySubjectId =
      const <String, List<BangumiEpisode>>{},
  Map<String, List<BangumiRelatedPerson>> personsBySubjectId =
      const <String, List<BangumiRelatedPerson>>{},
  Map<String, List<BangumiRelatedCharacter>> charactersBySubjectId =
      const <String, List<BangumiRelatedCharacter>>{},
  Map<String, List<BangumiRelatedSubject>> relationsBySubjectId =
      const <String, List<BangumiRelatedSubject>>{},
  bool failPersons = false,
  bool failCharacters = false,
  bool failRelations = false,
  ProviderBindingStore? bindingStore,
  PlaybackHistoryStore? historyStore,
  CacheInvalidationBus? invalidationBus,
  PlaybackSourceHandoffContract? handoff,
  BangumiTrackingProvider? trackingProvider,
  BangumiLocalTrackingStore? localTrackingStore,
  BangumiTrackingSyncProvider? trackingSyncProvider,
  DateTime Function()? now,
}) {
  final BangumiSubject value = subject ?? _subject();
  return VideoDetailRuntime(
    metadataProvider: FakeBangumiProvider(
      subjectsById: <String, BangumiSubject>{value.id.value: value},
      providerId: defaultVideoDetailMetadataProviderId,
      episodesBySubjectId: episodesBySubjectId,
      personsBySubjectId: personsBySubjectId,
      charactersBySubjectId: charactersBySubjectId,
      relationsBySubjectId: relationsBySubjectId,
      personsFailureKind: failPersons ? AcgProviderFailureKind.retryable : null,
      charactersFailureKind:
          failCharacters ? AcgProviderFailureKind.retryable : null,
      relationsFailureKind:
          failRelations ? AcgProviderFailureKind.retryable : null,
    ),
    bindingStore: bindingStore ?? DeterministicProviderBindingStore(),
    historyStore: historyStore ?? DeterministicPlaybackHistoryStore(),
    playbackSourceHandoff: handoff ?? const LocalPlaybackSourceHandoff(),
    invalidationBus: invalidationBus ?? RecordingCacheInvalidationBus(),
    trackingProvider: trackingProvider,
    localTrackingStore: localTrackingStore,
    trackingSyncProvider: trackingSyncProvider,
    seeds: seed == null
        ? const <BangumiVideoDetailSeed>[]
        : <BangumiVideoDetailSeed>[seed],
    now: now,
  );
}

BangumiSubject _subject() {
  return const BangumiSubject(
      id: BangumiSubjectId('subject-1'),
      title: 'Subject Title',
      summary: 'Subject summary');
}

BangumiEpisode _episode(String id, int index) {
  return BangumiEpisode(
      id: BangumiEpisodeId(id),
      subjectId: const BangumiSubjectId('subject-1'),
      index: index,
      title: 'Episode $index');
}

LocalMediaIdentity _media(String id, String basename) {
  return LocalMediaIdentity(
      id: LocalMediaId(id),
      uri: Uri.file('/library/$basename'),
      basename: basename);
}

StoredMediaLibraryItemRecord _storedMedia({
  required String id,
  required String localMediaId,
  required String basename,
  required DateTime addedAt,
}) {
  return StoredMediaLibraryItemRecord(
    id: id,
    localMediaId: localMediaId,
    uri: Uri.file('/library/$basename'),
    basename: basename,
    addedAt: addedAt,
    duration: const Duration(minutes: 24),
  );
}

StoredProviderBindingRecord _storedBinding({
  required String id,
  required String localMediaId,
  required String subjectId,
  required DateTime createdAt,
}) {
  return StoredProviderBindingRecord(
    id: id,
    localMediaId: localMediaId,
    providerId: defaultVideoDetailMetadataProviderId,
    providerSubjectId: subjectId,
    authority: storageProviderBindingAuthorityAutomatic,
    confidence: 0.8,
    createdAt: createdAt,
  );
}

Future<File> _tempDatabaseFile() async {
  final Directory directory =
      await Directory.systemTemp.createTemp('elaina-video-detail-test-');
  return File('${directory.path}${Platform.pathSeparator}storage.sqlite');
}

final class _RuntimeObserver implements VideoDetailRuntimeObserver {
  final List<VideoDetailRuntimeSnapshot> snapshots =
      <VideoDetailRuntimeSnapshot>[];

  @override
  void onVideoDetailRuntimeSnapshot(VideoDetailRuntimeSnapshot snapshot) {
    snapshots.add(snapshot);
  }
}
