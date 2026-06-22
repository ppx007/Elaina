import 'dart:async';

// BT task core contract tests define task/file/event projections before any
// concrete engine adapter is allowed to implement them.
// Adapter tests should conform to these projections, not redefine them.
import 'package:elaina/elaina.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('BT task store persists task metadata files snapshots and events',
      () async {
    final DeterministicBtTaskStore store = DeterministicBtTaskStore();
    final DateTime createdAt = DateTime.utc(2026, 6, 5, 12);

    await store.storeTask(
      StoredBtTaskRecord(
        id: 'task-1',
        sourceKind: StoredBtTaskSourceKind.magnet,
        sourceUri: 'magnet:?xt=urn:btih:abc',
        lifecycleState: StoredBtTaskLifecycleState.queued,
        createdAt: createdAt,
        updatedAt: createdAt,
      ),
    );
    await store.storeMetadata(
      const StoredBtTaskMetadataRecord(
        taskId: 'task-1',
        infoHash: 'abc',
        name: 'Episode 1',
        totalSizeBytes: 1024,
        pieceLengthBytes: 256,
      ),
    );
    await store.storeFiles(
      taskId: 'task-1',
      files: const <StoredBtTaskFileRecord>[
        StoredBtTaskFileRecord(
          taskId: 'task-1',
          index: 0,
          path: 'Episode 1.mkv',
          lengthBytes: 1024,
          offsetBytes: 0,
          selectionState: StoredBtFileSelectionState.selected,
        ),
      ],
    );
    await store.storeTransferSnapshot(
      StoredBtTaskTransferSnapshotRecord(
        taskId: 'task-1',
        lifecycleState: StoredBtTaskLifecycleState.downloading,
        progress: 0.5,
        downloadRateBytesPerSecond: 4096,
        uploadRateBytesPerSecond: 512,
        connectedPeers: 3,
        observedAt: createdAt,
      ),
    );
    await store.recordEvent(
      StoredBtTaskEventRecord(
        taskId: 'task-1',
        eventKind: StoredBtTaskEventKind.pieceCompleted,
        occurredAt: createdAt,
        pieceIndex: 1,
      ),
    );

    expect((await store.findTaskById('task-1'))?.sourceUri,
        'magnet:?xt=urn:btih:abc');
    expect((await store.metadataFor('task-1'))?.infoHash, 'abc');
    expect((await store.filesFor('task-1')).single.path, 'Episode 1.mkv');
    expect((await store.latestTransferSnapshot('task-1'))?.progress, 0.5);
    expect((await store.latestEvent('task-1'))?.pieceIndex, 1);
    expect(await store.count(), 1);
    expect(await store.removeTask('task-1'), isTrue);
    expect(await store.findTaskById('task-1'), isNull);
  });

  test('BT task core creates tasks through adapter and publishes cache events',
      () async {
    final _FakeDownloadEngineAdapter adapter = _FakeDownloadEngineAdapter();
    final DeterministicBtTaskStore store = DeterministicBtTaskStore();
    final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
    final DeterministicBtTaskCore core = DeterministicBtTaskCore(
      adapter: adapter,
      store: store,
      cacheInvalidationBus: bus,
      clock: () => DateTime.utc(2026, 6, 5, 12),
    );

    final Future<CacheInvalidationEvent> event = bus.events.first;
    final BtTaskCreateOutcome outcome = await core.createTask(
      const BtTaskCreateRequest(
        source: MagnetBtTaskSource(uri: 'magnet:?xt=urn:btih:abc'),
      ),
    );
    final CacheInvalidationEvent delivered = await event;

    expect(outcome.isSuccess, isTrue);
    expect(outcome.taskId?.value, 'task-1');
    expect(adapter.createdRequests.single.source, isA<MagnetBtTaskSource>());
    expect((await store.findTaskById('task-1'))?.lifecycleState,
        StoredBtTaskLifecycleState.queued);
    expect(delivered, isA<BtTaskCreated>());
    await bus.close();
  });

  test('BT task core persists metadata and file selections', () async {
    final _FakeDownloadEngineAdapter adapter = _FakeDownloadEngineAdapter();
    final DeterministicBtTaskStore store = DeterministicBtTaskStore();
    final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
    final DeterministicBtTaskCore core = DeterministicBtTaskCore(
      adapter: adapter,
      store: store,
      cacheInvalidationBus: bus,
      clock: () => DateTime.utc(2026, 6, 5, 12),
    );

    await core.createTask(
      const BtTaskCreateRequest(
        source: MagnetBtTaskSource(uri: 'magnet:?xt=urn:btih:abc'),
      ),
    );
    final Future<List<CacheInvalidationEvent>> events =
        bus.events.take(2).toList();
    final BtTaskMetadataOutcome metadataOutcome =
        await core.ensureMetadata(const BtTaskId('task-1'));
    final BtTaskCommandOutcome selectionOutcome = await core.selectFiles(
        const BtTaskId('task-1'), const <BtFileIndex>[BtFileIndex(1)]);
    final List<CacheInvalidationEvent> delivered = await events;

    expect(metadataOutcome.isSuccess, isTrue);
    expect(selectionOutcome.isSuccess, isTrue);
    expect((await store.metadataFor('task-1'))?.name, 'Episode Pack');
    expect(
        (await store.filesFor('task-1'))
            .map((StoredBtTaskFileRecord file) => file.selectionState),
        <StoredBtFileSelectionState>[
          StoredBtFileSelectionState.skipped,
          StoredBtFileSelectionState.selected,
        ]);
    expect(adapter.selectedFiles.single.single.value, 1);
    expect(delivered.whereType<BtMetadataUpdated>().single.infoHash, 'abc');
    expect(delivered.whereType<BtTaskFileSelectionChanged>().single.taskId,
        'task-1');
    await bus.close();
  });

  test('BT task core rejects unsupported capabilities without adapter calls',
      () async {
    final _FakeDownloadEngineAdapter adapter = _FakeDownloadEngineAdapter(
      capabilities: BtCapabilityMatrix.unsupported(reason: 'BT disabled.'),
    );
    final DeterministicBtTaskCore core = DeterministicBtTaskCore(
      adapter: adapter,
      store: DeterministicBtTaskStore(),
    );

    final BtTaskCreateOutcome outcome = await core.createTask(
      const BtTaskCreateRequest(
        source: MagnetBtTaskSource(uri: 'magnet:?xt=urn:btih:abc'),
      ),
    );

    expect(outcome.isSuccess, isFalse);
    expect(outcome.failure?.kind, BtTaskFailureKind.capabilityUnsupported);
    expect(adapter.createdRequests, isEmpty);
  });

  test('BT task core records lifecycle commands status and events', () async {
    final _FakeDownloadEngineAdapter adapter = _FakeDownloadEngineAdapter();
    final DeterministicBtTaskStore store = DeterministicBtTaskStore();
    final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
    final DeterministicBtTaskCore core = DeterministicBtTaskCore(
      adapter: adapter,
      store: store,
      cacheInvalidationBus: bus,
      clock: () => DateTime.utc(2026, 6, 5, 12),
    );

    await core.createTask(
      const BtTaskCreateRequest(
        source: MagnetBtTaskSource(uri: 'magnet:?xt=urn:btih:abc'),
      ),
    );
    final Future<List<CacheInvalidationEvent>> lifecycleEvents =
        bus.events.take(3).toList();
    await core.pause(const BtTaskId('task-1'));
    await core.resume(const BtTaskId('task-1'));
    await core.remove(const BtTaskId('task-1'));
    final List<CacheInvalidationEvent> deliveredLifecycleEvents =
        await lifecycleEvents;

    expect(adapter.pausedTaskIds.single.value, 'task-1');
    expect(adapter.resumedTaskIds.single.value, 'task-1');
    expect(adapter.removedTaskIds.single.value, 'task-1');
    expect((await store.findTaskById('task-1'))?.lifecycleState,
        StoredBtTaskLifecycleState.removed);
    expect(
        deliveredLifecycleEvents.whereType<BtTaskLifecycleChanged>().length, 2);
    expect(deliveredLifecycleEvents.whereType<BtTaskRemoved>().single.taskId,
        'task-1');

    final Future<BtTaskStatus> statusFuture =
        core.watchStatus(const BtTaskId('task-1')).first;
    await Future<void>.delayed(Duration.zero);
    adapter.emitStatus(_status(state: BtTaskLifecycleState.downloading));
    final BtTaskStatus status = await statusFuture;
    expect(status.progress, 0.25);
    expect((await store.latestTransferSnapshot('task-1'))?.connectedPeers, 2);

    final Future<List<CacheInvalidationEvent>> eventNotifications =
        bus.events.take(2).toList();
    final Future<List<BtTaskEvent>> taskEventsFuture =
        core.watchEvents(const BtTaskId('task-1')).take(2).toList();
    await Future<void>.delayed(Duration.zero);
    adapter.emitEvent(BtMetadataReceived(
        taskId: const BtTaskId('task-1'), metadata: _metadata()));
    adapter.emitEvent(const BtTaskFailed(
        taskId: BtTaskId('task-1'), message: 'Engine failed.'));
    final List<BtTaskEvent> taskEvents = await taskEventsFuture;
    final List<CacheInvalidationEvent> deliveredEventNotifications =
        await eventNotifications;

    expect(taskEvents.first, isA<BtMetadataReceived>());
    expect((await store.latestEvent('task-1'))?.eventKind,
        StoredBtTaskEventKind.failed);
    expect(
        deliveredEventNotifications.whereType<BtMetadataUpdated>().single.name,
        'Episode Pack');
    expect(
        deliveredEventNotifications
            .whereType<BtTaskLifecycleChanged>()
            .single
            .newState,
        BtTaskLifecycleState.failed.name);
    await bus.close();
  });
}

BtTaskMetadata _metadata() {
  return const BtTaskMetadata(
    infoHash: InfoHash('abc'),
    name: 'Episode Pack',
    totalSizeBytes: 3072,
    pieceLengthBytes: 1024,
    files: <BtTaskFile>[
      BtTaskFile(
        index: BtFileIndex(0),
        path: 'Episode 1.mkv',
        lengthBytes: 1024,
        offsetBytes: 0,
        selectionState: BtFileSelectionState.selected,
      ),
      BtTaskFile(
        index: BtFileIndex(1),
        path: 'Episode 2.mkv',
        lengthBytes: 2048,
        offsetBytes: 1024,
        selectionState: BtFileSelectionState.selected,
      ),
    ],
  );
}

BtTaskStatus _status({required BtTaskLifecycleState state}) {
  return BtTaskStatus(
    taskId: const BtTaskId('task-1'),
    state: state,
    progress: 0.25,
    downloadRateBytesPerSecond: 2048,
    uploadRateBytesPerSecond: 256,
    connectedPeers: 2,
    metadata: _metadata(),
  );
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
  _FakeDownloadEngineAdapter({BtCapabilityMatrix? capabilities})
      : capabilities = capabilities ?? _supportedCapabilities();

  @override
  final BtCapabilityMatrix capabilities;

  final List<BtTaskCreateRequest> createdRequests = <BtTaskCreateRequest>[];
  final List<BtTaskId> pausedTaskIds = <BtTaskId>[];
  final List<BtTaskId> resumedTaskIds = <BtTaskId>[];
  final List<BtTaskId> removedTaskIds = <BtTaskId>[];
  final List<List<BtFileIndex>> selectedFiles = <List<BtFileIndex>>[];
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
    return Future<BtTaskMetadata>.value(_metadata());
  }

  @override
  Future<void> pause(BtTaskId taskId) {
    pausedTaskIds.add(taskId);
    return Future<void>.value();
  }

  @override
  Future<void> remove(BtTaskId taskId) {
    removedTaskIds.add(taskId);
    return Future<void>.value();
  }

  @override
  Future<void> resume(BtTaskId taskId) {
    resumedTaskIds.add(taskId);
    return Future<void>.value();
  }

  @override
  Future<void> selectFiles(BtTaskId taskId, Iterable<BtFileIndex> files) {
    selectedFiles.add(<BtFileIndex>[...files]);
    return Future<void>.value();
  }

  @override
  Stream<BtTaskEvent> watchEvents(BtTaskId taskId) => _eventController.stream;

  @override
  Stream<BtTaskStatus> watchStatus(BtTaskId taskId) => _statusController.stream;

  void emitEvent(BtTaskEvent event) {
    _eventController.add(event);
  }

  void emitStatus(BtTaskStatus status) {
    _statusController.add(status);
  }
}
