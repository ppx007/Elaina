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

final class _FakeDownloadEngineAdapter implements DownloadEngineAdapter {
  _FakeDownloadEngineAdapter() : capabilities = _supportedCapabilities();

  @override
  final BtCapabilityMatrix capabilities;

  final List<BtTaskId> pausedTasks = <BtTaskId>[];
  final List<BtTaskId> resumedTasks = <BtTaskId>[];
  final List<BtTaskId> removedTasks = <BtTaskId>[];
  final List<BtTaskCreateRequest> createdRequests = <BtTaskCreateRequest>[];
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
    });

    tearDown(() {
      fakeAdapter.dispose();
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

      // Verify task name is displayed
      expect(find.text('My Download Task'), findsOneWidget);
      expect(find.text('分片文件拼图 (Piece map)'), findsOneWidget);

      // Verify control buttons (Pause icon/tooltip/button)
      expect(find.byIcon(Icons.pause), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow),
          findsNothing); // It's currently downloading so show pause

      // Tap Pause
      await tester.tap(find.byIcon(Icons.pause));
      await tester.pumpAndSettle();
      expect(fakeAdapter.pausedTasks.length, 1);
      expect(fakeAdapter.pausedTasks.single.value, 'task-1');

      // Tap Remove (represented by delete icon)
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      expect(fakeAdapter.removedTasks.length, 1);
      expect(fakeAdapter.removedTasks.single.value, 'task-1');
    });

    testWidgets('creates a new download task from magnet input',
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

      await tester.tap(find.text('Add task'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Magnet or file URL'),
        'magnet:?xt=urn:btih:new-task',
      );
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(fakeAdapter.createdRequests, hasLength(1));
      expect(
          fakeAdapter.createdRequests.single.source, isA<MagnetBtTaskSource>());
      expect(find.text('My Download Task'), findsOneWidget);
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

      await tester.tap(find.text('Add task'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Magnet or file URL'),
        'magnet:?xt=urn:btih:metadata-warning',
      );
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(fakeAdapter.createdRequests, hasLength(1));
      expect(find.textContaining('metadata failed'), findsOneWidget);
      expect(find.text('Creating...'), findsNothing);
      expect(find.text('Add task'), findsOneWidget);
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

      await tester.tap(find.text('Add task'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Magnet or file URL'),
        'magnet:?xt=urn:btih:selection-warning',
      );
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(fakeAdapter.createdRequests, hasLength(1));
      expect(find.textContaining('selection failed'), findsOneWidget);
      expect(find.text('Creating...'), findsNothing);
      expect(find.text('Add task'), findsOneWidget);
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

      await tester.tap(find.text('Add task'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Magnet or file URL'),
        'magnet:?xt=urn:btih:runtime-error',
      );
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Create task failed'), findsOneWidget);
      expect(find.text('Creating...'), findsNothing);
      expect(find.text('Add task'), findsOneWidget);
    });
  });
}

final class _ThrowingDownloadRuntime implements DownloadRuntime {
  final DownloadRuntimeSnapshot _snapshot = DownloadRuntimeSnapshot(
    status: DownloadRuntimeStatus.idle,
    tasks: const <DownloadProjection>[],
  );

  @override
  DownloadRuntimeSnapshot get currentSnapshot => _snapshot;

  @override
  void addObserver(DownloadRuntimeObserver observer) {}

  @override
  void dispose() {}

  @override
  Future<DownloadCreateResult> createTaskFromUri(String sourceUri) {
    throw StateError('create exploded');
  }

  @override
  Future<void> listTasks() async {}

  @override
  Future<void> pause(DownloadTaskId taskId) async {}

  @override
  Future<void> remove(DownloadTaskId taskId) async {}

  @override
  void removeObserver(DownloadRuntimeObserver observer) {}

  @override
  Future<void> resume(DownloadTaskId taskId) async {}
}
