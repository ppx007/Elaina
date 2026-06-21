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

final class _MappedVideoDetailRepository implements VideoDetailRepository {
  const _MappedVideoDetailRepository(this._dataById);

  final Map<String, VideoDetailViewData> _dataById;

  @override
  Future<VideoDetailViewData> load(VideoDetailId id) async => _dataFor(id);

  @override
  Stream<VideoDetailViewData> watch(VideoDetailId id) async* {
    yield _dataFor(id);
  }

  VideoDetailViewData _dataFor(VideoDetailId id) {
    final VideoDetailViewData? data = _dataById[id.value];
    if (data == null) {
      throw StateError('Missing detail fixture for ${id.value}.');
    }
    return data;
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

final class _FakeBangumiProvider implements BangumiProvider {
  _FakeBangumiProvider({required this.subjects});

  final List<BangumiSubject> subjects;

  @override
  String get displayName => 'Fake Bangumi Provider';

  @override
  ProviderGateway get gateway => _UnsupportedProviderGateway();

  @override
  String get id => 'fake-bangumi';

  @override
  ProviderKind get kind => ProviderKind.metadata;

  @override
  ProviderRegistration get registration => const ProviderRegistration(
        providerId: ProviderId('fake-bangumi'),
        ratePolicy:
            ProviderRatePolicy(maxRequests: 12, window: Duration(minutes: 1)),
        retryPolicy: ProviderRetryPolicy(
            maxAttempts: 3, initialBackoff: Duration(seconds: 1)),
      );

  @override
  Future<ProviderGatewayResponse<T>> executeGatewayRequest<T>({
    required String cacheKey,
    required Future<T> Function() load,
    ProviderCachePolicy cachePolicy = ProviderCachePolicy.networkOnly,
  }) async {
    return ProviderGatewayResponse<T>(
      value: await load(),
      source: ProviderGatewayResponseSource.network,
    );
  }

  @override
  Future<AcgProviderResult<BangumiEpisode>> lookupEpisode(BangumiEpisodeId id) {
    return Future<AcgProviderResult<BangumiEpisode>>.value(
      AcgProviderFailure<BangumiEpisode>(
        kind: AcgProviderFailureKind.unavailable,
        message: 'Episode lookup is not used by this test.',
      ),
    );
  }

  @override
  Future<AcgProviderResult<List<BangumiEpisode>>> listEpisodes(
    BangumiSubjectId subjectId,
  ) {
    return Future<AcgProviderResult<List<BangumiEpisode>>>.value(
      AcgProviderFailure<List<BangumiEpisode>>(
        kind: AcgProviderFailureKind.unavailable,
        message: 'Episode list lookup is not used by this test.',
      ),
    );
  }

  @override
  Future<AcgProviderResult<BangumiSubject>> lookupSubject(BangumiSubjectId id) {
    return Future<AcgProviderResult<BangumiSubject>>.value(
      AcgProviderFailure<BangumiSubject>(
        kind: AcgProviderFailureKind.unavailable,
        message: 'Subject lookup is not used by this test.',
      ),
    );
  }

  @override
  ProviderRequestKey requestKey(String cacheKey) {
    return ProviderRequestKey(
      providerId: const ProviderId('fake-bangumi'),
      cacheKey: cacheKey,
    );
  }

  @override
  Future<AcgProviderResult<List<BangumiSubject>>> searchSubjects(String query) {
    return Future<AcgProviderResult<List<BangumiSubject>>>.value(
      AcgProviderSuccess<List<BangumiSubject>>(subjects),
    );
  }
}

final class _UnsupportedProviderGateway implements ProviderGateway {
  @override
  StorageFoundation get storage =>
      throw UnsupportedError('Gateway storage is not used by this test.');

  @override
  Future<void> registerProvider(ProviderRegistration registration) {
    throw UnsupportedError('Provider registration is not used by this test.');
  }

  @override
  Future<ProviderGatewayResponse<T>> execute<T>(
      ProviderGatewayRequest<T> request) {
    throw UnsupportedError('Gateway execution is not used by this test.');
  }
}

void main() {
  group('MediaLibraryPage Tests', () {
    testWidgets('starts without fixed media folders',
        (WidgetTester tester) async {
      final _RecordingCacheInvalidationBus invalidationBus =
          _RecordingCacheInvalidationBus();
      final MediaLibraryRuntime runtime = MediaLibraryRuntime(
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
      await tester.pump();

      expect(find.text('暂无文件夹'), findsOneWidget);
      expect(find.textContaining('D:/media'), findsNothing);
      final ElevatedButton scanButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, '扫描本地库'),
      );
      expect(scanButton.onPressed, isNull);

      runtime.dispose();
      await invalidationBus.close();
    });

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
      final FakeSettingsRuntime settingsRuntime = FakeSettingsRuntime();
      await settingsRuntime.setPreference(
        key: SettingsPreferenceKeys.mediaLibraryRoots,
        value: '["file:///D:/media/"]',
      );

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
              settingsRuntime: settingsRuntime,
              onNavigateToDetail: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      // Verify page titles and folders render
      expect(find.text('本地媒体库'), findsWidgets);
      expect(find.text('打开文件'), findsOneWidget);
      expect(find.text('配置的文件夹'), findsOneWidget);
      expect(find.text('0 个视频'), findsOneWidget);

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

    testWidgets('confirms Bangumi match from media library item',
        (WidgetTester tester) async {
      final DateTime now = DateTime.utc(2026, 6, 20, 22);
      final MediaScanCandidate candidate =
          _candidate('media-frieren', '[Fansub] Frieren - 01 [1080p].mkv');
      final MediaLibraryItem item = MediaLibraryItem(
        id: const MediaLibraryItemId('item-frieren'),
        identity: candidate.identity,
        addedAt: now,
        duration: candidate.duration,
      );
      final DeterministicMediaLibraryCatalogRepository catalogRepo =
          DeterministicMediaLibraryCatalogRepository(
        seedItems: <MediaLibraryItem>[item],
      );
      final DeterministicProviderBindingStore bindingStore =
          DeterministicProviderBindingStore();
      final _RecordingCacheInvalidationBus invalidationBus =
          _RecordingCacheInvalidationBus();
      final MediaLibraryRuntime runtime = MediaLibraryRuntime(
        scanner: DeterministicMediaLibraryScanner(
          scanId: const MediaScanId('match-scan-id'),
        ),
        catalogRepository: catalogRepo,
        importer: DeterministicMediaBatchImportContract(
          repository: catalogRepo,
          clock: () => now,
        ),
        historyStore: DeterministicPlaybackHistoryStore(),
        bindingStore: bindingStore,
        playbackSourceHandoff: const LocalPlaybackSourceHandoff(),
        invalidationBus: invalidationBus,
        bangumiMatcher: BangumiLocalMediaMatcher(
          bangumiProvider: _FakeBangumiProvider(
            subjects: const <BangumiSubject>[
              BangumiSubject(id: BangumiSubjectId('42'), title: 'Frieren'),
            ],
          ),
        ),
        now: () => now,
      );

      await tester.pumpWidget(
        _testHost(
          child: Scaffold(
            body: MediaLibraryPage(
              mediaLibraryRuntime: runtime,
              playbackController: MockPlaybackController(
                matrix: PlaybackCapabilityMatrix(
                  capabilities: const <PlaybackCapability, CapabilityStatus>{
                    PlaybackCapability.localFilePlayback:
                        CapabilityStatus.supported(),
                  },
                ),
              ),
              settingsRuntime: FakeSettingsRuntime(),
              onNavigateToDetail: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.travel_explore));
      await tester.pumpAndSettle();
      expect(find.text('选择 Bangumi 条目'), findsOneWidget);

      await tester.tap(find.text('Frieren'));
      await tester.pumpAndSettle();

      final ProviderBinding? binding =
          await bindingStore.bindingFor(item.identity.id);
      expect(binding?.authority, ProviderBindingAuthority.userConfirmed);
      expect(binding?.subjectId?.value, '42');
      expect(find.textContaining('42'), findsOneWidget);

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

    testWidgets('allows modifying an existing media library folder path',
        (WidgetTester tester) async {
      final DateTime now = DateTime.utc(2026, 6, 19, 12);
      const String replacementFolderPath = 'D:\\anime';
      final DeterministicMediaLibraryCatalogRepository catalogRepo =
          DeterministicMediaLibraryCatalogRepository();
      final FakeSettingsRuntime settingsRuntime = FakeSettingsRuntime();
      await settingsRuntime.setPreference(
        key: SettingsPreferenceKeys.mediaLibraryRoots,
        value: '["file:///D:/media/"]',
      );
      final _RecordingCacheInvalidationBus invalidationBus =
          _RecordingCacheInvalidationBus();
      final MediaLibraryRuntime runtime = MediaLibraryRuntime(
        scanner: DeterministicMediaLibraryScanner(
          scanId: const MediaScanId('test-scan-id'),
          candidates: <MediaScanCandidate>[
            _candidate(
              'anime-media-1',
              'anime-episode-1.mkv',
              directoryPath: replacementFolderPath,
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
              directoryPathPicker: () async => replacementFolderPath,
              onNavigateToDetail: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('D:\\media'), findsOneWidget);
      await tester.tap(find.byTooltip('修改文件夹'));
      await tester.pump();

      expect(find.textContaining('anime'), findsOneWidget);
      expect(find.textContaining('D:\\media'), findsNothing);
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
      final Scaffold scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, ElainaThemeData.dark.background);
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
      expect(find.text('在追'), findsOneWidget);

      // Tap Episode 1 (available)
      await tester.tap(find.text('第 1 话'));
      await tester.pump();
      expect(actionHandler.calls, contains('selectEpisode:ep-1'));
      expect(playbackStartedCalled, isTrue);

      // Tap close/back button
      await tester
          .tap(find.byKey(const ValueKey<String>('video-detail-close')));
      await tester.pump();
      expect(closeCalled, isTrue);
    });

    testWidgets('renders remote tracking status without local follow mutation',
        (WidgetTester tester) async {
      const VideoDetailId detailId = VideoDetailId('subject-dropped');
      const VideoDetailViewData viewData = VideoDetailViewData(
        id: detailId,
        title: 'Remote Dropped Anime',
        summary: 'Remote-only detail summary.',
        followState: VideoFollowState.notFollowed,
        trackingStatus: VideoTrackingStatus.dropped,
        actions: VideoDetailActionSet(actions: <VideoDetailAction>[]),
        episodes: <VideoDetailEpisode>[
          VideoDetailEpisode(
            id: VideoEpisodeId('remote-ep-1'),
            index: 1,
            title: 'Remote Episode 1',
          ),
        ],
      );
      final FakeVideoDetailActionHandler actionHandler =
          FakeVideoDetailActionHandler();
      final VideoDetailPageContract contract = VideoDetailPageContract(
        controller: VideoDetailController(
          repository: FakeVideoDetailRepository(initialData: viewData),
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

      await tester.pumpWidget(
        _testHost(
          child: VideoDetailPage(
            id: detailId,
            videoDetailPageContract: contract,
            playbackController: playbackController,
            onPlaybackStarted: () {},
            onClose: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('抛弃'), findsOneWidget);
      expect(find.text('加入追番'), findsNothing);

      await tester.tap(find.text('抛弃'));
      await tester.pump();
      expect(actionHandler.calls, isEmpty);
    });

    testWidgets('reloads detail stream and tracking state when id changes',
        (WidgetTester tester) async {
      const VideoDetailId plannedId = VideoDetailId('subject-planned');
      const VideoDetailId droppedId = VideoDetailId('subject-dropped');
      const VideoDetailViewData plannedData = VideoDetailViewData(
        id: plannedId,
        title: 'Planned Remote Anime',
        summary: 'Planned summary.',
        followState: VideoFollowState.notFollowed,
        trackingStatus: VideoTrackingStatus.planned,
        actions: VideoDetailActionSet(actions: <VideoDetailAction>[]),
        episodes: <VideoDetailEpisode>[],
      );
      const VideoDetailViewData droppedData = VideoDetailViewData(
        id: droppedId,
        title: 'Dropped Remote Anime',
        summary: 'Dropped summary.',
        followState: VideoFollowState.notFollowed,
        trackingStatus: VideoTrackingStatus.dropped,
        actions: VideoDetailActionSet(actions: <VideoDetailAction>[]),
        episodes: <VideoDetailEpisode>[],
      );
      final FakeVideoDetailActionHandler actionHandler =
          FakeVideoDetailActionHandler();
      final VideoDetailPageContract contract = VideoDetailPageContract(
        controller: VideoDetailController(
          repository: const _MappedVideoDetailRepository(
            <String, VideoDetailViewData>{
              'subject-planned': plannedData,
              'subject-dropped': droppedData,
            },
          ),
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

      Future<void> pumpDetail(VideoDetailId id) {
        return tester.pumpWidget(
          _testHost(
            child: VideoDetailPage(
              id: id,
              videoDetailPageContract: contract,
              playbackController: playbackController,
              onPlaybackStarted: () {},
              onClose: () {},
            ),
          ),
        );
      }

      await pumpDetail(plannedId);
      await tester.pump();
      expect(find.text('Planned Remote Anime'), findsNWidgets(2));
      expect(find.text('想看'), findsOneWidget);
      expect(find.text('加入追番'), findsNothing);

      await pumpDetail(droppedId);
      await tester.pump();

      expect(find.text('Planned Remote Anime'), findsNothing);
      expect(find.text('想看'), findsNothing);
      expect(find.text('Dropped Remote Anime'), findsNWidgets(2));
      expect(find.text('抛弃'), findsOneWidget);
      expect(find.text('加入追番'), findsNothing);
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
      await tester.tap(find.byIcon(Icons.arrow_back).last);
      await tester.pump();

      // Expect overlay is closed and we are back to Library page
      expect(find.text('预加载番剧'), findsNothing);
      expect(find.text('本地媒体库'), findsWidgets);

      libraryRuntime.dispose();
      await invalidationBus.close();
    });

    testWidgets('Bangumi login action opens token acquisition page',
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
      final _RecordingBangumiLoginController bangumiLoginController =
          _RecordingBangumiLoginController();

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
            bangumiLoginController: bangumiLoginController,
            carouselAutoScroll: false,
          ),
        ),
      );

      await tester.tap(find.text('我的追番'));
      await tester.pump();
      await tester.tap(find.text('登录 Bangumi').first);
      await tester.pump();

      expect(bangumiLoginController.startLoginCalls, 1);
      expect(
        bangumiLoginController.openedUri,
        defaultBangumiAccessTokenPageUri,
      );
      expect(find.text('已打开 Bangumi token 获取页面'), findsOneWidget);

      libraryRuntime.dispose();
      await invalidationBus.close();
    });

    testWidgets('Bangumi token login refreshes remote tracking collection',
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
              id: VideoDetailId('42'),
              title: 'Remote Anime',
              summary: 'Remote detail summary',
              episodes: <VideoDetailEpisode>[],
              followState: VideoFollowState.followed,
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
      final _MutableBangumiTrackingProvider trackingProvider =
          _MutableBangumiTrackingProvider(
        const BangumiTrackingSnapshot.unauthenticated('missing token'),
      );
      final _RecordingBangumiLoginController bangumiLoginController =
          _RecordingBangumiLoginController(
        onSignIn: (_) {
          trackingProvider.snapshot = BangumiTrackingSnapshot.loaded(
            const <BangumiTrackingItem>[
              BangumiTrackingItem(
                subjectId: '42',
                title: 'Remote Anime',
                status: BangumiTrackingStatus.watching,
                watchedEpisodes: 5,
                totalEpisodes: 12,
              ),
            ],
          );
        },
      );

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
            bangumiTrackingProvider: trackingProvider,
            bangumiLoginController: bangumiLoginController,
            carouselAutoScroll: false,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('设置'));
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey<String>('settings-bangumi-access-token')),
        ' token-1 ',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('settings-bangumi-login')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('我的追番'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(trackingProvider.calls, greaterThanOrEqualTo(2));
      expect(bangumiLoginController.submittedToken, 'token-1');
      expect(find.text('Remote Anime'), findsOneWidget);
      expect(find.text('Bangumi ID: 42'), findsOneWidget);
      expect(find.text('5 / 12'), findsOneWidget);

      await tester.tap(find.text('Remote Anime'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Remote detail summary'), findsOneWidget);

      await playbackController.open(
        LocalFilePlaybackSource(uri: Uri.parse('file:///D:/media/remote.mkv')),
      );
      await playbackController.play();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester
          .tap(find.byKey(const ValueKey<String>('video-detail-close')));
      await tester.pump();
      expect(find.text('Remote detail summary'), findsNothing);
      await playbackController.stop();
      await tester.pump();

      await tester.tap(find.text('在追 1'));
      await tester.pump();
      expect(find.text('Remote Anime'), findsOneWidget);

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

final class _RecordingBangumiLoginController implements BangumiLoginController {
  _RecordingBangumiLoginController({this.onSignIn});

  final void Function(String token)? onSignIn;
  int startLoginCalls = 0;
  Uri? openedUri;
  String? submittedToken;

  @override
  Future<BangumiLoginStartResult> startLogin() async {
    startLoginCalls++;
    openedUri = defaultBangumiAccessTokenPageUri;
    return BangumiLoginStartResult.opened(openedUri!);
  }

  @override
  Future<BangumiTokenSignInResult> signInWithAccessToken(
    String accessToken,
  ) async {
    submittedToken = accessToken;
    onSignIn?.call(submittedToken!);
    return const BangumiTokenSignInResult.signedIn(
      UserProfileSnapshot(displayName: 'Alice'),
    );
  }
}

final class _MutableBangumiTrackingProvider implements BangumiTrackingProvider {
  _MutableBangumiTrackingProvider(this.snapshot);

  BangumiTrackingSnapshot snapshot;
  int calls = 0;

  @override
  Future<BangumiTrackingSnapshot> currentAnimeCollection() async {
    calls++;
    return snapshot;
  }
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
