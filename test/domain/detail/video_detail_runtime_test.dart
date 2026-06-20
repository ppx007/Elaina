import 'dart:async';
import 'dart:io';

import 'package:elaina/elaina.dart';
import 'package:flutter_test/flutter_test.dart';

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
        contains(VideoDetailActionKind.unfollow));
    expect(watched.title, detail.title);
    expect(runtime.currentSnapshot.status, VideoDetailRuntimeStatus.ready);
    expect(observer.snapshots.single.activeDetail?.id.value, 'subject-1');

    runtime.dispose();
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
    final _RecordingCacheInvalidationBus invalidationBus =
        _RecordingCacheInvalidationBus();
    final _RecordingPlaybackSourceHandoff handoff =
        _RecordingPlaybackSourceHandoff();
    final VideoDetailRuntime runtime = _runtime(
      bindingStore: bindingStore,
      historyStore: historyStore,
      invalidationBus: invalidationBus,
      handoff: handoff,
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
    final VideoDetailActionResult unfollowResult =
        await runtime.controller.unfollow(const VideoDetailId('subject-1'));
    final VideoDetailViewData unfollowed =
        await runtime.load(const VideoDetailId('subject-1'));

    expect(continueResult.isSuccess, isTrue);
    expect(selectResult.isSuccess, isTrue);
    expect(followResult.isSuccess, isTrue);
    expect(refreshResult.isSuccess, isTrue);
    expect(unfollowResult.isSuccess, isTrue);
    expect(
        handoff.inputs.map(
            (LocalMediaIdentity identity) => identity.uri.pathSegments.last),
        <String>['Action 2.mkv', 'Action 1.mkv']);
    expect(invalidationBus.publishedEvents.whereType<HistoryRecorded>(),
        hasLength(2));
    expect(invalidationBus.publishedEvents.whereType<BindingChanged>(),
        hasLength(3));
    expect(followed.followState, VideoFollowState.followed);
    expect(unfollowed.followState, VideoFollowState.notFollowed);

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
      metadataProvider:
          const _FakeBangumiProvider(subjects: <String, BangumiSubject>{}),
      bindingStore: DeterministicProviderBindingStore(),
      historyStore: DeterministicPlaybackHistoryStore(),
      playbackSourceHandoff: const LocalPlaybackSourceHandoff(),
      invalidationBus: _RecordingCacheInvalidationBus(),
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
    final _RecordingCacheInvalidationBus invalidationBus =
        _RecordingCacheInvalidationBus();
    final VideoDetailBootstrap bootstrap = storageBackedVideoDetailBootstrap(
      storage: second,
      metadataProvider: _FakeBangumiProvider(
        subjects: <String, BangumiSubject>{'subject-1': _subject()},
      ),
      invalidationBus: invalidationBus,
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
  ProviderBindingStore? bindingStore,
  PlaybackHistoryStore? historyStore,
  CacheInvalidationBus? invalidationBus,
  PlaybackSourceHandoffContract? handoff,
  DateTime Function()? now,
}) {
  final BangumiSubject value = subject ?? _subject();
  return VideoDetailRuntime(
    metadataProvider: _FakeBangumiProvider(
        subjects: <String, BangumiSubject>{value.id.value: value}),
    bindingStore: bindingStore ?? DeterministicProviderBindingStore(),
    historyStore: historyStore ?? DeterministicPlaybackHistoryStore(),
    playbackSourceHandoff: handoff ?? const LocalPlaybackSourceHandoff(),
    invalidationBus: invalidationBus ?? _RecordingCacheInvalidationBus(),
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

final class _RecordingPlaybackSourceHandoff
    implements PlaybackSourceHandoffContract {
  final List<LocalMediaIdentity> inputs = <LocalMediaIdentity>[];

  @override
  PlaybackSourceHandoffResult prepare(PlaybackSourceHandoffInput input) {
    if (input case LocalMediaIdentityHandoffInput(:final identity)) {
      inputs.add(identity);
    }
    return const LocalPlaybackSourceHandoff().prepare(input);
  }
}

final class _RecordingCacheInvalidationBus implements CacheInvalidationBus {
  final StreamController<CacheInvalidationEvent> _controller =
      StreamController<CacheInvalidationEvent>.broadcast(sync: true);
  final List<CacheInvalidationEvent> publishedEvents =
      <CacheInvalidationEvent>[];

  @override
  Stream<CacheInvalidationEvent> get events => _controller.stream;

  @override
  void publish(CacheInvalidationEvent event) {
    publishedEvents.add(event);
    _controller.add(event);
  }

  @override
  Future<void> close() => _controller.close();
}

final class _FakeBangumiProvider implements BangumiProvider {
  const _FakeBangumiProvider({required Map<String, BangumiSubject> subjects})
      : _subjects = subjects;

  final Map<String, BangumiSubject> _subjects;

  @override
  String get id => defaultVideoDetailMetadataProviderId;

  @override
  String get displayName => 'Fake Bangumi';

  @override
  ProviderKind get kind => ProviderKind.metadata;

  @override
  ProviderGateway get gateway =>
      throw UnsupportedError('Fake provider does not expose a gateway.');

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
    throw UnsupportedError('Fake provider does not execute gateway requests.');
  }

  @override
  Future<AcgProviderResult<BangumiEpisode>> lookupEpisode(BangumiEpisodeId id) {
    return Future<AcgProviderResult<BangumiEpisode>>.value(
        const AcgProviderFailure<BangumiEpisode>(
            kind: AcgProviderFailureKind.terminal,
            message: 'Episode lookup is not part of this test.'));
  }

  @override
  Future<AcgProviderResult<BangumiSubject>> lookupSubject(BangumiSubjectId id) {
    final BangumiSubject? subject = _subjects[id.value];
    if (subject == null)
      return Future<AcgProviderResult<BangumiSubject>>.value(
          const AcgProviderFailure<BangumiSubject>(
              kind: AcgProviderFailureKind.notFound,
              message: 'Missing subject.'));
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
        AcgProviderSuccess<List<BangumiSubject>>(
            <BangumiSubject>[..._subjects.values]));
  }
}
