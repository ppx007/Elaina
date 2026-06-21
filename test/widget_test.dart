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
  _FakeHomeRecommendationProvider({
    required this.popularSnapshot,
    Iterable<HomeRecommendationItem> recentItems =
        const <HomeRecommendationItem>[],
    this.recentPageLimit,
  }) : _recentItems = List<HomeRecommendationItem>.unmodifiable(recentItems);

  final HomeRecommendationSnapshot popularSnapshot;
  final List<HomeRecommendationItem> _recentItems;
  final int? recentPageLimit;

  @override
  Future<HomeRecommendationSnapshot> popularAnime() async => popularSnapshot;

  @override
  Future<HomeRecommendationSnapshot> recentPopularAnime({
    required int limit,
    required int offset,
  }) async {
    final int effectiveLimit = recentPageLimit ?? limit;
    return HomeRecommendationSnapshot.loaded(
      _recentItems.skip(offset).take(effectiveLimit),
    );
  }
}

class _FakeBangumiTrackingProvider implements BangumiTrackingProvider {
  const _FakeBangumiTrackingProvider(this.snapshot);

  final BangumiTrackingSnapshot snapshot;

  @override
  Future<BangumiTrackingSnapshot> currentAnimeCollection() async => snapshot;
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

  testWidgets(
      'Elaina App Shell shows popular hero and signed-out recent watching state',
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
          popularSnapshot: HomeRecommendationSnapshot.loaded(
            <HomeRecommendationItem>[
              const HomeRecommendationItem(
                subjectId: '100',
                title: 'Recent Hot Anime',
                rank: 1,
                score: 9.3,
                collectionTotal: 120000,
                episodeCount: 12,
              ),
            ],
          ),
          recentItems: const <HomeRecommendationItem>[
            HomeRecommendationItem(
              subjectId: '100',
              title: 'Recent Hot Anime',
              rank: 1,
              score: 9.3,
              collectionTotal: 120000,
              episodeCount: 12,
            ),
            HomeRecommendationItem(
              subjectId: '101',
              title: 'Six Month Hot Anime',
              score: 8.1,
              collectionTotal: 42000,
              episodeCount: 13,
            ),
          ],
          recentPageLimit: 1,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('欢迎回来'), findsOneWidget);
    expect(find.text('最近观看'), findsOneWidget);
    expect(find.text('请登录'), findsOneWidget);
    expect(find.text('Recent Hot Anime'), findsWidgets);
    expect(find.text('Six Month Hot Anime'), findsOneWidget);
    expect(find.text('Bangumi 近期热门，评分 9.3，120000 人收藏。'), findsWidgets);
    expect(find.textContaining('Bangumi 排名'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('home-recommendation-waterfall')),
      findsOneWidget,
    );

    await tester.tap(find.text('Recent Hot Anime').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Mock Title'), findsNWidgets(2));

    await tester.tap(find.byKey(const ValueKey<String>('video-detail-close')));
    await tester.pump();
    expect(find.text('Mock Title'), findsNothing);

    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('home-recommendation-waterfall')),
    );
    await tester.pump();
    await tester.ensureVisible(find.text('Six Month Hot Anime'));
    await tester.pump();
    await tester.tap(find.text('Six Month Hot Anime'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Mock Title'), findsNWidgets(2));

    libraryRuntime.dispose();
  });

  testWidgets('Elaina App Shell shows signed-in recent watching items',
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
        bangumiTrackingProvider: _FakeBangumiTrackingProvider(
          BangumiTrackingSnapshot.loaded(
            <BangumiTrackingItem>[
              BangumiTrackingItem(
                subjectId: '200',
                title: 'Recently Watched Anime',
                status: BangumiTrackingStatus.watching,
                watchedEpisodes: 3,
                totalEpisodes: 12,
                updatedAt: DateTime.utc(2026, 6, 20),
              ),
              BangumiTrackingItem(
                subjectId: '201',
                title: 'Planned Anime',
                status: BangumiTrackingStatus.planned,
                watchedEpisodes: 0,
                totalEpisodes: 12,
                updatedAt: DateTime.utc(2026, 6, 21),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('最近观看'), findsOneWidget);
    expect(find.text('Recently Watched Anime'), findsOneWidget);
    expect(find.text('进度 3 / 12，更新于 06-20'), findsOneWidget);
    expect(find.text('Planned Anime'), findsNothing);
    expect(find.text('请登录'), findsNothing);

    await tester.ensureVisible(find.text('查看详情'));
    await tester.pump();
    await tester.tap(find.text('查看详情'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Mock Title'), findsNWidgets(2));

    libraryRuntime.dispose();
  });
}
