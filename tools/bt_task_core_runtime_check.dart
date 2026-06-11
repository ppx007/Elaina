import 'dart:async';

import '../lib/celesteria.dart';

Future<void> main() async {
  await verifyBtTaskCoreRuntimeContract();
}

Future<void> verifyBtTaskCoreRuntimeContract() async {
  final _CheckDownloadEngineAdapter adapter = _CheckDownloadEngineAdapter();
  final DeterministicBtTaskStore store = DeterministicBtTaskStore();
  final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
  final BtTaskCoreRuntime runtime = BtTaskCoreRuntime.withDependencies(
    adapter: adapter,
    store: store,
    cacheInvalidationBus: bus,
    clock: _now,
  );

  final Future<List<CacheInvalidationEvent>> creationEvents =
      bus.events.take(1).toList();
  final BtTaskCoreRuntimeActionResult<BtTaskProjection> created =
      await runtime.createTask(const BtTaskCreateRequest(
    source: MagnetBtTaskSource(uri: 'magnet:?xt=urn:btih:check'),
  ));
  _expect(created.isSuccess, 'BT runtime must create magnet tasks.');
  _expect((await creationEvents).single is BtTaskCreated,
      'BT runtime must publish task creation invalidation.');
  _expect((await store.findTaskById('check-task-1')) != null,
      'BT runtime must persist created task before projection.');

  final Future<List<CacheInvalidationEvent>> metadataEvents =
      bus.events.take(2).toList();
  final BtTaskCoreRuntimeActionResult<BtTaskProjection> metadata =
      await runtime.ensureMetadata(const BtTaskId('check-task-1'));
  final BtTaskCoreRuntimeActionResult<BtTaskProjection> selected =
      await runtime.selectFiles(
    const BtTaskId('check-task-1'),
    const <BtFileIndex>[BtFileIndex(1)],
  );
  final List<CacheInvalidationEvent> metadataInvalidations =
      await metadataEvents;
  _expect(metadata.value?.metadata?.name == 'Runtime Check Pack',
      'BT runtime must project metadata from storage.');
  _expect(selected.value?.files.last.selectionState == BtFileSelectionState.selected,
      'BT runtime must project selected file state.');
  _expect(metadataInvalidations.whereType<BtMetadataUpdated>().length == 1,
      'BT runtime must publish metadata invalidation.');
  _expect(
      metadataInvalidations.whereType<BtTaskFileSelectionChanged>().length == 1,
      'BT runtime must publish file-selection invalidation.');

  final Future<List<CacheInvalidationEvent>> lifecycleEvents =
      bus.events.take(2).toList();
  _expect((await runtime.pause(const BtTaskId('check-task-1'))).isSuccess,
      'BT runtime must pause through adapter boundary.');
  _expect((await runtime.resume(const BtTaskId('check-task-1'))).isSuccess,
      'BT runtime must resume through adapter boundary.');
  _expect((await lifecycleEvents).whereType<BtTaskLifecycleChanged>().length == 2,
      'BT runtime must publish lifecycle invalidations after persistence.');

  final BtTaskCoreRuntimeActionResult<BtTaskRuntimeObservation<BtTaskStatus>>
      statusObservation = runtime.observeStatus(const BtTaskId('check-task-1'));
  final Future<BtTaskStatus> observedStatus =
      statusObservation.value!.values.first;
  await Future<void>.delayed(Duration.zero);
  adapter.emitStatus(_status(BtTaskLifecycleState.downloading));
  _expect((await observedStatus).progress == 0.5,
      'BT runtime must expose adapter status observation.');
  _expect((await store.latestTransferSnapshot('check-task-1'))?.progress == 0.5,
      'BT runtime must persist observed transfer snapshot.');

  final BtTaskCoreRuntimeActionResult<BtTaskRuntimeObservation<BtTaskEvent>>
      eventObservation = runtime.observeEvents(const BtTaskId('check-task-1'));
  final Future<List<BtTaskEvent>> observedEvents =
      eventObservation.value!.values.take(2).toList();
  await Future<void>.delayed(Duration.zero);
  adapter.emitEvent(BtMetadataReceived(
    taskId: const BtTaskId('check-task-1'),
    metadata: _metadata(),
  ));
  adapter.emitEvent(const BtTaskFailed(
    taskId: BtTaskId('check-task-1'),
    message: 'Runtime check failure.',
  ));
  _expect((await observedEvents).last is BtTaskFailed,
      'BT runtime must expose adapter event observation.');
  _expect((await store.latestEvent('check-task-1'))?.eventKind ==
      StoredBtTaskEventKind.failed,
      'BT runtime must persist observed task events.');

  final BtTaskCoreRuntimeActionResult<List<BtTaskRestartProjection>> restart =
      await runtime.restartReconciliation();
  _expect(restart.value!.single.disposition == BtRuntimeRestartDisposition.failed,
      'BT runtime must project terminal failure restart state.');

  final DeterministicBtTaskStore restartStore = DeterministicBtTaskStore(
    seedTasks: <StoredBtTaskRecord>[
      StoredBtTaskRecord(
        id: 'restart-paused',
        sourceKind: StoredBtTaskSourceKind.magnet,
        sourceUri: 'magnet:?xt=urn:btih:restart-paused',
        lifecycleState: StoredBtTaskLifecycleState.paused,
        createdAt: _now(),
        updatedAt: _now(),
      ),
    ],
  );
  final BtTaskCoreRuntime restartRuntime = BtTaskCoreRuntime(
    core: _UnavailableCheckBtTaskCore(),
    store: restartStore,
    capabilities: _supportedCapabilities(),
  );
  final BtTaskCoreRuntimeActionResult<List<BtTaskRestartProjection>> paused =
      await restartRuntime.restartReconciliation();
  _expect(paused.value!.single.requiresAdapterReconciliation,
      'BT runtime must flag paused restart state for adapter reconciliation.');

  final BtTaskCoreRuntime unsupported = BtTaskCoreRuntime.withDependencies(
    adapter: _CheckDownloadEngineAdapter(
      capabilities: BtCapabilityMatrix.unsupported(reason: 'BT disabled.'),
    ),
    store: DeterministicBtTaskStore(),
  );
  final BtTaskCoreRuntimeActionResult<BtTaskProjection> rejected =
      await unsupported.createTask(const BtTaskCreateRequest(
    source: MagnetBtTaskSource(uri: 'magnet:?xt=urn:btih:disabled'),
  ));
  _expect(rejected.failure?.kind == BtTaskCoreRuntimeFailureKind.capabilityUnsupported,
      'BT runtime must normalize unsupported capability failures.');

  await runtime.dispose();
  _expect((await runtime.listTasks()).kind == BtTaskCoreRuntimeActionResultKind.disposed,
      'BT runtime must reject actions after disposal.');
  await bus.close();
}

final class _UnavailableCheckBtTaskCore implements BtTaskCoreContract {
  @override
  Future<BtTaskCreateOutcome> createTask(BtTaskCreateRequest request) {
    return Future<BtTaskCreateOutcome>.value(
      const BtTaskCreateOutcome.failure(
        failure: BtTaskFailure(
          kind: BtTaskFailureKind.adapterUnavailable,
          message: 'Unavailable.',
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
          message: 'Unavailable.',
        ),
      ),
    );
  }

  @override
  Future<BtTaskCommandOutcome> pause(BtTaskId taskId) => _commandFailure();

  @override
  Future<BtTaskCommandOutcome> remove(BtTaskId taskId) => _commandFailure();

  @override
  Future<BtTaskCommandOutcome> resume(BtTaskId taskId) => _commandFailure();

  @override
  Future<BtTaskCommandOutcome> selectFiles(
    BtTaskId taskId,
    Iterable<BtFileIndex> files,
  ) =>
      _commandFailure();

  @override
  Stream<BtTaskEvent> watchEvents(BtTaskId taskId) => const Stream.empty();

  @override
  Stream<BtTaskStatus> watchStatus(BtTaskId taskId) => const Stream.empty();

  Future<BtTaskCommandOutcome> _commandFailure() {
    return Future<BtTaskCommandOutcome>.value(
      const BtTaskCommandOutcome.failure(
        failure: BtTaskFailure(
          kind: BtTaskFailureKind.adapterUnavailable,
          message: 'Unavailable.',
        ),
      ),
    );
  }
}

void _expect(bool condition, String message) {
  if (!condition) throw StateError(message);
}

DateTime _now() => DateTime.utc(2026, 6, 11, 12);

BtTaskMetadata _metadata() {
  return const BtTaskMetadata(
    infoHash: InfoHash('check-hash'),
    name: 'Runtime Check Pack',
    totalSizeBytes: 4096,
    pieceLengthBytes: 1024,
    files: <BtTaskFile>[
      BtTaskFile(
        index: BtFileIndex(0),
        path: 'Runtime Check 1.mkv',
        lengthBytes: 1024,
        offsetBytes: 0,
        selectionState: BtFileSelectionState.selected,
      ),
      BtTaskFile(
        index: BtFileIndex(1),
        path: 'Runtime Check 2.mkv',
        lengthBytes: 3072,
        offsetBytes: 1024,
        selectionState: BtFileSelectionState.selected,
      ),
    ],
  );
}

BtTaskStatus _status(BtTaskLifecycleState state) {
  return BtTaskStatus(
    taskId: const BtTaskId('check-task-1'),
    state: state,
    progress: 0.5,
    downloadRateBytesPerSecond: 8192,
    uploadRateBytesPerSecond: 512,
    connectedPeers: 4,
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

final class _CheckDownloadEngineAdapter implements DownloadEngineAdapter {
  _CheckDownloadEngineAdapter({BtCapabilityMatrix? capabilities})
      : capabilities = capabilities ?? _supportedCapabilities();

  @override
  final BtCapabilityMatrix capabilities;

  int _nextTaskId = 1;
  final StreamController<BtTaskStatus> _statusController =
      StreamController<BtTaskStatus>.broadcast(sync: true);
  final StreamController<BtTaskEvent> _eventController =
      StreamController<BtTaskEvent>.broadcast(sync: true);

  @override
  String get displayName => 'Runtime Check Download Engine';

  @override
  String get id => 'runtime-check-download-engine';

  @override
  Future<BtTaskId> createTask(BtTaskCreateRequest request) {
    return Future<BtTaskId>.value(BtTaskId('check-task-${_nextTaskId++}'));
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
