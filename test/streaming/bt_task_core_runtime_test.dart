import 'dart:async';

// BT task runtime tests keep lifecycle, metadata, file selection, and events in
// one suite because regressions usually cross those projections.
// Engine adapter details belong in adapter tests, not this runtime suite.
import 'package:elaina/elaina.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('BT task core runtime creates magnet and torrent-data tasks', () async {
    final _RuntimeHarness harness = _RuntimeHarness();

    final BtTaskCoreRuntimeActionResult<BtTaskProjection> magnet =
        await harness.runtime.createTask(const BtTaskCreateRequest(
      source: MagnetBtTaskSource(uri: 'magnet:?xt=urn:btih:abc'),
    ));
    final BtTaskCoreRuntimeActionResult<BtTaskProjection> torrent =
        await harness.runtime.createTask(BtTaskCreateRequest(
      source:
          TorrentDataBtTaskSource(uri: Uri.parse('file:///tmp/anime.torrent')),
    ));

    expect(magnet.isSuccess, isTrue);
    expect(torrent.isSuccess, isTrue);
    expect(harness.adapter.createdRequests.first.source,
        isA<MagnetBtTaskSource>());
    expect(harness.adapter.createdRequests.last.source,
        isA<TorrentDataBtTaskSource>());
    expect((await harness.store.findTaskById('task-1'))?.sourceKind,
        StoredBtTaskSourceKind.magnet);
    expect((await harness.store.findTaskById('task-2'))?.sourceKind,
        StoredBtTaskSourceKind.torrentData);
    expect(harness.runtime.currentSnapshot.tasks.length, 2);
    await harness.close();
  });

  test('BT task core runtime projects metadata files and immutable snapshots',
      () async {
    final _RuntimeHarness harness = _RuntimeHarness();
    await harness.runtime.createTask(const BtTaskCreateRequest(
      source: MagnetBtTaskSource(uri: 'magnet:?xt=urn:btih:abc'),
    ));

    final BtTaskCoreRuntimeActionResult<BtTaskProjection> metadata =
        await harness.runtime.ensureMetadata(const BtTaskId('task-1'));
    final BtTaskCoreRuntimeActionResult<BtTaskProjection> selected =
        await harness.runtime.selectFiles(
      const BtTaskId('task-1'),
      const <BtFileIndex>[BtFileIndex(1)],
    );
    final BtTaskCoreRuntimeActionResult<List<BtTaskProjection>> listed =
        await harness.runtime.listTasks();

    expect(metadata.isSuccess, isTrue);
    expect(selected.isSuccess, isTrue);
    expect(listed.value?.single.metadata?.name, 'Episode Pack');
    expect(
        listed.value?.single.files
            .map((BtTaskFileProjection file) => file.selectionState),
        <BtFileSelectionState>[
          BtFileSelectionState.skipped,
          BtFileSelectionState.selected,
        ]);
    expect(
        () => listed.value!.add(listed.value!.single), throwsUnsupportedError);
    expect(harness.adapter.selectedFiles.single.single.value, 1);
    await harness.close();
  });

  test('BT task core runtime gates unsupported and disposed behavior',
      () async {
    final _RuntimeHarness unsupported = _RuntimeHarness(
      capabilities: BtCapabilityMatrix.unsupported(reason: 'BT disabled.'),
    );
    final BtTaskCoreRuntimeActionResult<BtTaskProjection> rejected =
        await unsupported.runtime.createTask(const BtTaskCreateRequest(
      source: MagnetBtTaskSource(uri: 'magnet:?xt=urn:btih:abc'),
    ));
    expect(rejected.isSuccess, isFalse);
    expect(rejected.failure?.kind,
        BtTaskCoreRuntimeFailureKind.capabilityUnsupported);
    expect(unsupported.adapter.createdRequests, isEmpty);
    await unsupported.close();

    final BtTaskCoreRuntime unavailable =
        BtTaskCoreRuntime.unavailable(reason: 'No adapter configured.');
    final BtTaskCoreRuntimeActionResult<BtTaskProjection> unavailableResult =
        await unavailable.createTask(const BtTaskCreateRequest(
      source: MagnetBtTaskSource(uri: 'magnet:?xt=urn:btih:abc'),
    ));
    expect(
        unavailableResult.kind, BtTaskCoreRuntimeActionResultKind.unavailable);

    final _RuntimeHarness harness = _RuntimeHarness();
    await harness.runtime.dispose();
    final BtTaskCoreRuntimeActionResult<List<BtTaskProjection>> disposed =
        await harness.runtime.listTasks();
    expect(disposed.kind, BtTaskCoreRuntimeActionResultKind.disposed);
    await harness.close();
  });

  test('BT task core runtime records lifecycle commands and cache ordering',
      () async {
    final _RuntimeHarness harness = _RuntimeHarness();
    final Future<List<CacheInvalidationEvent>> creationEvents =
        harness.bus.events.take(1).toList();
    await harness.runtime.createTask(const BtTaskCreateRequest(
      source: MagnetBtTaskSource(uri: 'magnet:?xt=urn:btih:abc'),
    ));
    final CacheInvalidationEvent created = (await creationEvents).single;
    expect(created, isA<BtTaskCreated>());
    expect((await harness.store.findTaskById('task-1'))?.lifecycleState,
        StoredBtTaskLifecycleState.queued);

    final Future<List<CacheInvalidationEvent>> commandEvents =
        harness.bus.events.take(3).toList();
    final BtTaskCoreRuntimeActionResult<BtTaskProjection> paused =
        await harness.runtime.pause(const BtTaskId('task-1'));
    await harness.runtime.resume(const BtTaskId('task-1'));
    await harness.runtime.remove(const BtTaskId('task-1'));
    final List<CacheInvalidationEvent> events = await commandEvents;

    expect(paused.value?.lifecycleState, StoredBtTaskLifecycleState.paused);
    expect(events.whereType<BtTaskLifecycleChanged>().length, 2);
    expect(events.whereType<BtTaskRemoved>().single.taskId, 'task-1');
    expect((await harness.store.findTaskById('task-1'))?.lifecycleState,
        StoredBtTaskLifecycleState.removed);
    await harness.close();
  });

  test('BT task core runtime observes status and events into replayable state',
      () async {
    final _RuntimeHarness harness = _RuntimeHarness();
    await harness.runtime.createTask(const BtTaskCreateRequest(
      source: MagnetBtTaskSource(uri: 'magnet:?xt=urn:btih:abc'),
    ));

    final BtTaskCoreRuntimeActionResult<BtTaskRuntimeObservation<BtTaskStatus>>
        statusObservation =
        harness.runtime.observeStatus(const BtTaskId('task-1'));
    final Future<BtTaskStatus> statusFuture =
        statusObservation.value!.values.first;
    await Future<void>.delayed(Duration.zero);
    harness.adapter
        .emitStatus(_status(state: BtTaskLifecycleState.downloading));
    final BtTaskStatus status = await statusFuture;
    expect(status.progress, 0.25);
    expect(
        (await harness.store.latestTransferSnapshot('task-1'))?.connectedPeers,
        2);

    final BtTaskCoreRuntimeActionResult<BtTaskRuntimeObservation<BtTaskEvent>>
        eventObservation =
        harness.runtime.observeEvents(const BtTaskId('task-1'));
    final Future<List<BtTaskEvent>> taskEvents =
        eventObservation.value!.values.take(2).toList();
    await Future<void>.delayed(Duration.zero);
    harness.adapter.emitEvent(BtMetadataReceived(
      taskId: const BtTaskId('task-1'),
      metadata: _metadata(),
    ));
    harness.adapter.emitEvent(const BtTaskFailed(
      taskId: BtTaskId('task-1'),
      message: 'Engine failed.',
    ));

    expect((await taskEvents).last, isA<BtTaskFailed>());
    expect((await harness.store.latestEvent('task-1'))?.eventKind,
        StoredBtTaskEventKind.failed);
    final BtTaskCoreRuntimeActionResult<BtTaskProjection?> projection =
        await harness.runtime.taskById(const BtTaskId('task-1'));
    expect(projection.value?.latestTransferSnapshot?.progress, 0.25);
    expect(projection.value?.latestTransferSnapshot?.uploadRateBytesPerSecond,
        256);
    expect(
        projection.value?.latestEvent?.eventKind, StoredBtTaskEventKind.failed);
    await harness.close();
  });

  test('BT task core runtime projects restart reconciliation states', () async {
    final DateTime now = DateTime.utc(2026, 6, 11, 12);
    final DeterministicBtTaskStore store = DeterministicBtTaskStore(
      seedTasks: <StoredBtTaskRecord>[
        _storedTask('queued', StoredBtTaskLifecycleState.queued, now),
        _storedTask('paused', StoredBtTaskLifecycleState.paused, now),
        _storedTask('completed', StoredBtTaskLifecycleState.completed, now),
        _storedTask('failed', StoredBtTaskLifecycleState.failed, now),
        _storedTask('removed', StoredBtTaskLifecycleState.removed, now),
      ],
    );
    await store.storeMetadata(const StoredBtTaskMetadataRecord(
      taskId: 'paused',
      infoHash: 'paused-hash',
      name: 'Paused Pack',
      totalSizeBytes: 1,
      pieceLengthBytes: 1,
    ));
    final BtTaskCoreRuntime runtime = BtTaskCoreRuntime(
      core: _FakeBtTaskCore(),
      store: store,
      capabilities: _supportedCapabilities(),
    );

    final BtTaskCoreRuntimeActionResult<List<BtTaskRestartProjection>> result =
        await runtime.restartReconciliation();
    final Map<String, BtRuntimeRestartDisposition> dispositions =
        <String, BtRuntimeRestartDisposition>{
      for (final BtTaskRestartProjection projection in result.value!)
        projection.taskId.value: projection.disposition,
    };

    expect(dispositions['queued'], BtRuntimeRestartDisposition.incomplete);
    expect(dispositions['paused'], BtRuntimeRestartDisposition.paused);
    expect(dispositions['completed'], BtRuntimeRestartDisposition.terminal);
    expect(dispositions['failed'], BtRuntimeRestartDisposition.failed);
    expect(dispositions['removed'], BtRuntimeRestartDisposition.removed);
  });
}

final class _RuntimeHarness {
  _RuntimeHarness({BtCapabilityMatrix? capabilities})
      : adapter = _FakeDownloadEngineAdapter(capabilities: capabilities),
        store = DeterministicBtTaskStore(),
        bus = StreamCacheInvalidationBus() {
    runtime = BtTaskCoreRuntime.withDependencies(
      adapter: adapter,
      store: store,
      cacheInvalidationBus: bus,
      clock: () => DateTime.utc(2026, 6, 11, 12),
    );
  }

  final _FakeDownloadEngineAdapter adapter;
  final DeterministicBtTaskStore store;
  final StreamCacheInvalidationBus bus;
  late final BtTaskCoreRuntime runtime;

  Future<void> close() => bus.close();
}

StoredBtTaskRecord _storedTask(
  String id,
  StoredBtTaskLifecycleState state,
  DateTime now,
) {
  return StoredBtTaskRecord(
    id: id,
    sourceKind: StoredBtTaskSourceKind.magnet,
    sourceUri: 'magnet:?xt=urn:btih:$id',
    lifecycleState: state,
    createdAt: now,
    updatedAt: now,
  );
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
  final List<List<BtFileIndex>> selectedFiles = <List<BtFileIndex>>[];
  final StreamController<BtTaskStatus> _statusController =
      StreamController<BtTaskStatus>.broadcast(sync: true);
  final StreamController<BtTaskEvent> _eventController =
      StreamController<BtTaskEvent>.broadcast(sync: true);

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
    return Future<BtTaskMetadata>.value(_metadata());
  }

  @override
  Future<void> pause(BtTaskId taskId) => Future<void>.value();

  @override
  Future<void> remove(BtTaskId taskId) => Future<void>.value();

  @override
  Future<void> resume(BtTaskId taskId) => Future<void>.value();

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

final class _FakeBtTaskCore implements BtTaskCoreContract {
  @override
  Future<BtTaskCreateOutcome> createTask(BtTaskCreateRequest request) {
    return Future<BtTaskCreateOutcome>.value(
      const BtTaskCreateOutcome.failure(
        failure: BtTaskFailure(
          kind: BtTaskFailureKind.adapterUnavailable,
          message: 'Not used.',
        ),
      ),
    );
  }

  @override
  Future<BtTaskMetadataOutcome> ensureMetadata(BtTaskId taskId) {
    return Future<BtTaskMetadataOutcome>.value(
      const BtTaskMetadataOutcome.failure(
        failure: BtTaskFailure(
          kind: BtTaskFailureKind.adapterUnavailable,
          message: 'Not used.',
        ),
      ),
    );
  }

  @override
  Future<BtTaskCommandOutcome> pause(BtTaskId taskId) => _failure();

  @override
  Future<BtTaskCommandOutcome> remove(BtTaskId taskId) => _failure();

  @override
  Future<BtTaskCommandOutcome> resume(BtTaskId taskId) => _failure();

  @override
  Future<BtTaskCommandOutcome> selectFiles(
    BtTaskId taskId,
    Iterable<BtFileIndex> files,
  ) =>
      _failure();

  @override
  Stream<BtTaskEvent> watchEvents(BtTaskId taskId) => const Stream.empty();

  @override
  Stream<BtTaskStatus> watchStatus(BtTaskId taskId) => const Stream.empty();

  Future<BtTaskCommandOutcome> _failure() {
    return Future<BtTaskCommandOutcome>.value(
      const BtTaskCommandOutcome.failure(
        failure: BtTaskFailure(
          kind: BtTaskFailureKind.adapterUnavailable,
          message: 'Not used.',
        ),
      ),
    );
  }
}
