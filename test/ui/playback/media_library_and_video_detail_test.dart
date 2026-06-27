import 'package:elaina/elaina.dart';
import 'package:elaina/src/domain/diagnostics/diagnostics_domain.dart';
import 'package:elaina/src/ui/detail/video_detail_page.dart';
import 'package:elaina/src/ui/media/media_library_page.dart';
import 'package:elaina/src/ui/playback/shell/elaina_app_shell.dart';
import 'package:elaina/src/ui/theme/elaina_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../framework/elaina_test_framework.dart';
import '../../support/provider_test_fakes.dart';
import '../../support/runtime_test_fakes.dart';
import '../../support/ui_test_host.dart';
import '../../support/widget_test_waiters.dart';

Finder _richTextContaining(String text) {
  return find.byWidgetPredicate(
    (Widget widget) =>
        widget is RichText && widget.text.toPlainText().contains(text),
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
    testWidgets('starts without fixed media folders',
        (WidgetTester tester) async {
      final RecordingCacheInvalidationBus invalidationBus =
          RecordingCacheInvalidationBus();
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
        elainaTestHost(
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
      expect(find.text('还没有索引媒体'), findsOneWidget);
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
      final RecordingCacheInvalidationBus invalidationBus =
          RecordingCacheInvalidationBus();
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
        elainaTestHost(
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
      expect(find.text('媒体库文件夹'), findsOneWidget);
      expect(find.text('索引媒体'), findsOneWidget);
      expect(find.text('0 个视频'), findsOneWidget);

      // Tap scan button
      await tester.tap(find.text('扫描本地库'));
      await tester.pumpAndSettle();

      // Verify items imported
      expect(find.text('2 / 2 个文件'), findsOneWidget);
      expect(find.text('episode-1.mkv'), findsWidgets);
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
      final RecordingCacheInvalidationBus invalidationBus =
          RecordingCacheInvalidationBus();
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
          bangumiProvider: FakeBangumiProvider(
            subjects: const <BangumiSubject>[
              BangumiSubject(id: BangumiSubjectId('42'), title: 'Frieren'),
            ],
          ),
        ),
        now: () => now,
      );

      await tester.pumpWidget(
        elainaTestHost(
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

      await tester.ensureVisible(find.byTooltip('匹配 Bangumi').first);
      await tester.tap(find.byTooltip('匹配 Bangumi').first);
      await tester.pumpAndSettle();
      expect(find.text('选择 Bangumi 条目'), findsOneWidget);
      expect(find.textContaining('匹配度 100%'), findsOneWidget);

      await tester.tap(find.text('Frieren'));
      await tester.pumpAndSettle();

      final ProviderBinding? binding =
          await bindingStore.bindingFor(item.identity.id);
      expect(binding?.authority, ProviderBindingAuthority.userConfirmed);
      expect(binding?.subjectId?.value, '42');
      expect(find.textContaining('42'), findsWidgets);

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
      final RecordingCacheInvalidationBus invalidationBus =
          RecordingCacheInvalidationBus();
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
        elainaTestHost(
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

      expect(find.text('1 / 1 个文件'), findsOneWidget);
      expect(find.text('anime-episode-1.mkv'), findsWidgets);

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
      final RecordingCacheInvalidationBus invalidationBus =
          RecordingCacheInvalidationBus();
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
        elainaTestHost(
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

      expect(find.text('1 / 1 个文件'), findsOneWidget);
      expect(find.text('anime-episode-1.mkv'), findsWidgets);

      runtime.dispose();
      await invalidationBus.close();
    });

    testWidgets('filters indexed media and updates selected detail panel',
        (WidgetTester tester) async {
      final DateTime now = DateTime.utc(2026, 6, 19, 12);
      final LocalMediaIdentity watchingMedia = LocalMediaIdentity(
        id: const LocalMediaId('media-watching'),
        uri: Uri.parse('file:///D:/media/watching-episode.mkv'),
        basename: 'watching-episode.mkv',
      );
      final LocalMediaIdentity boundMedia = LocalMediaIdentity(
        id: const LocalMediaId('media-bound'),
        uri: Uri.parse('file:///D:/media/bound-episode.mkv'),
        basename: 'bound-episode.mkv',
      );
      final DeterministicMediaLibraryCatalogRepository catalogRepo =
          DeterministicMediaLibraryCatalogRepository(
        seedItems: <MediaLibraryItem>[
          MediaLibraryItem(
            id: const MediaLibraryItemId('item-watching'),
            identity: watchingMedia,
            addedAt: now,
            duration: const Duration(minutes: 24),
          ),
          MediaLibraryItem(
            id: const MediaLibraryItemId('item-bound'),
            identity: boundMedia,
            addedAt: now.subtract(const Duration(minutes: 1)),
            duration: const Duration(minutes: 25),
          ),
        ],
      );
      final DeterministicPlaybackHistoryStore historyStore =
          DeterministicPlaybackHistoryStore();
      await historyStore.record(
        PlaybackHistoryEntry(
          id: const PlaybackHistoryEntryId('history-watching'),
          mediaId: watchingMedia.id,
          position: const Duration(minutes: 12),
          duration: const Duration(minutes: 24),
          updatedAt: now.add(const Duration(minutes: 1)),
        ),
      );
      final DeterministicProviderBindingStore bindingStore =
          DeterministicProviderBindingStore();
      await bindingStore.saveUserConfirmed(
        ProviderBinding(
          id: const ProviderBindingId('binding-bound'),
          localMediaId: boundMedia.id,
          providerId: bangumiProviderBindingProviderId,
          subjectId: const ProviderSubjectId('42'),
          authority: ProviderBindingAuthority.userConfirmed,
          confidence: 1,
          createdAt: now,
        ),
      );
      final RecordingCacheInvalidationBus invalidationBus =
          RecordingCacheInvalidationBus();
      final MediaLibraryRuntime runtime = MediaLibraryRuntime(
        scanner: const EmptyMediaLibraryScanner(),
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

      await tester.pumpWidget(
        elainaTestHost(
          child: Scaffold(
            body: MediaLibraryPage(
              mediaLibraryRuntime: runtime,
              playbackController: mockPlaybackController(),
              settingsRuntime: FakeSettingsRuntime(),
              onNavigateToDetail: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('2 / 2 个文件'), findsOneWidget);
      expect(find.text('watching-episode.mkv'), findsWidgets);
      expect(find.text('已观看 50%'), findsOneWidget);
      expect(find.text('Bangumi ID: 42'), findsWidgets);

      await tester.tap(find.widgetWithText(ChoiceChip, '继续观看'));
      await tester.pump();
      expect(find.text('watching-episode.mkv'), findsWidgets);
      expect(find.text('bound-episode.mkv'), findsNothing);

      await tester.tap(find.widgetWithText(ChoiceChip, '已绑定'));
      await tester.pump();
      expect(find.text('bound-episode.mkv'), findsWidgets);
      expect(find.text('watching-episode.mkv'), findsNothing);

      await tester.enterText(
        find.byType(TextField),
        'bound',
      );
      await tester.pump();
      expect(find.text('bound-episode.mkv'), findsWidgets);

      runtime.dispose();
      await invalidationBus.close();
    });

    testWidgets('removes indexed item only after confirmation',
        (WidgetTester tester) async {
      final DateTime now = DateTime.utc(2026, 6, 19, 12);
      final MediaScanCandidate candidate =
          _candidate('media-remove', 'remove-me.mkv');
      final DeterministicMediaLibraryCatalogRepository catalogRepo =
          DeterministicMediaLibraryCatalogRepository(
        seedItems: <MediaLibraryItem>[
          MediaLibraryItem(
            id: const MediaLibraryItemId('item-remove'),
            identity: candidate.identity,
            addedAt: now,
            duration: candidate.duration,
          ),
        ],
      );
      final RecordingCacheInvalidationBus invalidationBus =
          RecordingCacheInvalidationBus();
      final MediaLibraryRuntime runtime = MediaLibraryRuntime(
        scanner: const EmptyMediaLibraryScanner(),
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

      await tester.pumpWidget(
        elainaTestHost(
          child: Scaffold(
            body: MediaLibraryPage(
              mediaLibraryRuntime: runtime,
              playbackController: mockPlaybackController(),
              settingsRuntime: FakeSettingsRuntime(),
              onNavigateToDetail: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('remove-me.mkv'), findsWidgets);
      await tester.ensureVisible(find.text('移除索引'));
      await tester.tap(find.text('移除索引'));
      await tester.pumpAndSettle();
      expect(
          find.text('确认从媒体库索引中移除「remove-me.mkv」？本地文件不会被删除。'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, '移除索引'));
      await tester.pumpAndSettle();

      expect((await runtime.count()).value, 0);
      expect(find.text('remove-me.mkv'), findsNothing);
      expect(find.text('已移除索引，本地文件已保留'), findsOneWidget);

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
        metadataStats: const VideoDetailMetadataStats(
          score: 9.1,
          rank: 8,
          collectionTotal: 12345,
          episodeCount: 12,
        ),
        credits: const <VideoDetailCredit>[
          VideoDetailCredit(
            id: 'staff-1',
            name: '今敏',
            role: '导演',
            careers: <String>['director'],
            episodeRange: '全话',
          ),
          VideoDetailCredit(
            id: 'staff-2',
            name: '虚渊玄',
            role: '脚本',
            careers: <String>['writer'],
          ),
        ],
        characters: const <VideoDetailCharacter>[
          VideoDetailCharacter(
            id: 'character-1',
            name: '艾蕾娜',
            role: '主角',
            voiceActors: <VideoDetailVoiceActor>[
              VideoDetailVoiceActor(id: 'actor-1', name: '本渡枫'),
            ],
          ),
        ],
        relations: const <VideoDetailRelatedSubject>[
          VideoDetailRelatedSubject(
            id: 'related-1',
            title: '赛博朋克大冒险 第二季',
            relation: '续集',
            type: bangumiAnimeSubjectType,
          ),
        ],
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
        elainaTestHost(
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
      expect(find.text('评分 9.1'), findsOneWidget);
      expect(find.text('排名 #8'), findsOneWidget);
      expect(find.text('收藏 12345'), findsOneWidget);
      expect(find.text('话数 12'), findsOneWidget);
      expect(find.text('制作人员'), findsOneWidget);
      expect(find.text('导演 1'), findsOneWidget);
      expect(find.text('脚本 1'), findsOneWidget);
      expect(find.text('导演'), findsOneWidget);
      expect(find.text('今敏'), findsOneWidget);
      expect(find.text('director · 全话'), findsOneWidget);
      expect(find.text('虚渊玄'), findsNothing);
      await tester.ensureVisible(find.text('脚本 1'));
      await tester.pump();
      await tester.tap(find.text('脚本 1'));
      await tester.pumpAndSettle();
      expect(find.text('今敏'), findsNothing);
      expect(find.text('脚本'), findsOneWidget);
      expect(find.text('虚渊玄'), findsOneWidget);
      expect(find.text('writer'), findsOneWidget);
      expect(find.text('角色与声优'), findsOneWidget);
      expect(find.text('主角'), findsOneWidget);
      expect(find.text('艾蕾娜'), findsOneWidget);
      expect(find.text('声优: 本渡枫'), findsOneWidget);
      expect(find.text('关联条目'), findsOneWidget);
      expect(find.text('续集'), findsOneWidget);
      expect(find.text('赛博朋克大冒险 第二季'), findsOneWidget);

      // Verify tracking state changes
      expect(find.text('加入追番'), findsOneWidget);
      await tester.ensureVisible(find.text('加入追番'));
      await tester.pump();
      await tester.tap(find.text('加入追番'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('在追').last);
      await tester.pumpAndSettle();
      expect(actionHandler.calls, contains('setTrackingStatus:watching'));

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
      await tester.pumpAndSettle();
      expect(find.text('在追'), findsWidgets);

      // Tap Episode 1 (available)
      await tester.ensureVisible(find.text('第 1 话'));
      await tester.pump();
      await tester.tap(find.text('第 1 话'));
      await tester.pump();
      expect(actionHandler.calls, contains('selectEpisode:ep-1'));
      expect(playbackController.currentState.status,
          PlaybackLifecycleStatus.playing);
      expect(playbackController.currentState.sourceUri.toString(),
          'file:///D:/media/episode-1.mkv');
      expect(playbackStartedCalled, isTrue);

      // Tap close/back button
      await tester.tap(ElainaFinders.videoDetailClose);
      await tester.pump();
      expect(closeCalled, isTrue);
    });

    testWidgets('renders optional metadata empty and failure states',
        (WidgetTester tester) async {
      const VideoDetailId detailId = VideoDetailId('subject-metadata-failure');
      const VideoDetailViewData viewData = VideoDetailViewData(
        id: detailId,
        title: 'Metadata Failure Anime',
        summary: 'Metadata failure summary.',
        followState: VideoFollowState.notFollowed,
        actions: VideoDetailActionSet(actions: <VideoDetailAction>[]),
        episodes: <VideoDetailEpisode>[],
        metadataFailures: <VideoDetailMetadataFailure>[
          VideoDetailMetadataFailure(
            section: VideoDetailMetadataSection.staff,
            message: 'Staff offline',
          ),
          VideoDetailMetadataFailure(
            section: VideoDetailMetadataSection.characters,
            message: 'Characters offline',
          ),
          VideoDetailMetadataFailure(
            section: VideoDetailMetadataSection.relations,
            message: 'Relations offline',
          ),
        ],
      );
      final VideoDetailPageContract contract = VideoDetailPageContract(
        controller: VideoDetailController(
          repository: FakeVideoDetailRepository(initialData: viewData),
          actions: FakeVideoDetailActionHandler(),
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
        elainaTestHost(
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

      expect(find.text('Metadata Failure Anime'), findsNWidgets(2));
      expect(find.text('Bangumi 暂无评分与收藏统计'), findsOneWidget);
      expect(find.text('暂无剧集'), findsOneWidget);
      expect(find.text('制作人员加载失败: Staff offline'), findsOneWidget);
      expect(find.text('角色与声优加载失败: Characters offline'), findsOneWidget);
      expect(find.text('关联条目加载失败: Relations offline'), findsOneWidget);
    });

    testWidgets('updates remote-only tracking status through status menu',
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
        elainaTestHost(
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

      expect(find.text('抛弃'), findsWidgets);
      expect(find.text('加入追番'), findsNothing);

      await tester.tap(find.text('抛弃').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('搁置').last);
      await tester.pumpAndSettle();
      expect(actionHandler.calls, contains('setTrackingStatus:onHold'));
    });

    testWidgets('prompts when local and remote tracking status conflict',
        (WidgetTester tester) async {
      const VideoDetailId detailId = VideoDetailId('subject-conflict');
      final VideoDetailViewData viewData = VideoDetailViewData(
        id: detailId,
        title: 'Conflict Anime',
        summary: 'Conflict detail summary.',
        followState: VideoFollowState.followed,
        trackingStatus: VideoTrackingStatus.watching,
        trackingConflict: VideoTrackingConflict(
          subjectId: detailId.value,
          title: 'Conflict Anime',
          localStatus: VideoTrackingStatus.dropped,
          remoteStatus: VideoTrackingStatus.watching,
          localUpdatedAt: DateTime.utc(2026, 6, 21, 9),
          remoteUpdatedAt: DateTime.utc(2026, 6, 21, 12),
        ),
        actions: const VideoDetailActionSet(actions: <VideoDetailAction>[]),
        episodes: const <VideoDetailEpisode>[],
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
        elainaTestHost(
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
      await tester.pumpAndSettle();

      expect(find.text('追番状态冲突'), findsOneWidget);
      expect(_richTextContaining('本地状态: 抛弃'), findsOneWidget);
      expect(_richTextContaining('云端状态: 在追'), findsOneWidget);

      await tester.tap(find.text('云端同步到本地'));
      await tester.pumpAndSettle();

      expect(
        actionHandler.calls,
        contains('resolveTrackingConflict:remoteToLocal'),
      );
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
          repository: const MappedVideoDetailRepository(
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
          elainaTestHost(
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
      expect(find.text('想看'), findsWidgets);
      expect(find.text('加入追番'), findsNothing);

      await pumpDetail(droppedId);
      await tester.pump();

      expect(find.text('Planned Remote Anime'), findsNothing);
      expect(find.text('想看'), findsNothing);
      expect(find.text('Dropped Remote Anime'), findsNWidgets(2));
      expect(find.text('抛弃'), findsWidgets);
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
      final RecordingCacheInvalidationBus invalidationBus =
          RecordingCacheInvalidationBus();

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
        engine: FakeRssEngine(),
        store: DeterministicRssFeedStore(),
        scheduler: FakeFeedScheduler(),
        policyStore: policyStore,
      );
      final BtTaskCoreRuntime btTaskCoreRuntime =
          BtTaskCoreRuntime.unavailable(reason: 'testing');

      await tester.pumpWidget(
        elainaTestHost(
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
      expect(find.text('episode-1.mkv'), findsWidgets);

      // Tap detail info button
      expect(find.byTooltip('打开番剧详情'), findsWidgets);
      await tester.ensureVisible(find.byTooltip('打开番剧详情').first);
      await tester.tap(find.byTooltip('打开番剧详情').first);
      await tester.pump();
      await tester.pumpUntilFound(find.text('预加载番剧'));

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

    testWidgets('detail episode playback closes detail and shows player',
        (WidgetTester tester) async {
      final RecordingCacheInvalidationBus invalidationBus =
          RecordingCacheInvalidationBus();
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
      final LocalMediaIdentity playableMedia = LocalMediaIdentity(
        id: const LocalMediaId('media-playable-1'),
        uri: Uri.parse('file:///D:/media/episode-1.mkv'),
        basename: 'episode-1.mkv',
      );
      final VideoDetailPageContract videoDetailContract =
          VideoDetailPageContract(
        controller: VideoDetailController(
          repository: FakeVideoDetailRepository(
            initialData: VideoDetailViewData(
              id: const VideoDetailId('subject-playable'),
              title: 'Playable Anime',
              episodes: <VideoDetailEpisode>[
                VideoDetailEpisode(
                  id: const VideoEpisodeId('playable-ep-1'),
                  index: 1,
                  title: 'episode-1.mkv',
                  localMedia: playableMedia,
                  localMediaId: playableMedia.id,
                ),
              ],
              followState: VideoFollowState.followed,
              trackingStatus: VideoTrackingStatus.watching,
              actions:
                  const VideoDetailActionSet(actions: <VideoDetailAction>[]),
            ),
          ),
          actions: FakeVideoDetailActionHandler(),
        ),
      );
      final DeterministicRssAutoDownloadPolicyStore policyStore =
          DeterministicRssAutoDownloadPolicyStore();
      final RssEngineRuntime rssEngineRuntime = RssEngineRuntime(
        engine: FakeRssEngine(),
        store: DeterministicRssFeedStore(),
        scheduler: FakeFeedScheduler(),
        policyStore: policyStore,
      );
      final BtTaskCoreRuntime btTaskCoreRuntime =
          BtTaskCoreRuntime.unavailable(reason: 'testing');

      await tester.pumpWidget(
        elainaTestHost(
          child: ElainaAppShell(
            playbackController: playbackController,
            videoSurface: const SizedBox(),
            mediaLibraryRuntime: libraryRuntime,
            videoDetailPageContract: videoDetailContract,
            rssEngineRuntime: rssEngineRuntime,
            downloadRuntime: DownloadRuntimeAdapter(btTaskCoreRuntime),
            settingsRuntime: FakeSettingsRuntime(),
            diagnosticsRuntime: FakeDiagnosticsRuntime(),
            bangumiTrackingProvider: MutableBangumiTrackingProvider(
              BangumiTrackingSnapshot.loaded(
                const <BangumiTrackingItem>[
                  BangumiTrackingItem(
                    subjectId: 'subject-playable',
                    title: 'Playable Anime',
                    status: BangumiTrackingStatus.watching,
                    watchedEpisodes: 1,
                    totalEpisodes: 12,
                  ),
                ],
              ),
            ),
            carouselAutoScroll: false,
          ),
        ),
      );

      await tester.tap(find.text('我的追番'));
      await tester.pump();
      await tester.tap(find.text('Playable Anime'));
      await tester.pump();
      await tester.pumpUntilFound(find.text('播放第 1 话'));
      expect(find.text('播放第 1 话'), findsWidgets);

      await tester.tap(find.text('播放第 1 话').first);
      await tester.pump();
      await tester.pumpUntilFound(find.text('episode-1.mkv'));

      expect(playbackController.currentState.status,
          PlaybackLifecycleStatus.playing);
      expect(playbackController.currentState.sourceUri.toString(),
          'file:///D:/media/episode-1.mkv');
      expect(find.text('episode-1.mkv'), findsOneWidget);

      libraryRuntime.dispose();
      await invalidationBus.close();
    });

    testWidgets('Bangumi login action opens OAuth authorization page',
        (WidgetTester tester) async {
      final RecordingCacheInvalidationBus invalidationBus =
          RecordingCacheInvalidationBus();
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
        engine: FakeRssEngine(),
        store: DeterministicRssFeedStore(),
        scheduler: FakeFeedScheduler(),
        policyStore: policyStore,
      );
      final BtTaskCoreRuntime btTaskCoreRuntime =
          BtTaskCoreRuntime.unavailable(reason: 'testing');
      final RecordingBangumiLoginController bangumiLoginController =
          RecordingBangumiLoginController();

      await tester.pumpWidget(
        elainaTestHost(
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
        defaultBangumiOAuthAuthorizationPageUri,
      );
      expect(find.text('已打开 Bangumi OAuth 授权页面'), findsOneWidget);

      libraryRuntime.dispose();
      await invalidationBus.close();
    });

    testWidgets('Bangumi token login refreshes remote tracking collection',
        (WidgetTester tester) async {
      final RecordingCacheInvalidationBus invalidationBus =
          RecordingCacheInvalidationBus();
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
        engine: FakeRssEngine(),
        store: DeterministicRssFeedStore(),
        scheduler: FakeFeedScheduler(),
        policyStore: policyStore,
      );
      final BtTaskCoreRuntime btTaskCoreRuntime =
          BtTaskCoreRuntime.unavailable(reason: 'testing');
      final MutableBangumiTrackingProvider trackingProvider =
          MutableBangumiTrackingProvider(
        const BangumiTrackingSnapshot.unauthenticated('missing token'),
      );
      final RecordingBangumiLoginController bangumiLoginController =
          RecordingBangumiLoginController(
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
        elainaTestHost(
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
      await tester.tap(find.text('Bangumi').first);
      await tester.pump();
      final Finder tokenField = ElainaFinders.settingsBangumiAccessToken;
      final Finder loginButton = ElainaFinders.settingsBangumiLogin;
      await tester.ensureVisible(tokenField);
      await tester.pump();
      await tester.enterText(tokenField, ' token-1 ');
      await tester.ensureVisible(loginButton);
      await tester.tap(loginButton);
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('我的追番'));
      await tester.pump();
      await tester.pumpUntilFound(find.text('Remote Anime'));

      expect(trackingProvider.calls, greaterThanOrEqualTo(2));
      expect(bangumiLoginController.submittedToken, 'token-1');
      expect(find.text('Remote Anime'), findsOneWidget);
      expect(find.text('Bangumi ID: 42'), findsOneWidget);
      expect(find.text('5 / 12'), findsOneWidget);

      await tester.tap(find.text('Remote Anime'));
      await tester.pump();
      await tester.pumpUntilFound(find.text('Remote detail summary'));
      expect(find.text('Remote detail summary'), findsOneWidget);

      await playbackController.open(
        LocalFilePlaybackSource(uri: Uri.parse('file:///D:/media/remote.mkv')),
      );
      await playbackController.play();
      await tester.pump();
      await tester.pump();
      await tester.tap(ElainaFinders.videoDetailClose);
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
      final RecordingCacheInvalidationBus invalidationBus =
          RecordingCacheInvalidationBus();
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
        engine: FakeRssEngine(),
        store: DeterministicRssFeedStore(),
        scheduler: FakeFeedScheduler(),
        policyStore: policyStore,
      );
      final BtTaskCoreRuntime btTaskCoreRuntime =
          BtTaskCoreRuntime.unavailable(reason: 'testing');

      await tester.pumpWidget(
        elainaTestHost(
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
