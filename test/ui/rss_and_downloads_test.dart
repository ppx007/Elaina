import 'dart:async';

import 'package:elaina/elaina.dart';
import 'package:elaina/src/ui/download/downloads_page.dart';
import 'package:elaina/src/ui/rss/rss_page.dart';
import 'package:elaina/src/ui/theme/elaina_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

class _FakeRssEngine implements RssEngineContract {
  _FakeRssEngine(this.store);

  final RssFeedStore store;
  final List<FeedSource> registered = <FeedSource>[];
  final StreamController<FeedItem> _updatesController =
      StreamController<FeedItem>.broadcast();

  @override
  Future<void> registerSource(FeedSource source) async {
    registered.add(source);
    await store.storeSource(
      StoredFeedSourceRecord(
        id: source.id.value,
        displayName: source.displayName,
        uri: source.uri,
        format: source.format.name,
        refreshInterval: source.refreshInterval,
      ),
    );
  }

  @override
  Future<RssRefreshOutcome> refreshSource(RssRefreshRequest request) async {
    return RssRefreshOutcome.success(
      sourceId: request.sourceId,
      newItems: const <FeedItem>[],
    );
  }

  @override
  Stream<FeedItem> get updates => _updatesController.stream;

  void dispose() {
    _updatesController.close();
  }
}

class _FakeFeedScheduler implements FeedScheduler {
  @override
  Stream<FeedScheduleDecision> dueSources(Iterable<FeedSource> sources) =>
      const Stream<FeedScheduleDecision>.empty();
}

BtCapabilityMatrix _supportedCapabilities() {
  return const BtCapabilityMatrix(
    capabilities: <BtStreamingCapability, BtCapabilityStatus>{
      BtStreamingCapability.taskManagement: BtCapabilityStatus.supported(),
      BtStreamingCapability.metadataFetching: BtCapabilityStatus.supported(),
    },
  );
}

BtCapabilityMatrix _taskManagementWithoutMetadataCapabilities() {
  return const BtCapabilityMatrix(
    capabilities: <BtStreamingCapability, BtCapabilityStatus>{
      BtStreamingCapability.taskManagement: BtCapabilityStatus.supported(),
      BtStreamingCapability.metadataFetching:
          BtCapabilityStatus.unsupported('Metadata projection unavailable.'),
    },
  );
}

final DateTime _downloadTestInstant = DateTime.utc(2026, 6, 21, 12);

StoredBtTaskRecord _storedDownloadTask(
  String id,
  StoredBtTaskLifecycleState state,
) {
  return StoredBtTaskRecord(
    id: id,
    sourceKind: StoredBtTaskSourceKind.magnet,
    sourceUri: 'magnet:?xt=urn:btih:$id',
    lifecycleState: state,
    createdAt: _downloadTestInstant,
    updatedAt: _downloadTestInstant,
  );
}

DownloadRuntimeAdapter _downloadRuntimeFor({
  required _FakeDownloadEngineAdapter adapter,
  Iterable<StoredBtTaskRecord> seedTasks = const <StoredBtTaskRecord>[],
}) {
  final BtTaskCoreRuntime runtime = BtTaskCoreRuntime.withDependencies(
    adapter: adapter,
    store: DeterministicBtTaskStore(seedTasks: seedTasks),
  );
  return DownloadRuntimeAdapter(runtime);
}

Finder _filledButtonWithIcon(IconData icon) {
  return find.ancestor(
    of: find.byIcon(icon),
    matching: find.byType(FilledButton),
  );
}

Finder _outlinedButtonWithIcon(IconData icon) {
  return find.ancestor(
    of: find.byIcon(icon),
    matching: find.byType(OutlinedButton),
  );
}

final class _FakeDownloadEngineAdapter implements DownloadEngineAdapter {
  _FakeDownloadEngineAdapter({BtCapabilityMatrix? capabilities})
      : capabilities = capabilities ?? _supportedCapabilities();

  @override
  final BtCapabilityMatrix capabilities;

  final List<BtTaskId> pausedTasks = <BtTaskId>[];
  final List<BtTaskId> resumedTasks = <BtTaskId>[];
  final List<BtTaskId> removedTasks = <BtTaskId>[];
  final List<BtTaskCreateRequest> createdRequests = <BtTaskCreateRequest>[];
  final List<List<BtFileIndex>> selectedFiles = <List<BtFileIndex>>[];
  bool failMetadata = false;
  bool includeMetadataFiles = false;
  bool failSelection = false;

  final StreamController<BtTaskStatus> _statusController =
      StreamController<BtTaskStatus>.broadcast(sync: true);
  final StreamController<BtTaskEvent> _eventController =
      StreamController<BtTaskEvent>.broadcast(sync: true);

  @override
  String get displayName => 'Fake Download Engine';

  @override
  String get id => 'fake-download-engine';

  @override
  Future<BtTaskId> createTask(BtTaskCreateRequest request) {
    createdRequests.add(request);
    return Future<BtTaskId>.value(const BtTaskId('task-1'));
  }

  @override
  Future<BtTaskMetadata> ensureMetadata(BtTaskId taskId) {
    if (failMetadata) {
      throw StateError('metadata failed');
    }
    return Future<BtTaskMetadata>.value(BtTaskMetadata(
      infoHash: InfoHash('abc'),
      name: 'My Download Task',
      totalSizeBytes: 3072,
      pieceLengthBytes: 1024,
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
  Stream<BtTaskEvent> watchEvents(BtTaskId taskId) => _eventController.stream;

  @override
  Stream<BtTaskStatus> watchStatus(BtTaskId taskId) => _statusController.stream;

  void dispose() {
    _statusController.close();
    _eventController.close();
  }
}

void main() {
  group('RssPage Widget Tests', () {
    late _FakeRssEngine fakeEngine;
    late DeterministicRssFeedStore feedStore;
    late RssEngineRuntime rssEngineRuntime;
    late DeterministicRssAutoDownloadPolicyStore policyStore;

    setUp(() {
      feedStore = DeterministicRssFeedStore();
      fakeEngine = _FakeRssEngine(feedStore);
      policyStore = DeterministicRssAutoDownloadPolicyStore();
      rssEngineRuntime = RssEngineRuntime(
        engine: fakeEngine,
        store: feedStore,
        scheduler: _FakeFeedScheduler(),
        policyStore: policyStore,
      );
    });

    tearDown(() {
      fakeEngine.dispose();
    });

    testWidgets('renders RSS Page and shows empty state',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _testHost(
          child: Scaffold(
            body: RssPage(
              rssEngineRuntime: rssEngineRuntime,
            ),
          ),
        ),
      );

      expect(
          find.text('已订阅 Graves 的 RSS 源', skipOffstage: false), findsNothing);
      expect(find.text('已订阅的 RSS 源'), findsOneWidget);
      expect(find.text('暂无订阅，请点击“添加订阅”按钮。'), findsOneWidget);
    });

    testWidgets('adds a new RSS source via dialog',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _testHost(
          child: Scaffold(
            body: RssPage(
              rssEngineRuntime: rssEngineRuntime,
            ),
          ),
        ),
      );

      // Open Add dialog
      await tester.tap(find.text('添加订阅'));
      await tester.pumpAndSettle();

      expect(find.text('订阅新 RSS 源'), findsOneWidget);

      // Fill in details
      await tester.enterText(
          find.widgetWithText(TextField, '订阅源名称'), 'My Anime Feed');
      await tester.enterText(find.widgetWithText(TextField, 'RSS URL 地址'),
          'https://anime.com/feed.xml');

      // Click subscribe
      await tester.tap(find.text('订阅'));
      await tester.pumpAndSettle();

      // Check registered feed source in backend fake
      expect(fakeEngine.registered.length, 1);
      expect(fakeEngine.registered.single.displayName, 'My Anime Feed');
      expect(fakeEngine.registered.single.uri.toString(),
          'https://anime.com/feed.xml');
    });

    testWidgets('shows validation error for invalid RSS URL',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _testHost(
          child: Scaffold(
            body: RssPage(
              rssEngineRuntime: rssEngineRuntime,
            ),
          ),
        ),
      );

      await tester.tap(find.text('添加订阅'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextField, '订阅源名称'), 'Invalid Feed');
      await tester.enterText(
          find.widgetWithText(TextField, 'RSS URL 地址'), 'not-a-feed-url');

      await tester.tap(find.text('订阅'));
      await tester.pumpAndSettle();

      expect(find.text('RSS URL 必须是 http 或 https 地址'), findsOneWidget);
      expect(fakeEngine.registered, isEmpty);
      expect(find.text('订阅新 RSS 源'), findsOneWidget);
    });
  });

  group('DownloadsPage Widget Tests', () {
    late _FakeDownloadEngineAdapter fakeAdapter;
    late DeterministicBtTaskStore btStore;
    late BtTaskCoreRuntime btTaskCoreRuntime;

    setUp(() async {
      fakeAdapter = _FakeDownloadEngineAdapter();
      btStore = DeterministicBtTaskStore();
      btTaskCoreRuntime = BtTaskCoreRuntime.withDependencies(
        adapter: fakeAdapter,
        store: btStore,
      );

      // Pre-seed a download task in database
      await btStore.storeTask(
        StoredBtTaskRecord(
          id: 'task-1',
          sourceKind: StoredBtTaskSourceKind.magnet,
          sourceUri: 'magnet:?xt=urn:btih:abc',
          lifecycleState: StoredBtTaskLifecycleState.downloading,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      await btStore.storeMetadata(
        const StoredBtTaskMetadataRecord(
          taskId: 'task-1',
          infoHash: 'abc',
          name: 'My Download Task',
          pieceLengthBytes: 16384,
          totalSizeBytes: 1024 * 1024,
        ),
      );
      await btStore.storeFiles(
        taskId: 'task-1',
        files: const <StoredBtTaskFileRecord>[
          StoredBtTaskFileRecord(
            taskId: 'task-1',
            index: 0,
            path: 'Season 1/Episode 01.mkv',
            lengthBytes: 1024 * 1024,
            offsetBytes: 0,
            selectionState: StoredBtFileSelectionState.selected,
            mediaMimeType: 'video/x-matroska',
          ),
        ],
      );
      await btStore.storeTransferSnapshot(
        StoredBtTaskTransferSnapshotRecord(
          taskId: 'task-1',
          lifecycleState: StoredBtTaskLifecycleState.downloading,
          progress: 0.5,
          downloadRateBytesPerSecond: 2048,
          uploadRateBytesPerSecond: 512,
          connectedPeers: 3,
          observedAt: DateTime.utc(2026, 6, 21, 12),
          message: 'running',
        ),
      );
    });

    tearDown(() {
      fakeAdapter.dispose();
    });

    testWidgets(
        'keeps add enabled without metadata capability and disables empty batch actions',
        (WidgetTester tester) async {
      final _FakeDownloadEngineAdapter localAdapter =
          _FakeDownloadEngineAdapter(
        capabilities: _taskManagementWithoutMetadataCapabilities(),
      );
      final DownloadRuntimeAdapter runtime = _downloadRuntimeFor(
        adapter: localAdapter,
      );
      addTearDown(runtime.dispose);
      addTearDown(localAdapter.dispose);

      await tester.pumpWidget(
        _testHost(
          child: Scaffold(
            body: DownloadsPage(downloadRuntime: runtime),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<FilledButton>(
              _filledButtonWithIcon(Icons.add_link),
            )
            .onPressed,
        isNotNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              _outlinedButtonWithIcon(Icons.pause),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              _outlinedButtonWithIcon(Icons.play_arrow),
            )
            .onPressed,
        isNull,
      );
    });

    testWidgets('enables pause all only when a pausable task exists',
        (WidgetTester tester) async {
      final _FakeDownloadEngineAdapter localAdapter =
          _FakeDownloadEngineAdapter();
      final DownloadRuntimeAdapter runtime = _downloadRuntimeFor(
        adapter: localAdapter,
        seedTasks: <StoredBtTaskRecord>[
          _storedDownloadTask(
            'downloading',
            StoredBtTaskLifecycleState.downloading,
          ),
        ],
      );
      addTearDown(runtime.dispose);
      addTearDown(localAdapter.dispose);

      await tester.pumpWidget(
        _testHost(
          child: Scaffold(
            body: DownloadsPage(downloadRuntime: runtime),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<OutlinedButton>(
              _outlinedButtonWithIcon(Icons.pause),
            )
            .onPressed,
        isNotNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              _outlinedButtonWithIcon(Icons.play_arrow),
            )
            .onPressed,
        isNull,
      );
    });

    testWidgets('enables resume all only when a resumable task exists',
        (WidgetTester tester) async {
      final _FakeDownloadEngineAdapter localAdapter =
          _FakeDownloadEngineAdapter();
      final DownloadRuntimeAdapter runtime = _downloadRuntimeFor(
        adapter: localAdapter,
        seedTasks: <StoredBtTaskRecord>[
          _storedDownloadTask('paused', StoredBtTaskLifecycleState.paused),
        ],
      );
      addTearDown(runtime.dispose);
      addTearDown(localAdapter.dispose);

      await tester.pumpWidget(
        _testHost(
          child: Scaffold(
            body: DownloadsPage(downloadRuntime: runtime),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<OutlinedButton>(
              _outlinedButtonWithIcon(Icons.pause),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              _outlinedButtonWithIcon(Icons.play_arrow),
            )
            .onPressed,
        isNotNull,
      );
    });

    testWidgets(
        'renders download task list and responds to pause/resume/remove actions',
        (WidgetTester tester) async {
      // Start/load the tasks
      await btTaskCoreRuntime.listTasks();

      await tester.pumpWidget(
        _testHost(
          child: Scaffold(
            body: DownloadsPage(
              downloadRuntime: DownloadRuntimeAdapter(btTaskCoreRuntime),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('下载'), findsWidgets);
      expect(find.text('My Download Task'), findsWidgets);
      expect(find.text('2.0 KiB/s / 512 B/s'), findsOneWidget);
      await tester.drag(
        find.byKey(const ValueKey<String>('download-detail-scroll')),
        const Offset(0, -260),
      );
      await tester.pumpAndSettle();
      expect(find.text('文件'), findsOneWidget);
      expect(find.textContaining('Episode 01.mkv'), findsOneWidget);

      await tester.tap(find.byTooltip('暂停'));
      await tester.pumpAndSettle();
      expect(fakeAdapter.pausedTasks.length, 1);
      expect(fakeAdapter.pausedTasks.single.value, 'task-1');

      await tester.tap(find.byTooltip('删除任务'));
      await tester.pumpAndSettle();
      expect(find.text('删除下载任务'), findsOneWidget);
      await tester.tap(find.text('删除任务'));
      await tester.pumpAndSettle();
      expect(fakeAdapter.removedTasks.length, 1);
      expect(fakeAdapter.removedTasks.single.value, 'task-1');
    });

    testWidgets('creates a new download task from magnet input',
        (WidgetTester tester) async {
      fakeAdapter.includeMetadataFiles = true;
      await tester.pumpWidget(
        _testHost(
          child: Scaffold(
            body: DownloadsPage(
              downloadRuntime: DownloadRuntimeAdapter(btTaskCoreRuntime),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('添加'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Magnet 或本地 torrent 文件 URI'),
        'magnet:?xt=urn:btih:new-task',
      );
      await tester.tap(find.text('创建'));
      await tester.pumpAndSettle();

      expect(fakeAdapter.createdRequests, hasLength(1));
      expect(
          fakeAdapter.createdRequests.single.source, isA<MagnetBtTaskSource>());
      expect(fakeAdapter.selectedFiles.single.single.value, 0);
      expect(find.text('My Download Task'), findsWidgets);
    });

    testWidgets('advanced add pauses task and requires a file selection',
        (WidgetTester tester) async {
      fakeAdapter.includeMetadataFiles = true;

      await tester.pumpWidget(
        _testHost(
          child: Scaffold(
            body: DownloadsPage(
              downloadRuntime: DownloadRuntimeAdapter(btTaskCoreRuntime),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('添加'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('高级添加'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Magnet 或本地 torrent 文件 URI'),
        'magnet:?xt=urn:btih:advanced-task',
      );
      await tester.tap(find.text('创建'));
      await tester.pumpAndSettle();

      expect(fakeAdapter.pausedTasks.single.value, 'task-1');
      expect(find.textContaining('选择文件：My Download Task'), findsOneWidget);
      await tester.tap(find.byType(CheckboxListTile).first);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, '确认选择'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byType(CheckboxListTile).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认选择'));
      await tester.pumpAndSettle();

      expect(fakeAdapter.selectedFiles.single.single.value, 0);
      expect(fakeAdapter.resumedTasks.single.value, 'task-1');
    });

    testWidgets('rejects HTTP torrent URL before creating a task',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _testHost(
          child: Scaffold(
            body: DownloadsPage(
              downloadRuntime: DownloadRuntimeAdapter(btTaskCoreRuntime),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('添加'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Magnet 或本地 torrent 文件 URI'),
        'https://example.com/anime.torrent',
      );
      await tester.tap(find.text('创建'));
      await tester.pumpAndSettle();

      expect(
        find.text('仅支持 magnet 链接或本地 .torrent 文件 URI。'),
        findsOneWidget,
      );
      expect(fakeAdapter.createdRequests, isEmpty);
    });

    testWidgets('surfaces metadata failure as a partial create warning',
        (WidgetTester tester) async {
      fakeAdapter.failMetadata = true;

      await tester.pumpWidget(
        _testHost(
          child: Scaffold(
            body: DownloadsPage(
              downloadRuntime: DownloadRuntimeAdapter(btTaskCoreRuntime),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('添加'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Magnet 或本地 torrent 文件 URI'),
        'magnet:?xt=urn:btih:metadata-warning',
      );
      await tester.tap(find.text('创建'));
      await tester.pumpAndSettle();

      expect(fakeAdapter.createdRequests, hasLength(1));
      expect(find.textContaining('metadata failed'), findsOneWidget);
      expect(find.text('添加中'), findsNothing);
      expect(find.text('添加'), findsWidgets);
    });

    testWidgets('surfaces file selection failure as a partial create warning',
        (WidgetTester tester) async {
      fakeAdapter.includeMetadataFiles = true;
      fakeAdapter.failSelection = true;

      await tester.pumpWidget(
        _testHost(
          child: Scaffold(
            body: DownloadsPage(
              downloadRuntime: DownloadRuntimeAdapter(btTaskCoreRuntime),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('添加'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Magnet 或本地 torrent 文件 URI'),
        'magnet:?xt=urn:btih:selection-warning',
      );
      await tester.tap(find.text('创建'));
      await tester.pumpAndSettle();

      expect(fakeAdapter.createdRequests, hasLength(1));
      expect(find.textContaining('selection failed'), findsOneWidget);
      expect(find.text('添加中'), findsNothing);
      expect(find.text('添加'), findsWidgets);
    });

    testWidgets('restores create button after unexpected runtime failure',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _testHost(
          child: Scaffold(
            body: DownloadsPage(
              downloadRuntime: _ThrowingDownloadRuntime(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('添加'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Magnet 或本地 torrent 文件 URI'),
        'magnet:?xt=urn:btih:runtime-error',
      );
      await tester.tap(find.text('创建'));
      await tester.pumpAndSettle();

      expect(find.textContaining('创建下载任务失败'), findsOneWidget);
      expect(find.text('添加中'), findsNothing);
      expect(find.text('添加'), findsWidgets);
    });
  });
}

final class _ThrowingDownloadRuntime implements DownloadRuntime {
  final DownloadRuntimeSnapshot _snapshot = DownloadRuntimeSnapshot(
    status: DownloadRuntimeStatus.idle,
    tasks: const <DownloadProjection>[],
    capabilities: const DownloadCapabilityProjection(
      taskManagementAvailable: true,
      metadataFetchingAvailable: true,
      backgroundDownloadAvailable: false,
      virtualStreamAvailable: false,
    ),
  );

  @override
  DownloadRuntimeSnapshot get currentSnapshot => _snapshot;

  @override
  void addObserver(DownloadRuntimeObserver observer) {}

  @override
  void dispose() {}

  @override
  Future<DownloadCreateResult> createTaskFromUri(
    String sourceUri, {
    DownloadCreateMode mode = DownloadCreateMode.quick,
  }) {
    throw StateError('create exploded');
  }

  @override
  Future<void> listTasks() async {}

  @override
  Future<DownloadCommandResult> pause(DownloadTaskId taskId) async =>
      const DownloadCommandResult.success();

  @override
  Future<DownloadCommandResult> pauseAll() async =>
      const DownloadCommandResult.success();

  @override
  Future<DownloadCommandResult> remove(DownloadTaskId taskId) async =>
      const DownloadCommandResult.success();

  @override
  void removeObserver(DownloadRuntimeObserver observer) {}

  @override
  Future<DownloadCommandResult> resume(DownloadTaskId taskId) async =>
      const DownloadCommandResult.success();

  @override
  Future<DownloadCommandResult> resumeAll() async =>
      const DownloadCommandResult.success();

  @override
  Future<DownloadCommandResult> selectFiles(
    DownloadTaskId taskId,
    Iterable<DownloadFileIndex> files,
  ) async =>
      const DownloadCommandResult.success();
}
