import 'dart:async';

import 'package:elaina/elaina.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DownloadRuntimeAdapter', () {
    test('rejects HTTP torrent URLs without creating a task', () async {
      final _DownloadHarness harness = _DownloadHarness();

      final DownloadCreateResult result = await harness.downloadRuntime
          .createTaskFromUri('https://example.com/anime.torrent');

      expect(result.isSuccess, isFalse);
      expect(result.failureMessage, contains('magnet'));
      expect(harness.adapter.createdRequests, isEmpty);
      await harness.close();
    });

    test('quick add selects every metadata file by default', () async {
      final _DownloadHarness harness = _DownloadHarness();

      final DownloadCreateResult result = await harness.downloadRuntime
          .createTaskFromUri('magnet:?xt=urn:btih:quick');

      expect(result.isSuccess, isTrue);
      expect(harness.adapter.createdRequests.single.source,
          isA<MagnetBtTaskSource>());
      expect(
        harness.adapter.selectedFiles.single
            .map((BtFileIndex file) => file.value),
        <int>[0, 1],
      );
      expect(result.task?.files, hasLength(2));
      await harness.close();
    });

    test('advanced add pauses and waits for explicit file selection', () async {
      final _DownloadHarness harness = _DownloadHarness();

      final DownloadCreateResult result =
          await harness.downloadRuntime.createTaskFromUri(
        'magnet:?xt=urn:btih:advanced',
        mode: DownloadCreateMode.advanced,
      );

      expect(result.isSuccess, isTrue);
      expect(harness.adapter.pausedTasks.single.value, 'task-1');
      expect(harness.adapter.selectedFiles, isEmpty);
      expect(result.task?.files, hasLength(2));

      final DownloadCommandResult emptySelection = await harness.downloadRuntime
          .selectFiles(
              const DownloadTaskId('task-1'), const <DownloadFileIndex>[]);
      expect(emptySelection.isSuccess, isFalse);

      final DownloadCommandResult selected =
          await harness.downloadRuntime.selectFiles(
        const DownloadTaskId('task-1'),
        const <DownloadFileIndex>[DownloadFileIndex(1)],
      );
      expect(selected.isSuccess, isTrue);
      expect(harness.adapter.selectedFiles.single.single.value, 1);
      await harness.close();
    });

    test('batch commands only target actionable tasks', () async {
      final DateTime now = DateTime.utc(2026, 6, 21, 12);
      final _DownloadHarness pauseHarness = _DownloadHarness(
        seedTasks: <StoredBtTaskRecord>[
          _storedTask(
              'downloading', StoredBtTaskLifecycleState.downloading, now),
          _storedTask('ready', StoredBtTaskLifecycleState.ready, now),
          _storedTask('paused', StoredBtTaskLifecycleState.paused, now),
          _storedTask('completed', StoredBtTaskLifecycleState.completed, now),
          _storedTask('failed', StoredBtTaskLifecycleState.failed, now),
        ],
      );
      await pauseHarness.downloadRuntime.listTasks();

      final DownloadCommandResult pauseAll =
          await pauseHarness.downloadRuntime.pauseAll();

      expect(pauseAll.isSuccess, isTrue);
      expect(
        pauseHarness.adapter.pausedTasks.map((BtTaskId taskId) => taskId.value),
        <String>['downloading', 'ready'],
      );
      await pauseHarness.close();

      final _DownloadHarness resumeHarness = _DownloadHarness(
        seedTasks: <StoredBtTaskRecord>[
          _storedTask('queued', StoredBtTaskLifecycleState.queued, now),
          _storedTask('ready', StoredBtTaskLifecycleState.ready, now),
          _storedTask('paused', StoredBtTaskLifecycleState.paused, now),
          _storedTask(
              'downloading', StoredBtTaskLifecycleState.downloading, now),
          _storedTask('completed', StoredBtTaskLifecycleState.completed, now),
        ],
      );
      await resumeHarness.downloadRuntime.listTasks();

      final DownloadCommandResult resumeAll =
          await resumeHarness.downloadRuntime.resumeAll();

      expect(resumeAll.isSuccess, isTrue);
      expect(
        resumeHarness.adapter.resumedTasks
            .map((BtTaskId taskId) => taskId.value),
        <String>['queued', 'ready', 'paused'],
      );
      await resumeHarness.close();
    });

    test('maps management projection fields from BT runtime', () async {
      final DateTime now = DateTime.utc(2026, 6, 21, 12);
      final DeterministicBtTaskStore store = DeterministicBtTaskStore(
        seedTasks: <StoredBtTaskRecord>[
          _storedTask(
            'task-1',
            StoredBtTaskLifecycleState.downloading,
            now,
            infoHash: 'projection-hash',
          ),
        ],
      );
      await store.storeMetadata(const StoredBtTaskMetadataRecord(
        taskId: 'task-1',
        infoHash: 'projection-hash',
        name: 'Projection Pack',
        totalSizeBytes: 4096,
        pieceLengthBytes: 1024,
      ));
      await store.storeFiles(
        taskId: 'task-1',
        files: const <StoredBtTaskFileRecord>[
          StoredBtTaskFileRecord(
            taskId: 'task-1',
            index: 0,
            path: 'Season/Episode 01.mkv',
            lengthBytes: 4096,
            offsetBytes: 0,
            selectionState: StoredBtFileSelectionState.selected,
            mediaMimeType: 'video/x-matroska',
          ),
        ],
      );
      await store.storeTransferSnapshot(StoredBtTaskTransferSnapshotRecord(
        taskId: 'task-1',
        lifecycleState: StoredBtTaskLifecycleState.downloading,
        progress: 0.75,
        downloadRateBytesPerSecond: 2048,
        uploadRateBytesPerSecond: 512,
        connectedPeers: 4,
        observedAt: now,
        message: 'transfer message',
      ));
      await store.recordEvent(StoredBtTaskEventRecord(
        taskId: 'task-1',
        eventKind: StoredBtTaskEventKind.failed,
        occurredAt: now,
        message: 'latest failure',
      ));
      final _DownloadHarness harness = _DownloadHarness(store: store);

      await harness.downloadRuntime.listTasks();
      final DownloadProjection task =
          harness.downloadRuntime.currentSnapshot.tasks.single;

      expect(task.name, 'Projection Pack');
      expect(task.sourceKind, DownloadTaskSourceKind.magnet);
      expect(task.infoHash, 'projection-hash');
      expect(task.pieceLengthBytes, 1024);
      expect(task.progress, 0.75);
      expect(task.uploadRateBytesPerSecond, 512);
      expect(task.connectedPeers, 4);
      expect(task.latestEvent, 'latest failure');
      expect(task.files.single.name, 'Episode 01.mkv');
      expect(task.files.single.isSelected, isTrue);
      expect(
          harness.downloadRuntime.currentSnapshot.capabilities.canCreateTasks,
          isTrue);
      await harness.close();
    });
  });
}

final class _DownloadHarness {
  _DownloadHarness({
    DeterministicBtTaskStore? store,
    Iterable<StoredBtTaskRecord> seedTasks = const <StoredBtTaskRecord>[],
  })  : adapter = _FakeDownloadEngineAdapter(),
        store = store ?? DeterministicBtTaskStore(seedTasks: seedTasks) {
    btRuntime = BtTaskCoreRuntime.withDependencies(
      adapter: adapter,
      store: this.store,
    );
    downloadRuntime = DownloadRuntimeAdapter(btRuntime);
  }

  final _FakeDownloadEngineAdapter adapter;
  final DeterministicBtTaskStore store;
  late final BtTaskCoreRuntime btRuntime;
  late final DownloadRuntimeAdapter downloadRuntime;

  Future<void> close() async {
    downloadRuntime.dispose();
  }
}

final class _FakeDownloadEngineAdapter implements DownloadEngineAdapter {
  _FakeDownloadEngineAdapter();

  @override
  BtCapabilityMatrix get capabilities => const BtCapabilityMatrix(
        capabilities: <BtStreamingCapability, BtCapabilityStatus>{
          BtStreamingCapability.taskManagement: BtCapabilityStatus.supported(),
          BtStreamingCapability.metadataFetching:
              BtCapabilityStatus.supported(),
          BtStreamingCapability.longBackgroundDownload:
              BtCapabilityStatus.supported(),
          BtStreamingCapability.virtualMediaStream:
              BtCapabilityStatus.supported(),
        },
      );

  final List<BtTaskCreateRequest> createdRequests = <BtTaskCreateRequest>[];
  final List<BtTaskId> pausedTasks = <BtTaskId>[];
  final List<BtTaskId> resumedTasks = <BtTaskId>[];
  final List<List<BtFileIndex>> selectedFiles = <List<BtFileIndex>>[];
  int _nextTaskId = 1;

  @override
  String get displayName => 'Fake Download Engine';

  @override
  String get id => 'fake-download-engine';

  @override
  Future<BtTaskId> createTask(BtTaskCreateRequest request) {
    createdRequests.add(request);
    return Future<BtTaskId>.value(BtTaskId('task-${_nextTaskId++}'));
  }

  @override
  Future<BtTaskMetadata> ensureMetadata(BtTaskId taskId) {
    return Future<BtTaskMetadata>.value(const BtTaskMetadata(
      infoHash: InfoHash('metadata-hash'),
      name: 'Metadata Pack',
      totalSizeBytes: 3072,
      pieceLengthBytes: 1024,
      files: <BtTaskFile>[
        BtTaskFile(
          index: BtFileIndex(0),
          path: 'Episode 01.mkv',
          lengthBytes: 1024,
          offsetBytes: 0,
          selectionState: BtFileSelectionState.skipped,
          mediaMimeType: 'video/x-matroska',
        ),
        BtTaskFile(
          index: BtFileIndex(1),
          path: 'Episode 02.mkv',
          lengthBytes: 2048,
          offsetBytes: 1024,
          selectionState: BtFileSelectionState.skipped,
          mediaMimeType: 'video/x-matroska',
        ),
      ],
    ));
  }

  @override
  Future<void> pause(BtTaskId taskId) async {
    pausedTasks.add(taskId);
  }

  @override
  Future<void> remove(BtTaskId taskId) async {}

  @override
  Future<void> resume(BtTaskId taskId) async {
    resumedTasks.add(taskId);
  }

  @override
  Future<void> selectFiles(BtTaskId taskId, Iterable<BtFileIndex> files) async {
    selectedFiles.add(<BtFileIndex>[...files]);
  }

  @override
  Stream<BtTaskEvent> watchEvents(BtTaskId taskId) => const Stream.empty();

  @override
  Stream<BtTaskStatus> watchStatus(BtTaskId taskId) => const Stream.empty();
}

StoredBtTaskRecord _storedTask(
  String id,
  StoredBtTaskLifecycleState state,
  DateTime now, {
  String? infoHash,
}) {
  return StoredBtTaskRecord(
    id: id,
    sourceKind: StoredBtTaskSourceKind.magnet,
    sourceUri: 'magnet:?xt=urn:btih:$id',
    lifecycleState: state,
    createdAt: now,
    updatedAt: now,
    infoHash: infoHash,
  );
}
