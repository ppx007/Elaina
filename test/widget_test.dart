import 'dart:async';

import 'package:elaina/elaina.dart';
import 'package:elaina/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockCacheInvalidationBus implements CacheInvalidationBus {
  @override
  Stream<CacheInvalidationEvent> get events => const Stream.empty();
  @override
  void publish(CacheInvalidationEvent event) {}
  @override
  Future<void> close() async {}
}

class _FakeVideoDetailRepository implements VideoDetailRepository {
  @override
  Future<VideoDetailViewData> load(VideoDetailId id) async {
    return VideoDetailViewData(
      id: id,
      title: 'Mock Title',
      episodes: const [],
      followState: VideoFollowState.notFollowed,
      actions: const VideoDetailActionSet(actions: []),
    );
  }

  @override
  Stream<VideoDetailViewData> watch(VideoDetailId id) => Stream.value(
        VideoDetailViewData(
          id: id,
          title: 'Mock Title',
          episodes: const [],
          followState: VideoFollowState.notFollowed,
          actions: const VideoDetailActionSet(actions: []),
        ),
      );
}

class _FakeUserProfileProvider implements UserProfileProvider {
  const _FakeUserProfileProvider(this.snapshot);

  final UserProfileSnapshot? snapshot;

  @override
  Future<UserProfileSnapshot?> currentProfile() async => snapshot;
}

class _FakeHomeRecommendationProvider implements HomeRecommendationProvider {
  const _FakeHomeRecommendationProvider(this.snapshot);

  final HomeRecommendationSnapshot snapshot;

  @override
  Future<HomeRecommendationSnapshot> popularAnime() async => snapshot;
}

class _FakeVideoDetailActionHandler implements VideoDetailActionHandler {
  @override
  Future<VideoDetailActionResult> continuePlayback(VideoDetailId id) async =>
      const VideoDetailActionResult.success();
  @override
  Future<VideoDetailActionResult> selectEpisode(
          VideoDetailId id, VideoEpisodeId episodeId) async =>
      const VideoDetailActionResult.success();
  @override
  Future<VideoDetailActionResult> follow(VideoDetailId id) async =>
      const VideoDetailActionResult.success();
  @override
  Future<VideoDetailActionResult> unfollow(VideoDetailId id) async =>
      const VideoDetailActionResult.success();
  @override
  Future<VideoDetailActionResult> perform(
          VideoDetailId id, VideoDetailAction action) async =>
      const VideoDetailActionResult.success();
}

class _FakeRssEngine implements RssEngineContract {
  @override
  Future<void> registerSource(FeedSource source) async {}

  @override
  Future<RssRefreshOutcome> refreshSource(RssRefreshRequest request) async {
    return RssRefreshOutcome.success(
      sourceId: request.sourceId,
      newItems: const <FeedItem>[],
    );
  }

  @override
  Stream<FeedItem> get updates => const Stream<FeedItem>.empty();
}

class _FakeFeedScheduler implements FeedScheduler {
  @override
  Stream<FeedScheduleDecision> dueSources(Iterable<FeedSource> sources) =>
      const Stream<FeedScheduleDecision>.empty();
}

class _FakeDownloadEngineAdapter implements DownloadEngineAdapter {
  @override
  String get displayName => 'Fake Download Engine';

  @override
  String get id => 'fake-download-engine';

  @override
  BtCapabilityMatrix get capabilities => const BtCapabilityMatrix(
        capabilities: <BtStreamingCapability, BtCapabilityStatus>{},
      );

  @override
  Future<BtTaskId> createTask(BtTaskCreateRequest request) async =>
      const BtTaskId('mock-task');

  @override
  Future<BtTaskMetadata> ensureMetadata(BtTaskId taskId) async =>
      const BtTaskMetadata(
        infoHash: InfoHash('mock'),
        name: 'mock',
        totalSizeBytes: 0,
        pieceLengthBytes: 1024,
        files: [],
      );

  @override
  Stream<BtTaskStatus> watchStatus(BtTaskId taskId) => const Stream.empty();

  @override
  Stream<BtTaskEvent> watchEvents(BtTaskId taskId) => const Stream.empty();

  @override
  Future<void> pause(BtTaskId taskId) async {}

  @override
  Future<void> resume(BtTaskId taskId) async {}

  @override
  Future<void> remove(BtTaskId taskId) async {}

  @override
  Future<void> selectFiles(
      BtTaskId taskId, Iterable<BtFileIndex> files) async {}
}

void main() {
  testWidgets('Elaina App Shell smoke test', (WidgetTester tester) async {
    final mockController = MockPlaybackController(
      matrix: PlaybackCapabilityMatrix(
        capabilities: const <PlaybackCapability, CapabilityStatus>{
          PlaybackCapability.playPause: CapabilityStatus.supported(),
          PlaybackCapability.seek: CapabilityStatus.supported(),
          PlaybackCapability.stop: CapabilityStatus.supported(),
        },
      ),
    );

    final libraryRuntime = MediaLibraryRuntime(
      scanner: DeterministicMediaLibraryScanner(
        scanId: const MediaScanId('test-scan'),
        candidates: const [],
      ),
      catalogRepository: DeterministicMediaLibraryCatalogRepository(),
      importer: DeterministicMediaBatchImportContract(
        repository: DeterministicMediaLibraryCatalogRepository(),
      ),
      historyStore: DeterministicPlaybackHistoryStore(),
      bindingStore: DeterministicProviderBindingStore(),
      playbackSourceHandoff: const LocalPlaybackSourceHandoff(),
      invalidationBus: _MockCacheInvalidationBus(),
    );

    final detailContract = VideoDetailPageContract(
      controller: VideoDetailController(
        repository: _FakeVideoDetailRepository(),
        actions: _FakeVideoDetailActionHandler(),
      ),
    );

    final policyStore = DeterministicRssAutoDownloadPolicyStore();

    final rssEngineRuntime = RssEngineRuntime(
      engine: _FakeRssEngine(),
      store: DeterministicRssFeedStore(),
      scheduler: _FakeFeedScheduler(),
      policyStore: policyStore,
    );

    final btTaskCoreRuntime = BtTaskCoreRuntime.withDependencies(
      adapter: _FakeDownloadEngineAdapter(),
      store: DeterministicBtTaskStore(),
    );

    await tester.pumpWidget(
      MyApp(
        playbackController: mockController,
        videoSurface: const SizedBox(),
        mediaLibraryRuntime: libraryRuntime,
        videoDetailPageContract: detailContract,
        rssEngineRuntime: rssEngineRuntime,
        btTaskCoreRuntime: btTaskCoreRuntime,
        policyStore: policyStore,
      ),
    );

    expect(find.text('欢迎回来'), findsOneWidget);
    expect(find.text('Elaina'), findsOneWidget);

    libraryRuntime.dispose();
  });

  testWidgets('Elaina App Shell greets signed-in profile',
      (WidgetTester tester) async {
    final mockController = MockPlaybackController(
      matrix: PlaybackCapabilityMatrix(
        capabilities: const <PlaybackCapability, CapabilityStatus>{
          PlaybackCapability.playPause: CapabilityStatus.supported(),
          PlaybackCapability.seek: CapabilityStatus.supported(),
          PlaybackCapability.stop: CapabilityStatus.supported(),
        },
      ),
    );

    final libraryRuntime = MediaLibraryRuntime(
      scanner: DeterministicMediaLibraryScanner(
        scanId: const MediaScanId('test-scan'),
        candidates: const [],
      ),
      catalogRepository: DeterministicMediaLibraryCatalogRepository(),
      importer: DeterministicMediaBatchImportContract(
        repository: DeterministicMediaLibraryCatalogRepository(),
      ),
      historyStore: DeterministicPlaybackHistoryStore(),
      bindingStore: DeterministicProviderBindingStore(),
      playbackSourceHandoff: const LocalPlaybackSourceHandoff(),
      invalidationBus: _MockCacheInvalidationBus(),
    );

    final detailContract = VideoDetailPageContract(
      controller: VideoDetailController(
        repository: _FakeVideoDetailRepository(),
        actions: _FakeVideoDetailActionHandler(),
      ),
    );

    final policyStore = DeterministicRssAutoDownloadPolicyStore();

    final rssEngineRuntime = RssEngineRuntime(
      engine: _FakeRssEngine(),
      store: DeterministicRssFeedStore(),
      scheduler: _FakeFeedScheduler(),
      policyStore: policyStore,
    );

    final btTaskCoreRuntime = BtTaskCoreRuntime.withDependencies(
      adapter: _FakeDownloadEngineAdapter(),
      store: DeterministicBtTaskStore(),
    );

    await tester.pumpWidget(
      MyApp(
        playbackController: mockController,
        videoSurface: const SizedBox(),
        mediaLibraryRuntime: libraryRuntime,
        videoDetailPageContract: detailContract,
        rssEngineRuntime: rssEngineRuntime,
        btTaskCoreRuntime: btTaskCoreRuntime,
        policyStore: policyStore,
        profileProvider: const _FakeUserProfileProvider(
          UserProfileSnapshot(displayName: 'Alice'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('欢迎回来，Alice'), findsOneWidget);
    expect(find.text('欢迎回来'), findsNothing);

    libraryRuntime.dispose();
  });

  testWidgets('Elaina App Shell shows Bangumi popular ranking while signed out',
      (WidgetTester tester) async {
    final mockController = MockPlaybackController(
      matrix: PlaybackCapabilityMatrix(
        capabilities: const <PlaybackCapability, CapabilityStatus>{
          PlaybackCapability.playPause: CapabilityStatus.supported(),
          PlaybackCapability.seek: CapabilityStatus.supported(),
          PlaybackCapability.stop: CapabilityStatus.supported(),
        },
      ),
    );

    final libraryRuntime = MediaLibraryRuntime(
      scanner: DeterministicMediaLibraryScanner(
        scanId: const MediaScanId('test-scan'),
        candidates: const [],
      ),
      catalogRepository: DeterministicMediaLibraryCatalogRepository(),
      importer: DeterministicMediaBatchImportContract(
        repository: DeterministicMediaLibraryCatalogRepository(),
      ),
      historyStore: DeterministicPlaybackHistoryStore(),
      bindingStore: DeterministicProviderBindingStore(),
      playbackSourceHandoff: const LocalPlaybackSourceHandoff(),
      invalidationBus: _MockCacheInvalidationBus(),
    );

    final detailContract = VideoDetailPageContract(
      controller: VideoDetailController(
        repository: _FakeVideoDetailRepository(),
        actions: _FakeVideoDetailActionHandler(),
      ),
    );

    final policyStore = DeterministicRssAutoDownloadPolicyStore();
    final rssEngineRuntime = RssEngineRuntime(
      engine: _FakeRssEngine(),
      store: DeterministicRssFeedStore(),
      scheduler: _FakeFeedScheduler(),
      policyStore: policyStore,
    );
    final btTaskCoreRuntime = BtTaskCoreRuntime.withDependencies(
      adapter: _FakeDownloadEngineAdapter(),
      store: DeterministicBtTaskStore(),
    );

    await tester.pumpWidget(
      MyApp(
        playbackController: mockController,
        videoSurface: const SizedBox(),
        mediaLibraryRuntime: libraryRuntime,
        videoDetailPageContract: detailContract,
        rssEngineRuntime: rssEngineRuntime,
        btTaskCoreRuntime: btTaskCoreRuntime,
        policyStore: policyStore,
        homeRecommendationProvider: _FakeHomeRecommendationProvider(
          HomeRecommendationSnapshot.loaded(
            <HomeRecommendationItem>[
              const HomeRecommendationItem(
                subjectId: '100',
                title: 'Ranked Anime',
                rank: 1,
                score: 9.3,
                collectionTotal: 120000,
                episodeCount: 12,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('欢迎回来'), findsOneWidget);
    expect(find.text('热门番剧'), findsOneWidget);
    expect(find.text('Ranked Anime'), findsWidgets);
    expect(find.text('Bangumi 排名 #1，评分 9.3，120000 人收藏。'), findsWidgets);

    libraryRuntime.dispose();
  });
}
