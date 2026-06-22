import 'dart:async';

import 'package:elaina/elaina.dart';
import 'package:elaina/main.dart';
import 'package:elaina/src/domain/diagnostics/diagnostics_domain.dart';
import 'package:elaina/src/domain/settings/settings_domain.dart';
import 'package:elaina/src/ui/theme/elaina_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/runtime_test_fakes.dart';
import '../support/ui_test_host.dart';
import 'screen_robots.dart';

const String defaultTestScanId = 'test-harness-scan';
const String defaultDownloadEngineId = 'test-download-engine';
const String defaultDownloadEngineName = 'Test Download Engine';
const String defaultDownloadTaskId = 'test-task';
const String defaultDownloadInfoHash = 'test-info-hash';
const int defaultDownloadPieceLengthBytes = 1024;

final DateTime defaultDownloadInstant = DateTime.utc(2026, 6, 22, 12);

final class ElainaTestHarness {
  const ElainaTestHarness._();

  static Future<ElainaAppFixture> pumpApp(
    WidgetTester tester, {
    PlaybackControllerContract? playbackController,
    Widget videoSurface = const SizedBox(),
    MediaLibraryRuntime? mediaLibraryRuntime,
    VideoDetailPageContract? videoDetailPageContract,
    RssEngineRuntime? rssEngineRuntime,
    BtTaskCoreRuntime? btTaskCoreRuntime,
    RssAutoDownloadPolicyStore? policyStore,
    SettingsRuntime? settingsRuntime,
    DiagnosticsRuntime? diagnosticsRuntime,
    UserProfileProvider? profileProvider,
    BangumiTrackingProvider? bangumiTrackingProvider,
    BangumiLoginController? bangumiLoginController,
    HomeRecommendationProvider? homeRecommendationProvider,
    HomeSearchProvider? homeSearchProvider,
  }) async {
    final _HarnessRuntimeBundle bundle = _HarnessRuntimeBundle.create(
      playbackController: playbackController,
      mediaLibraryRuntime: mediaLibraryRuntime,
      videoDetailPageContract: videoDetailPageContract,
      rssEngineRuntime: rssEngineRuntime,
      btTaskCoreRuntime: btTaskCoreRuntime,
      policyStore: policyStore,
      settingsRuntime: settingsRuntime,
      diagnosticsRuntime: diagnosticsRuntime,
    );

    await tester.pumpWidget(
      MyApp(
        playbackController: bundle.playbackController,
        videoSurface: videoSurface,
        mediaLibraryRuntime: bundle.mediaLibraryRuntime,
        videoDetailPageContract: bundle.videoDetailPageContract,
        rssEngineRuntime: bundle.rssEngineRuntime,
        btTaskCoreRuntime: bundle.btTaskCoreRuntime,
        policyStore: bundle.policyStore,
        settingsRuntime: bundle.settingsRuntime,
        diagnosticsRuntime: bundle.diagnosticsRuntime,
        profileProvider: profileProvider,
        bangumiTrackingProvider: bangumiTrackingProvider,
        bangumiLoginController: bangumiLoginController,
        homeRecommendationProvider: homeRecommendationProvider,
        homeSearchProvider: homeSearchProvider,
      ),
    );
    await tester.pump();

    return ElainaAppFixture._(tester: tester, bundle: bundle);
  }

  static Future<ElainaAppFixture> pumpShell(
    WidgetTester tester, {
    PlaybackControllerContract? playbackController,
    Widget videoSurface = const SizedBox(),
    MediaLibraryRuntime? mediaLibraryRuntime,
    VideoDetailPageContract? videoDetailPageContract,
    RssEngineRuntime? rssEngineRuntime,
    BtTaskCoreRuntime? btTaskCoreRuntime,
    RssAutoDownloadPolicyStore? policyStore,
    SettingsRuntime? settingsRuntime,
    DiagnosticsRuntime? diagnosticsRuntime,
    UserProfileProvider? profileProvider,
    BangumiTrackingProvider? bangumiTrackingProvider,
    BangumiLoginController? bangumiLoginController,
    HomeRecommendationProvider? homeRecommendationProvider,
    HomeSearchProvider? homeSearchProvider,
  }) {
    return pumpApp(
      tester,
      playbackController: playbackController,
      videoSurface: videoSurface,
      mediaLibraryRuntime: mediaLibraryRuntime,
      videoDetailPageContract: videoDetailPageContract,
      rssEngineRuntime: rssEngineRuntime,
      btTaskCoreRuntime: btTaskCoreRuntime,
      policyStore: policyStore,
      settingsRuntime: settingsRuntime,
      diagnosticsRuntime: diagnosticsRuntime,
      profileProvider: profileProvider,
      bangumiTrackingProvider: bangumiTrackingProvider,
      bangumiLoginController: bangumiLoginController,
      homeRecommendationProvider: homeRecommendationProvider,
      homeSearchProvider: homeSearchProvider,
    );
  }

  static Future<void> pumpThemedWidget(
    WidgetTester tester, {
    required Widget child,
  }) async {
    await tester.pumpWidget(elainaTestHost(child: child));
    await tester.pump();
  }

  static Future<void> pumpSettingsWidget(
    WidgetTester tester, {
    required SettingsRuntime settingsRuntime,
    required Widget child,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ElainaThemeProvider(
          initialMode: ElainaThemeMode.dark,
          settingsRuntime: settingsRuntime,
          child: Scaffold(
            body: Material(child: child),
          ),
        ),
      ),
    );
    await tester.pump();
  }
}

final class ElainaAppFixture {
  ElainaAppFixture._({
    required this.tester,
    required _HarnessRuntimeBundle bundle,
  })  : playbackController = bundle.playbackController,
        mediaLibraryRuntime = bundle.mediaLibraryRuntime,
        videoDetailPageContract = bundle.videoDetailPageContract,
        rssEngineRuntime = bundle.rssEngineRuntime,
        btTaskCoreRuntime = bundle.btTaskCoreRuntime,
        policyStore = bundle.policyStore,
        settingsRuntime = bundle.settingsRuntime,
        diagnosticsRuntime = bundle.diagnosticsRuntime,
        downloadEngineAdapter = bundle.downloadEngineAdapter,
        _bundle = bundle;

  final WidgetTester tester;
  final PlaybackControllerContract playbackController;
  final MediaLibraryRuntime mediaLibraryRuntime;
  final VideoDetailPageContract videoDetailPageContract;
  final RssEngineRuntime rssEngineRuntime;
  final BtTaskCoreRuntime btTaskCoreRuntime;
  final RssAutoDownloadPolicyStore policyStore;
  final SettingsRuntime settingsRuntime;
  final DiagnosticsRuntime diagnosticsRuntime;
  final TestDownloadEngineAdapter downloadEngineAdapter;
  final _HarnessRuntimeBundle _bundle;

  ElainaRobots get robot => ElainaRobots(tester);

  Future<void> dispose() => _bundle.dispose();
}

final class _HarnessRuntimeBundle {
  _HarnessRuntimeBundle({
    required this.playbackController,
    required this.mediaLibraryRuntime,
    required this.videoDetailPageContract,
    required this.rssEngineRuntime,
    required this.btTaskCoreRuntime,
    required this.policyStore,
    required this.settingsRuntime,
    required this.diagnosticsRuntime,
    required this.downloadEngineAdapter,
    required this.ownsMediaLibraryRuntime,
    required this.ownsRssEngineRuntime,
    required this.ownsBtTaskCoreRuntime,
  });

  final PlaybackControllerContract playbackController;
  final MediaLibraryRuntime mediaLibraryRuntime;
  final VideoDetailPageContract videoDetailPageContract;
  final RssEngineRuntime rssEngineRuntime;
  final BtTaskCoreRuntime btTaskCoreRuntime;
  final RssAutoDownloadPolicyStore policyStore;
  final SettingsRuntime settingsRuntime;
  final DiagnosticsRuntime diagnosticsRuntime;
  final TestDownloadEngineAdapter downloadEngineAdapter;
  final bool ownsMediaLibraryRuntime;
  final bool ownsRssEngineRuntime;
  final bool ownsBtTaskCoreRuntime;

  static _HarnessRuntimeBundle create({
    PlaybackControllerContract? playbackController,
    MediaLibraryRuntime? mediaLibraryRuntime,
    VideoDetailPageContract? videoDetailPageContract,
    RssEngineRuntime? rssEngineRuntime,
    BtTaskCoreRuntime? btTaskCoreRuntime,
    RssAutoDownloadPolicyStore? policyStore,
    SettingsRuntime? settingsRuntime,
    DiagnosticsRuntime? diagnosticsRuntime,
  }) {
    final TestDownloadEngineAdapter downloadEngineAdapter =
        TestDownloadEngineAdapter();
    final RssAutoDownloadPolicyStore effectivePolicyStore =
        policyStore ?? DeterministicRssAutoDownloadPolicyStore();

    return _HarnessRuntimeBundle(
      playbackController: playbackController ?? _defaultPlaybackController(),
      mediaLibraryRuntime: mediaLibraryRuntime ?? _defaultMediaLibraryRuntime(),
      videoDetailPageContract:
          videoDetailPageContract ?? _defaultVideoDetailPageContract(),
      rssEngineRuntime:
          rssEngineRuntime ?? _defaultRssEngineRuntime(effectivePolicyStore),
      btTaskCoreRuntime: btTaskCoreRuntime ??
          BtTaskCoreRuntime.withDependencies(
            adapter: downloadEngineAdapter,
            store: DeterministicBtTaskStore(),
          ),
      policyStore: effectivePolicyStore,
      settingsRuntime: settingsRuntime ?? FakeSettingsRuntime(),
      diagnosticsRuntime: diagnosticsRuntime ?? FakeDiagnosticsRuntime(),
      downloadEngineAdapter: downloadEngineAdapter,
      ownsMediaLibraryRuntime: mediaLibraryRuntime == null,
      ownsRssEngineRuntime: rssEngineRuntime == null,
      ownsBtTaskCoreRuntime: btTaskCoreRuntime == null,
    );
  }

  Future<void> dispose() async {
    if (ownsMediaLibraryRuntime) mediaLibraryRuntime.dispose();
    if (ownsRssEngineRuntime) await rssEngineRuntime.dispose();
    if (ownsBtTaskCoreRuntime) await btTaskCoreRuntime.dispose();
    await downloadEngineAdapter.dispose();
  }
}

PlaybackControllerContract _defaultPlaybackController() {
  return MockPlaybackController(
    matrix: PlaybackCapabilityMatrix(
      capabilities: const <PlaybackCapability, CapabilityStatus>{
        PlaybackCapability.playPause: CapabilityStatus.supported(),
        PlaybackCapability.seek: CapabilityStatus.supported(),
        PlaybackCapability.stop: CapabilityStatus.supported(),
        PlaybackCapability.localFilePlayback: CapabilityStatus.supported(),
      },
    ),
  );
}

MediaLibraryRuntime _defaultMediaLibraryRuntime() {
  final DeterministicMediaLibraryCatalogRepository repository =
      DeterministicMediaLibraryCatalogRepository();
  return MediaLibraryRuntime(
    scanner: DeterministicMediaLibraryScanner(
      scanId: const MediaScanId(defaultTestScanId),
      candidates: const <MediaScanCandidate>[],
    ),
    catalogRepository: repository,
    importer: DeterministicMediaBatchImportContract(repository: repository),
    historyStore: DeterministicPlaybackHistoryStore(),
    bindingStore: DeterministicProviderBindingStore(),
    playbackSourceHandoff: const LocalPlaybackSourceHandoff(),
    invalidationBus: RecordingCacheInvalidationBus(),
  );
}

VideoDetailPageContract _defaultVideoDetailPageContract() {
  return VideoDetailPageContract(
    controller: VideoDetailController(
      repository: FakeVideoDetailRepository(
        initialData: const VideoDetailViewData(
          id: VideoDetailId('mock-detail'),
          title: 'Mock Title',
          episodes: <VideoDetailEpisode>[],
          followState: VideoFollowState.notFollowed,
          actions: VideoDetailActionSet(actions: <VideoDetailAction>[]),
        ),
      ),
      actions: FakeVideoDetailActionHandler(),
    ),
  );
}

RssEngineRuntime _defaultRssEngineRuntime(
  RssAutoDownloadPolicyStore policyStore,
) {
  return RssEngineRuntime(
    engine: FakeRssEngine(),
    store: DeterministicRssFeedStore(),
    scheduler: FakeFeedScheduler(),
    policyStore: policyStore,
  );
}

final class RecordingUserProfileProvider implements UserProfileProvider {
  const RecordingUserProfileProvider(this.snapshot);

  final UserProfileSnapshot? snapshot;

  @override
  Future<UserProfileSnapshot?> currentProfile() async => snapshot;
}

final class RecordingHomeRecommendationProvider
    implements HomeRecommendationProvider {
  RecordingHomeRecommendationProvider({
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

final class RecordingHomeSearchProvider implements HomeSearchProvider {
  RecordingHomeSearchProvider({
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

final class RecordingBangumiTrackingProvider
    implements BangumiTrackingProvider {
  RecordingBangumiTrackingProvider(this.snapshot);

  final BangumiTrackingSnapshot snapshot;
  int currentAnimeCollectionCalls = 0;

  @override
  Future<BangumiTrackingSnapshot> currentAnimeCollection() async {
    currentAnimeCollectionCalls++;
    return snapshot;
  }
}

final class TestDownloadEngineAdapter implements DownloadEngineAdapter {
  TestDownloadEngineAdapter({
    BtCapabilityMatrix? capabilities,
    this.includeMetadataFiles = false,
    this.failMetadata = false,
    this.failSelection = false,
  }) : capabilities = capabilities ?? supportedDownloadCapabilities;

  static const BtCapabilityMatrix supportedDownloadCapabilities =
      BtCapabilityMatrix(
    capabilities: <BtStreamingCapability, BtCapabilityStatus>{
      BtStreamingCapability.taskManagement: BtCapabilityStatus.supported(),
      BtStreamingCapability.metadataFetching: BtCapabilityStatus.supported(),
    },
  );

  static const BtCapabilityMatrix taskManagementWithoutMetadataCapabilities =
      BtCapabilityMatrix(
    capabilities: <BtStreamingCapability, BtCapabilityStatus>{
      BtStreamingCapability.taskManagement: BtCapabilityStatus.supported(),
      BtStreamingCapability.metadataFetching:
          BtCapabilityStatus.unsupported('Metadata projection unavailable.'),
    },
  );

  @override
  final BtCapabilityMatrix capabilities;

  final List<BtTaskId> pausedTasks = <BtTaskId>[];
  final List<BtTaskId> resumedTasks = <BtTaskId>[];
  final List<BtTaskId> removedTasks = <BtTaskId>[];
  final List<BtTaskCreateRequest> createdRequests = <BtTaskCreateRequest>[];
  final List<List<BtFileIndex>> selectedFiles = <List<BtFileIndex>>[];
  bool includeMetadataFiles;
  bool failMetadata;
  bool failSelection;

  final StreamController<BtTaskStatus> _statusController =
      StreamController<BtTaskStatus>.broadcast(sync: true);
  final StreamController<BtTaskEvent> _eventController =
      StreamController<BtTaskEvent>.broadcast(sync: true);
  int _createdTaskCounter = 0;

  @override
  String get displayName => defaultDownloadEngineName;

  @override
  String get id => defaultDownloadEngineId;

  @override
  Future<BtTaskId> createTask(BtTaskCreateRequest request) {
    createdRequests.add(request);
    _createdTaskCounter++;
    return Future<BtTaskId>.value(BtTaskId('task-$_createdTaskCounter'));
  }

  @override
  Future<BtTaskMetadata> ensureMetadata(BtTaskId taskId) {
    if (failMetadata) {
      throw StateError('metadata failed');
    }
    return Future<BtTaskMetadata>.value(BtTaskMetadata(
      infoHash: const InfoHash(defaultDownloadInfoHash),
      name: 'My Download Task',
      totalSizeBytes: 3072,
      pieceLengthBytes: defaultDownloadPieceLengthBytes,
      files: includeMetadataFiles
          ? const <BtTaskFile>[
              BtTaskFile(
                index: BtFileIndex(0),
                path: 'episode-1.mkv',
                lengthBytes: 3072,
                offsetBytes: 0,
                selectionState: BtFileSelectionState.skipped,
              ),
            ]
          : const <BtTaskFile>[],
    ));
  }

  @override
  Future<void> pause(BtTaskId taskId) async {
    pausedTasks.add(taskId);
  }

  @override
  Future<void> resume(BtTaskId taskId) async {
    resumedTasks.add(taskId);
  }

  @override
  Future<void> remove(BtTaskId taskId) async {
    removedTasks.add(taskId);
  }

  @override
  Future<void> selectFiles(BtTaskId taskId, Iterable<BtFileIndex> files) async {
    if (failSelection) {
      throw StateError('selection failed');
    }
    selectedFiles.add(<BtFileIndex>[...files]);
  }

  @override
  Stream<BtTaskEvent> watchEvents(BtTaskId taskId) {
    return _eventController.stream;
  }

  @override
  Stream<BtTaskStatus> watchStatus(BtTaskId taskId) {
    return _statusController.stream;
  }

  Future<void> dispose() async {
    await _statusController.close();
    await _eventController.close();
  }
}

StoredBtTaskRecord storedDownloadTask(
  String id,
  StoredBtTaskLifecycleState state,
) {
  return StoredBtTaskRecord(
    id: id,
    sourceKind: StoredBtTaskSourceKind.magnet,
    sourceUri: 'magnet:?xt=urn:btih:$id',
    lifecycleState: state,
    createdAt: defaultDownloadInstant,
    updatedAt: defaultDownloadInstant,
  );
}
