import 'dart:async';

import 'package:elaina/elaina.dart';
import 'package:elaina/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/widget_test_waiters.dart';

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
  int popularCalls = 0;
  int recentPopularCalls = 0;

  @override
  Future<HomeRecommendationSnapshot> popularAnime() async {
    popularCalls++;
    return popularSnapshot;
  }

  @override
  Future<HomeRecommendationSnapshot> recentPopularAnime({
    required int limit,
    required int offset,
  }) async {
    recentPopularCalls++;
    final int effectiveLimit = recentPageLimit ?? limit;
    return HomeRecommendationSnapshot.loaded(
      _recentItems.skip(offset).take(effectiveLimit),
    );
  }
}

class _FakeHomeSearchProvider implements HomeSearchProvider {
  _FakeHomeSearchProvider({
    Map<String, HomeSearchSnapshot> snapshotsByQuery =
        const <String, HomeSearchSnapshot>{},
    Map<String, List<HomeSearchSnapshot>> queuedSnapshotsByQuery =
        const <String, List<HomeSearchSnapshot>>{},
    Map<String, Completer<HomeSearchSnapshot>> pendingByQuery =
        const <String, Completer<HomeSearchSnapshot>>{},
  })  : _snapshotsByQuery = snapshotsByQuery,
        _queuedSnapshotsByQuery = <String, List<HomeSearchSnapshot>>{
          for (final MapEntry<String, List<HomeSearchSnapshot>> entry
              in queuedSnapshotsByQuery.entries)
            entry.key: <HomeSearchSnapshot>[...entry.value],
        },
        _pendingByQuery = pendingByQuery;

  final Map<String, HomeSearchSnapshot> _snapshotsByQuery;
  final Map<String, List<HomeSearchSnapshot>> _queuedSnapshotsByQuery;
  final Map<String, Completer<HomeSearchSnapshot>> _pendingByQuery;
  final List<String> searchedQueries = <String>[];

  @override
  Future<HomeSearchSnapshot> searchAnime(String query) {
    searchedQueries.add(query);
    final List<HomeSearchSnapshot>? queue = _queuedSnapshotsByQuery[query];
    if (queue != null && queue.isNotEmpty) {
      return Future<HomeSearchSnapshot>.value(queue.removeAt(0));
    }
    final Completer<HomeSearchSnapshot>? pending = _pendingByQuery[query];
    if (pending != null) return pending.future;
    return Future<HomeSearchSnapshot>.value(
      _snapshotsByQuery[query] ??
          HomeSearchSnapshot.loaded(const <HomeSearchItem>[]),
    );
  }
}

class _FakeBangumiTrackingProvider implements BangumiTrackingProvider {
  _FakeBangumiTrackingProvider(this.snapshot);

  final BangumiTrackingSnapshot snapshot;
  int currentAnimeCollectionCalls = 0;

  @override
  Future<BangumiTrackingSnapshot> currentAnimeCollection() async {
    currentAnimeCollectionCalls++;
    return snapshot;
  }
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
  Future<VideoDetailActionResult> setTrackingStatus(
          VideoDetailId id, VideoTrackingStatus status) async =>
      const VideoDetailActionResult.success();
  @override
  Future<VideoDetailActionResult> resolveTrackingConflict(
          VideoDetailId id, VideoTrackingConflictResolution resolution) async =>
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

final class _WidgetShellFixture {
  const _WidgetShellFixture(this.libraryRuntime);

  final MediaLibraryRuntime libraryRuntime;

  void dispose() {
    libraryRuntime.dispose();
  }
}

Future<_WidgetShellFixture> _pumpHomeSearchShell(
  WidgetTester tester, {
  required HomeSearchProvider homeSearchProvider,
}) async {
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
      scanId: const MediaScanId('search-shell-scan'),
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
      homeSearchProvider: homeSearchProvider,
    ),
  );
  await tester.pump();
  return _WidgetShellFixture(libraryRuntime);
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

  testWidgets('home search opens typeahead and Enter opens first result',
      (WidgetTester tester) async {
    final _FakeHomeSearchProvider searchProvider = _FakeHomeSearchProvider(
      snapshotsByQuery: <String, HomeSearchSnapshot>{
        'fri': HomeSearchSnapshot.loaded(
          const <HomeSearchItem>[
            HomeSearchItem(
              subjectId: 'search-frieren',
              title: 'Frieren',
              summary: 'Journey after the end.',
              score: 9.1,
              collectionTotal: 120000,
              episodeCount: 28,
            ),
          ],
        ),
      },
    );
    final _WidgetShellFixture fixture = await _pumpHomeSearchShell(
      tester,
      homeSearchProvider: searchProvider,
    );

    await tester.tap(find.byKey(const ValueKey<String>('home-search-entry')));
    await tester.pump();
    await tester.pumpUntilFound(
      find.byKey(const ValueKey<String>('home-search-input')),
    );
    final TextField input = tester.widget<TextField>(
      find.byKey(const ValueKey<String>('home-search-input')),
    );
    expect(input.focusNode?.hasFocus, isTrue);

    await tester.enterText(
      find.byKey(const ValueKey<String>('home-search-input')),
      'f',
    );
    await tester.pump(homeSearchDebounceDuration);
    expect(searchProvider.searchedQueries, isEmpty);

    await tester.enterText(
      find.byKey(const ValueKey<String>('home-search-input')),
      'fri',
    );
    await tester.pump(homeSearchDebounceDuration);
    await tester.pumpUntilFound(find.text('Frieren'));

    expect(searchProvider.searchedQueries, <String>['fri']);
    expect(find.text('评分 9.1 · 120000 人收藏 · 28 话'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pumpUntilFound(find.text('Mock Title'));

    expect(
        find.byKey(const ValueKey<String>('home-search-input')), findsNothing);
    expect(find.text('Mock Title'), findsNWidgets(2));

    fixture.dispose();
  });

  testWidgets('home search closes with Escape', (WidgetTester tester) async {
    final _WidgetShellFixture fixture = await _pumpHomeSearchShell(
      tester,
      homeSearchProvider: _FakeHomeSearchProvider(),
    );

    await tester.tap(find.byKey(const ValueKey<String>('home-search-entry')));
    await tester.pump();
    await tester.pumpUntilFound(
      find.byKey(const ValueKey<String>('home-search-input')),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(
        find.byKey(const ValueKey<String>('home-search-input')), findsNothing);

    fixture.dispose();
  });

  testWidgets('home search retry recovers from provider failure',
      (WidgetTester tester) async {
    final _FakeHomeSearchProvider searchProvider = _FakeHomeSearchProvider(
      queuedSnapshotsByQuery: <String, List<HomeSearchSnapshot>>{
        'bad': <HomeSearchSnapshot>[
          const HomeSearchSnapshot.failed('Bangumi temporarily failed.'),
          HomeSearchSnapshot.loaded(
            const <HomeSearchItem>[
              HomeSearchItem(
                subjectId: 'retry-subject',
                title: 'Recovered Anime',
              ),
            ],
          ),
        ],
      },
    );
    final _WidgetShellFixture fixture = await _pumpHomeSearchShell(
      tester,
      homeSearchProvider: searchProvider,
    );

    await tester.tap(find.byKey(const ValueKey<String>('home-search-entry')));
    await tester.pump();
    await tester.pumpUntilFound(
      find.byKey(const ValueKey<String>('home-search-input')),
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('home-search-input')),
      'bad',
    );
    await tester.pump(homeSearchDebounceDuration);
    await tester.pumpUntilFound(find.text('Bangumi temporarily failed.'));

    await tester.tap(find.byKey(const ValueKey<String>('home-search-retry')));
    await tester.pump();
    await tester.pumpUntilFound(find.text('Recovered Anime'));

    expect(searchProvider.searchedQueries, <String>['bad', 'bad']);

    fixture.dispose();
  });

  testWidgets('home search ignores stale typeahead results',
      (WidgetTester tester) async {
    final Completer<HomeSearchSnapshot> oldSearch =
        Completer<HomeSearchSnapshot>();
    final Completer<HomeSearchSnapshot> newSearch =
        Completer<HomeSearchSnapshot>();
    final _FakeHomeSearchProvider searchProvider = _FakeHomeSearchProvider(
      pendingByQuery: <String, Completer<HomeSearchSnapshot>>{
        'sl': oldSearch,
        'slow': newSearch,
      },
    );
    final _WidgetShellFixture fixture = await _pumpHomeSearchShell(
      tester,
      homeSearchProvider: searchProvider,
    );

    await tester.tap(find.byKey(const ValueKey<String>('home-search-entry')));
    await tester.pump();
    await tester.pumpUntilFound(
      find.byKey(const ValueKey<String>('home-search-input')),
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('home-search-input')),
      'sl',
    );
    await tester.pump(homeSearchDebounceDuration);
    expect(searchProvider.searchedQueries, <String>['sl']);

    await tester.enterText(
      find.byKey(const ValueKey<String>('home-search-input')),
      'slow',
    );
    await tester.pump(homeSearchDebounceDuration);
    expect(searchProvider.searchedQueries, <String>['sl', 'slow']);

    newSearch.complete(
      HomeSearchSnapshot.loaded(
        const <HomeSearchItem>[
          HomeSearchItem(subjectId: 'new-result', title: 'New Result'),
        ],
      ),
    );
    await tester.pump();
    await tester.pumpUntilFound(find.text('New Result'));

    oldSearch.complete(
      HomeSearchSnapshot.loaded(
        const <HomeSearchItem>[
          HomeSearchItem(subjectId: 'old-result', title: 'Old Result'),
        ],
      ),
    );
    await tester.pump();

    expect(find.text('New Result'), findsOneWidget);
    expect(find.text('Old Result'), findsNothing);

    fixture.dispose();
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
    await tester.pumpUntilFound(find.textContaining('Alice'));

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
    await tester.pumpUntilFound(find.text('Six Month Hot Anime'));

    expect(find.text('欢迎回来'), findsOneWidget);
    expect(find.text('最近观看'), findsOneWidget);
    expect(find.text('请登录'), findsOneWidget);
    expect(find.text('Recent Hot Anime'), findsWidgets);
    expect(find.text('Six Month Hot Anime'), findsOneWidget);
    expect(find.text('Bangumi 近30天注目，评分 9.3，120000 人收藏。'), findsWidgets);
    expect(find.textContaining('Bangumi 排名'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('home-recommendation-waterfall')),
      findsOneWidget,
    );

    await tester.tap(find.text('Recent Hot Anime').first);
    await tester.pump();
    await tester.pumpUntilFound(find.text('Mock Title'));
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
    await tester.pumpUntilFound(find.text('Mock Title'));
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
    await tester.pumpUntilFound(find.text('Recently Watched Anime'));

    expect(find.text('最近观看'), findsOneWidget);
    expect(find.text('Recently Watched Anime'), findsOneWidget);
    expect(find.text('进度 3 / 12，更新于 06-20'), findsOneWidget);
    expect(find.text('Planned Anime'), findsNothing);
    expect(find.text('请登录'), findsNothing);

    await tester.ensureVisible(find.text('查看详情'));
    await tester.pump();
    await tester.tap(find.text('查看详情'));
    await tester.pump();
    await tester.pumpUntilFound(find.text('Mock Title'));
    expect(find.text('Mock Title'), findsNWidgets(2));

    libraryRuntime.dispose();
  });

  testWidgets('theme switching does not reload home or tracking providers',
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
        scanId: const MediaScanId('theme-switch-scan'),
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
    final _FakeHomeRecommendationProvider homeProvider =
        _FakeHomeRecommendationProvider(
      popularSnapshot: HomeRecommendationSnapshot.loaded(
        const <HomeRecommendationItem>[
          HomeRecommendationItem(
            subjectId: 'theme-hero',
            title: 'Theme Hero Anime',
            score: 8.8,
          ),
        ],
      ),
      recentItems: const <HomeRecommendationItem>[
        HomeRecommendationItem(
          subjectId: 'theme-more',
          title: 'Theme More Anime',
          score: 8.1,
        ),
      ],
      recentPageLimit: 1,
    );
    final _FakeBangumiTrackingProvider trackingProvider =
        _FakeBangumiTrackingProvider(
      BangumiTrackingSnapshot.loaded(
        <BangumiTrackingItem>[
          BangumiTrackingItem(
            subjectId: 'theme-tracking',
            title: 'Theme Tracking Anime',
            status: BangumiTrackingStatus.watching,
            watchedEpisodes: 2,
            totalEpisodes: 12,
            updatedAt: DateTime.utc(2026, 6, 21),
          ),
        ],
      ),
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
        homeRecommendationProvider: homeProvider,
        bangumiTrackingProvider: trackingProvider,
      ),
    );
    await tester.pump();
    await tester.pumpUntilFound(find.text('Theme Tracking Anime'));

    final int popularCalls = homeProvider.popularCalls;
    final int recentPopularCalls = homeProvider.recentPopularCalls;
    final int trackingCalls = trackingProvider.currentAnimeCollectionCalls;

    await tester.tap(find.byIcon(Icons.dark_mode));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.light_mode));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.dark_mode));
    await tester.pump();

    expect(homeProvider.popularCalls, popularCalls);
    expect(homeProvider.recentPopularCalls, recentPopularCalls);
    expect(trackingProvider.currentAnimeCollectionCalls, trackingCalls);
    expect(find.text('Theme Tracking Anime'), findsOneWidget);

    libraryRuntime.dispose();
  });
}
