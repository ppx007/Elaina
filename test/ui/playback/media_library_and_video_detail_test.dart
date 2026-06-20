import 'dart:async';

import 'package:elaina/elaina.dart';
import 'package:elaina/src/domain/diagnostics/diagnostics_domain.dart';
import 'package:elaina/src/domain/settings/settings_domain.dart';
import 'package:elaina/src/ui/detail/video_detail_page.dart';
import 'package:elaina/src/ui/media/media_library_page.dart';
import 'package:elaina/src/ui/playback/shell/elaina_app_shell.dart';
import 'package:elaina/src/ui/theme/elaina_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeVideoDetailRepository implements VideoDetailRepository {
  FakeVideoDetailRepository({required this.initialData}) {
    _controller = StreamController<VideoDetailViewData>.broadcast();
  }

  VideoDetailViewData initialData;
  late final StreamController<VideoDetailViewData> _controller;

  void update(VideoDetailViewData data) {
    initialData = data;
    _controller.add(data);
  }

  @override
  Future<VideoDetailViewData> load(VideoDetailId id) async {
    return initialData;
  }

  @override
  Stream<VideoDetailViewData> watch(VideoDetailId id) async* {
    yield initialData;
    yield* _controller.stream;
  }
}

class FakeVideoDetailActionHandler implements VideoDetailActionHandler {
  final List<String> calls = <String>[];

  @override
  Future<VideoDetailActionResult> continuePlayback(VideoDetailId id) async {
    calls.add('continuePlayback');
    return const VideoDetailActionResult.success();
  }

  @override
  Future<VideoDetailActionResult> selectEpisode(
      VideoDetailId id, VideoEpisodeId episodeId) async {
    calls.add('selectEpisode:${episodeId.value}');
    return const VideoDetailActionResult.success();
  }

  @override
  Future<VideoDetailActionResult> follow(VideoDetailId id) async {
    calls.add('follow');
    return const VideoDetailActionResult.success();
  }

  @override
  Future<VideoDetailActionResult> unfollow(VideoDetailId id) async {
    calls.add('unfollow');
    return const VideoDetailActionResult.success();
  }

  @override
  Future<VideoDetailActionResult> perform(
      VideoDetailId id, VideoDetailAction action) async {
    calls.add('perform:${action.kind}');
    return const VideoDetailActionResult.success();
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

Widget _testHost({required Widget child}) {
  return MaterialApp(
    home: ElainaTheme(
      data: ElainaThemeData.dark,
      mode: ElainaThemeMode.dark,
      onModeChanged: (_) {},
      child: child,
    ),
  );
}

MediaScanCandidate _candidate(
  String mediaId,
  String basename, {
  String directoryPath = 'D:/media',
}) {
  return MediaScanCandidate(
    identity: LocalMediaIdentity(
      id: LocalMediaId(mediaId),
      uri: Uri.directory(directoryPath).resolve(basename),
      basename: basename,
    ),
    sizeBytes: 1024 * 1024,
    duration: const Duration(minutes: 24),
  );
}

void main() {
  group('MediaLibraryPage Tests', () {
    testWidgets('renders folder stats and executes scan process successfully',
        (WidgetTester tester) async {
      final DateTime now = DateTime.utc(2026, 6, 19, 12);
      const MediaScanId scanId = MediaScanId('test-scan-id');
      final DeterministicMediaLibraryCatalogRepository catalogRepo =
          DeterministicMediaLibraryCatalogRepository();
      final DeterministicPlaybackHistoryStore historyStore =
          DeterministicPlaybackHistoryStore();
      final DeterministicProviderBindingStore bindingStore =
          DeterministicProviderBindingStore();
      final _RecordingCacheInvalidationBus invalidationBus =
          _RecordingCacheInvalidationBus();

      final MediaLibraryRuntime runtime = MediaLibraryRuntime(
        scanner: DeterministicMediaLibraryScanner(
          scanId: scanId,
          candidates: <MediaScanCandidate>[
            _candidate('media-1', 'episode-1.mkv'),
            _candidate('media-2', 'episode-2.mkv'),
          ],
        ),
        catalogRepository: catalogRepo,
        importer: DeterministicMediaBatchImportContract(
          repository: catalogRepo,
          clock: () => now,
        ),
        historyStore: historyStore,
        bindingStore: bindingStore,
        playbackSourceHandoff: const LocalPlaybackSourceHandoff(),
        invalidationBus: invalidationBus,
        now: () => now,
      );

      final MockPlaybackController playbackController = MockPlaybackController(
        matrix: PlaybackCapabilityMatrix(
          capabilities: const <PlaybackCapability, CapabilityStatus>{
            PlaybackCapability.playPause: CapabilityStatus.supported(),
            PlaybackCapability.localFilePlayback: CapabilityStatus.supported(),
          },
        ),
      );

      await tester.pumpWidget(
        _testHost(
          child: Scaffold(
            body: MediaLibraryPage(
              mediaLibraryRuntime: runtime,
              playbackController: playbackController,
              settingsRuntime: FakeSettingsRuntime(),
              onNavigateToDetail: (_) {},
            ),
          ),
        ),
      );

      // Verify page titles and folders render
      expect(find.text('本地媒体库'), findsWidgets);
      expect(find.text('打开文件'), findsOneWidget);
      expect(find.text('配置的文件夹'), findsOneWidget);
      expect(find.text('0 个视频'),
          findsNWidgets(2)); // D:/media and C:/Users/Public/Videos

      // Tap scan button
      await tester.tap(find.text('扫描本地库'));
      await tester.pumpAndSettle();

      // Verify items imported
      expect(find.text('已索引内容 (2)'), findsOneWidget);
      expect(find.text('episode-1.mkv'), findsOneWidget);
      expect(find.text('episode-2.mkv'), findsOneWidget);

      runtime.dispose();
      await invalidationBus.close();
    });

    testWidgets('allows adding media library folder path before scanning',
        (WidgetTester tester) async {
      final DateTime now = DateTime.utc(2026, 6, 19, 12);
      const String selectedFolderPath = 'D:\\anime';
      final DeterministicMediaLibraryCatalogRepository catalogRepo =
          DeterministicMediaLibraryCatalogRepository();
      final FakeSettingsRuntime settingsRuntime = FakeSettingsRuntime();
      final _RecordingCacheInvalidationBus invalidationBus =
          _RecordingCacheInvalidationBus();
      final MediaLibraryRuntime runtime = MediaLibraryRuntime(
        scanner: DeterministicMediaLibraryScanner(
          scanId: const MediaScanId('test-scan-id'),
          candidates: <MediaScanCandidate>[
            _candidate(
              'anime-media-1',
              'anime-episode-1.mkv',
              directoryPath: selectedFolderPath,
            ),
          ],
        ),
        catalogRepository: catalogRepo,
        importer: DeterministicMediaBatchImportContract(
          repository: catalogRepo,
          clock: () => now,
        ),
        historyStore: DeterministicPlaybackHistoryStore(),
        bindingStore: DeterministicProviderBindingStore(),
        playbackSourceHandoff: const LocalPlaybackSourceHandoff(),
        invalidationBus: invalidationBus,
        now: () => now,
      );
      final MockPlaybackController playbackController = MockPlaybackController(
        matrix: PlaybackCapabilityMatrix(
          capabilities: const <PlaybackCapability, CapabilityStatus>{
            PlaybackCapability.playPause: CapabilityStatus.supported(),
            PlaybackCapability.localFilePlayback: CapabilityStatus.supported(),
          },
        ),
      );

      await tester.pumpWidget(
        _testHost(
          child: Scaffold(
            body: MediaLibraryPage(
              mediaLibraryRuntime: runtime,
              playbackController: playbackController,
              settingsRuntime: settingsRuntime,
              directoryPathPicker: () async => selectedFolderPath,
              onNavigateToDetail: (_) {},
            ),
          ),
        ),
      );

      await tester.tap(find.text('添加文件夹'));
      await tester.pump();
      expect(find.textContaining('anime'), findsOneWidget);
      expect(
        await settingsRuntime
            .getPreference(SettingsPreferenceKeys.mediaLibraryRoots),
        contains('anime'),
      );

      await tester.tap(find.text('扫描本地库'));
      await tester.pumpAndSettle();

      expect(find.text('已索引内容 (1)'), findsOneWidget);
      expect(find.text('anime-episode-1.mkv'), findsOneWidget);

      runtime.dispose();
      await invalidationBus.close();
    });
  });

  group('VideoDetailPage Tests', () {
    testWidgets(
        'renders video metadata and responds to follow and episode selection actions',
        (WidgetTester tester) async {
      const VideoDetailId detailId = VideoDetailId('subject-123');
      final VideoDetailViewData viewData = VideoDetailViewData(
        id: detailId,
        title: '赛博朋克大冒险',
        summary: '这是一个未来赛博世界的硬核故事。',
        followState: VideoFollowState.notFollowed,
        actions: const VideoDetailActionSet(actions: <VideoDetailAction>[]),
        episodes: <VideoDetailEpisode>[
          VideoDetailEpisode(
            id: const VideoEpisodeId('ep-1'),
            index: 1,
            title: '启航之旅',
            localMedia: LocalMediaIdentity(
              id: const LocalMediaId('media-1'),
              uri: Uri.parse('file:///D:/media/episode-1.mkv'),
              basename: 'episode-1.mkv',
            ),
          ),
          const VideoDetailEpisode(
            id: VideoEpisodeId('ep-2'),
            index: 2,
            title: '未知前路 (暂无本地文件)',
          ),
        ],
      );

      final FakeVideoDetailRepository repo =
          FakeVideoDetailRepository(initialData: viewData);
      final FakeVideoDetailActionHandler actionHandler =
          FakeVideoDetailActionHandler();
      final VideoDetailController controller = VideoDetailController(
        repository: repo,
        actions: actionHandler,
      );
      final VideoDetailPageContract contract =
          VideoDetailPageContract(controller: controller);

      final MockPlaybackController playbackController = MockPlaybackController(
        matrix: PlaybackCapabilityMatrix(
          capabilities: const <PlaybackCapability, CapabilityStatus>{
            PlaybackCapability.playPause: CapabilityStatus.supported(),
            PlaybackCapability.localFilePlayback: CapabilityStatus.supported(),
          },
        ),
      );

      bool playbackStartedCalled = false;
      bool closeCalled = false;

      await tester.pumpWidget(
        _testHost(
          child: VideoDetailPage(
            id: detailId,
            videoDetailPageContract: contract,
            playbackController: playbackController,
            onPlaybackStarted: () {
              playbackStartedCalled = true;
            },
            onClose: () {
              closeCalled = true;
            },
          ),
        ),
      );

      await tester.pump();

      // Verify layout contents
      expect(find.text('赛博朋克大冒险'),
          findsNWidgets(2)); // Header title and content title
      expect(find.text('这是一个未来赛博世界的硬核故事。'), findsOneWidget);
      expect(find.text('第 1 话'), findsOneWidget);
      expect(find.text('启航之旅'), findsOneWidget);
      expect(find.text('第 2 话'), findsOneWidget);
      expect(find.text('未知前路 (暂无本地文件)'), findsOneWidget);

      // Verify follow state changes
      expect(find.text('加入追番'), findsOneWidget);
      await tester.tap(find.text('加入追番'));
      await tester.pump();
      expect(actionHandler.calls, contains('follow'));

      // Mock follow state change
      repo.update(VideoDetailViewData(
        id: detailId,
        title: '赛博朋克大冒险',
        summary:
            '这是一个未来赛博世界的硬核故事.。', // Dot added to avoid exact duplicate data warning
        followState: VideoFollowState.followed,
        actions: const VideoDetailActionSet(actions: <VideoDetailAction>[]),
        episodes: viewData.episodes,
      ));
      await tester.pump();
      expect(find.text('已在追番'), findsOneWidget);

      // Tap Episode 1 (available)
      await tester.tap(find.text('第 1 话'));
      await tester.pump();
      expect(actionHandler.calls, contains('selectEpisode:ep-1'));
      expect(playbackStartedCalled, isTrue);

      // Tap close/back button
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pump();
      expect(closeCalled, isTrue);
    });
  });

  group('ElainaAppShell Integration Tests', () {
    testWidgets('navigation and detail page overlay toggles successfully',
        (WidgetTester tester) async {
      final DateTime now = DateTime.utc(2026, 6, 19, 12);
      const MediaScanId scanId = MediaScanId('test-scan-id');
      final DeterministicPlaybackHistoryStore historyStore =
          DeterministicPlaybackHistoryStore();
      final DeterministicProviderBindingStore bindingStore =
          DeterministicProviderBindingStore();
      final _RecordingCacheInvalidationBus invalidationBus =
          _RecordingCacheInvalidationBus();

      // Pre-seed catalog & binding to allow detail page navigation from info button
      final LocalMediaIdentity seededMedia = LocalMediaIdentity(
        id: const LocalMediaId('media-1'),
        uri: Uri.parse('file:///D:/media/episode-1.mkv'),
        basename: 'episode-1.mkv',
      );
      final DeterministicMediaLibraryCatalogRepository catalogRepo =
          DeterministicMediaLibraryCatalogRepository(
        seedItems: <MediaLibraryItem>[
          MediaLibraryItem(
            id: const MediaLibraryItemId('item-1'),
            identity: seededMedia,
            addedAt: now,
          ),
        ],
      );

      final MediaLibraryRuntime libraryRuntime = MediaLibraryRuntime(
        scanner: DeterministicMediaLibraryScanner(
          scanId: scanId,
          candidates: <MediaScanCandidate>[
            MediaScanCandidate(
              identity: seededMedia,
              sizeBytes: 1024,
              duration: const Duration(minutes: 24),
            ),
          ],
        ),
        catalogRepository: catalogRepo,
        importer: DeterministicMediaBatchImportContract(
          repository: catalogRepo,
          clock: () => now,
        ),
        historyStore: historyStore,
        bindingStore: bindingStore,
        playbackSourceHandoff: const LocalPlaybackSourceHandoff(),
        invalidationBus: invalidationBus,
        now: () => now,
      );

      await bindingStore.saveUserConfirmed(ProviderBinding(
        id: const ProviderBindingId('binding-1'),
        localMediaId: seededMedia.id,
        providerId: defaultVideoDetailMetadataProviderId,
        subjectId: const ProviderSubjectId('subject-1'),
        authority: ProviderBindingAuthority.userConfirmed,
        confidence: 1.0,
        createdAt: now,
      ));

      await libraryRuntime.refresh();

      final FakeVideoDetailRepository detailRepo = FakeVideoDetailRepository(
        initialData: const VideoDetailViewData(
          id: VideoDetailId('subject-1'),
          title: '预加载番剧',
          episodes: <VideoDetailEpisode>[],
          followState: VideoFollowState.notFollowed,
          actions: VideoDetailActionSet(actions: <VideoDetailAction>[]),
        ),
      );
      final FakeVideoDetailActionHandler actionHandler =
          FakeVideoDetailActionHandler();
      final VideoDetailPageContract videoDetailContract =
          VideoDetailPageContract(
        controller: VideoDetailController(
          repository: detailRepo,
          actions: actionHandler,
        ),
      );

      final MockPlaybackController playbackController = MockPlaybackController(
        matrix: PlaybackCapabilityMatrix(
          capabilities: const <PlaybackCapability, CapabilityStatus>{
            PlaybackCapability.playPause: CapabilityStatus.supported(),
            PlaybackCapability.localFilePlayback: CapabilityStatus.supported(),
          },
        ),
      );

      final DeterministicRssAutoDownloadPolicyStore policyStore =
          DeterministicRssAutoDownloadPolicyStore();
      final RssEngineRuntime rssEngineRuntime = RssEngineRuntime(
        engine: _FakeRssEngine(),
        store: DeterministicRssFeedStore(),
        scheduler: _FakeFeedScheduler(),
        policyStore: policyStore,
      );
      final BtTaskCoreRuntime btTaskCoreRuntime =
          BtTaskCoreRuntime.unavailable(reason: 'testing');

      await tester.pumpWidget(
        _testHost(
          child: ElainaAppShell(
            playbackController: playbackController,
            videoSurface: const SizedBox(),
            mediaLibraryRuntime: libraryRuntime,
            videoDetailPageContract: videoDetailContract,
            rssEngineRuntime: rssEngineRuntime,
            downloadRuntime: DownloadRuntimeAdapter(btTaskCoreRuntime),
            settingsRuntime: FakeSettingsRuntime(),
            diagnosticsRuntime: FakeDiagnosticsRuntime(),
            carouselAutoScroll: false,
          ),
        ),
      );

      // Navigate to the Bangumi tracking page first.
      await tester.tap(find.text('我的追番'));
      await tester.pump();
      expect(find.text('Bangumi 追番'), findsOneWidget);
      expect(find.text('episode-1.mkv'), findsOneWidget);
      expect(find.text('Bangumi ID: subject-1'), findsOneWidget);

      // Navigate to the separate local media library entry.
      await tester.tap(find.text('本地媒体库'));
      await tester.pump();
      expect(find.text('本地媒体库'), findsWidgets);
      expect(find.text('episode-1.mkv'), findsOneWidget);

      // Tap detail info button
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
      await tester.tap(find.byIcon(Icons.info_outline));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Expect VideoDetailPage overlay to render
      expect(find.text('预加载番剧'), findsNWidgets(2));

      // Close VideoDetailPage overlay
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pump();

      // Expect overlay is closed and we are back to Library page
      expect(find.text('预加载番剧'), findsNothing);
      expect(find.text('本地媒体库'), findsWidgets);

      libraryRuntime.dispose();
      await invalidationBus.close();
    });

    testWidgets('Bangumi login action opens settings access token section',
        (WidgetTester tester) async {
      final _RecordingCacheInvalidationBus invalidationBus =
          _RecordingCacheInvalidationBus();
      final MediaLibraryRuntime libraryRuntime = MediaLibraryRuntime(
        scanner: DeterministicMediaLibraryScanner(
          scanId: const MediaScanId('test-scan-id'),
          candidates: const <MediaScanCandidate>[],
        ),
        catalogRepository: DeterministicMediaLibraryCatalogRepository(),
        importer: DeterministicMediaBatchImportContract(
          repository: DeterministicMediaLibraryCatalogRepository(),
        ),
        historyStore: DeterministicPlaybackHistoryStore(),
        bindingStore: DeterministicProviderBindingStore(),
        playbackSourceHandoff: const LocalPlaybackSourceHandoff(),
        invalidationBus: invalidationBus,
      );
      final MockPlaybackController playbackController = MockPlaybackController(
        matrix: PlaybackCapabilityMatrix(
          capabilities: const <PlaybackCapability, CapabilityStatus>{
            PlaybackCapability.playPause: CapabilityStatus.supported(),
            PlaybackCapability.localFilePlayback: CapabilityStatus.supported(),
          },
        ),
      );
      final VideoDetailPageContract videoDetailContract =
          VideoDetailPageContract(
        controller: VideoDetailController(
          repository: FakeVideoDetailRepository(
            initialData: const VideoDetailViewData(
              id: VideoDetailId('subject-1'),
              title: '预加载番剧',
              episodes: <VideoDetailEpisode>[],
              followState: VideoFollowState.notFollowed,
              actions: VideoDetailActionSet(actions: <VideoDetailAction>[]),
            ),
          ),
          actions: FakeVideoDetailActionHandler(),
        ),
      );
      final DeterministicRssAutoDownloadPolicyStore policyStore =
          DeterministicRssAutoDownloadPolicyStore();
      final RssEngineRuntime rssEngineRuntime = RssEngineRuntime(
        engine: _FakeRssEngine(),
        store: DeterministicRssFeedStore(),
        scheduler: _FakeFeedScheduler(),
        policyStore: policyStore,
      );
      final BtTaskCoreRuntime btTaskCoreRuntime =
          BtTaskCoreRuntime.unavailable(reason: 'testing');

      await tester.pumpWidget(
        _testHost(
          child: ElainaAppShell(
            playbackController: playbackController,
            videoSurface: const SizedBox(),
            mediaLibraryRuntime: libraryRuntime,
            videoDetailPageContract: videoDetailContract,
            rssEngineRuntime: rssEngineRuntime,
            downloadRuntime: DownloadRuntimeAdapter(btTaskCoreRuntime),
            settingsRuntime: FakeSettingsRuntime(),
            diagnosticsRuntime: FakeDiagnosticsRuntime(),
            carouselAutoScroll: false,
          ),
        ),
      );

      await tester.tap(find.text('我的追番'));
      await tester.pump();
      await tester.tap(find.text('登录 Bangumi').first);
      await tester.pump();

      expect(find.text('Bangumi'), findsOneWidget);
      expect(find.text('Access token'), findsOneWidget);

      libraryRuntime.dispose();
      await invalidationBus.close();
    });

    testWidgets('Bangumi tracking filters update visible list and empty state',
        (WidgetTester tester) async {
      final DateTime now = DateTime.utc(2026, 6, 19, 12);
      final DeterministicPlaybackHistoryStore historyStore =
          DeterministicPlaybackHistoryStore();
      final DeterministicProviderBindingStore bindingStore =
          DeterministicProviderBindingStore();
      final _RecordingCacheInvalidationBus invalidationBus =
          _RecordingCacheInvalidationBus();
      final LocalMediaIdentity seededMedia = LocalMediaIdentity(
        id: const LocalMediaId('media-1'),
        uri: Uri.parse('file:///D:/media/episode-1.mkv'),
        basename: 'episode-1.mkv',
      );
      final DeterministicMediaLibraryCatalogRepository catalogRepo =
          DeterministicMediaLibraryCatalogRepository(
        seedItems: <MediaLibraryItem>[
          MediaLibraryItem(
            id: const MediaLibraryItemId('item-1'),
            identity: seededMedia,
            addedAt: now,
          ),
        ],
      );
      await bindingStore.saveUserConfirmed(ProviderBinding(
        id: const ProviderBindingId('binding-1'),
        localMediaId: seededMedia.id,
        providerId: defaultVideoDetailMetadataProviderId,
        subjectId: const ProviderSubjectId('subject-1'),
        authority: ProviderBindingAuthority.userConfirmed,
        confidence: 1.0,
        createdAt: now,
      ));
      await historyStore.record(PlaybackHistoryEntry(
        id: const PlaybackHistoryEntryId('history-1'),
        mediaId: seededMedia.id,
        position: const Duration(minutes: 12),
        duration: const Duration(minutes: 24),
        updatedAt: now,
      ));

      final MediaLibraryRuntime libraryRuntime = MediaLibraryRuntime(
        scanner: DeterministicMediaLibraryScanner(
          scanId: const MediaScanId('test-scan-id'),
          candidates: <MediaScanCandidate>[
            MediaScanCandidate(
              identity: seededMedia,
              sizeBytes: 1024,
              duration: const Duration(minutes: 24),
            ),
          ],
        ),
        catalogRepository: catalogRepo,
        importer: DeterministicMediaBatchImportContract(
          repository: catalogRepo,
          clock: () => now,
        ),
        historyStore: historyStore,
        bindingStore: bindingStore,
        playbackSourceHandoff: const LocalPlaybackSourceHandoff(),
        invalidationBus: invalidationBus,
        now: () => now,
      );
      await libraryRuntime.refresh();

      final MockPlaybackController playbackController = MockPlaybackController(
        matrix: PlaybackCapabilityMatrix(
          capabilities: const <PlaybackCapability, CapabilityStatus>{
            PlaybackCapability.playPause: CapabilityStatus.supported(),
            PlaybackCapability.localFilePlayback: CapabilityStatus.supported(),
          },
        ),
      );
      final VideoDetailPageContract videoDetailContract =
          VideoDetailPageContract(
        controller: VideoDetailController(
          repository: FakeVideoDetailRepository(
            initialData: const VideoDetailViewData(
              id: VideoDetailId('subject-1'),
              title: '预加载番剧',
              episodes: <VideoDetailEpisode>[],
              followState: VideoFollowState.notFollowed,
              actions: VideoDetailActionSet(actions: <VideoDetailAction>[]),
            ),
          ),
          actions: FakeVideoDetailActionHandler(),
        ),
      );
      final DeterministicRssAutoDownloadPolicyStore policyStore =
          DeterministicRssAutoDownloadPolicyStore();
      final RssEngineRuntime rssEngineRuntime = RssEngineRuntime(
        engine: _FakeRssEngine(),
        store: DeterministicRssFeedStore(),
        scheduler: _FakeFeedScheduler(),
        policyStore: policyStore,
      );
      final BtTaskCoreRuntime btTaskCoreRuntime =
          BtTaskCoreRuntime.unavailable(reason: 'testing');

      await tester.pumpWidget(
        _testHost(
          child: ElainaAppShell(
            playbackController: playbackController,
            videoSurface: const SizedBox(),
            mediaLibraryRuntime: libraryRuntime,
            videoDetailPageContract: videoDetailContract,
            rssEngineRuntime: rssEngineRuntime,
            downloadRuntime: DownloadRuntimeAdapter(btTaskCoreRuntime),
            settingsRuntime: FakeSettingsRuntime(),
            diagnosticsRuntime: FakeDiagnosticsRuntime(),
            carouselAutoScroll: false,
          ),
        ),
      );

      await tester.tap(find.text('我的追番'));
      await tester.pump();
      expect(find.text('episode-1.mkv'), findsOneWidget);

      await tester.tap(find.text('在追 1'));
      await tester.pump();
      expect(find.text('episode-1.mkv'), findsOneWidget);
      expect(find.text('已观看 50%'), findsOneWidget);

      await tester.tap(find.text('抛弃 0'));
      await tester.pump();
      expect(find.text('当前没有抛弃条目'), findsOneWidget);

      libraryRuntime.dispose();
      await invalidationBus.close();
    });
  });
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
