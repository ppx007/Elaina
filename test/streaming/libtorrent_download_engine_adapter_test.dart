// Adapter tests pin the contract between the domain download runtime and the
// libtorrent-facing adapter. Keep engine fakes narrow so UI tests do not grow
// hidden torrent-engine assumptions.
import 'dart:async';

import 'package:elaina/elaina.dart';
import 'package:flutter_test/flutter_test.dart';

const int _torrentId = 1;
const String _torrentIdValue = '1';
const String _virtualStreamIdValue = '1::1';
const int _selectedFileIndex = 1;
const String _magnetUri = 'magnet:?xt=urn:btih:abc123';
const String _infoHash = 'abc123';
const int _pieceLengthBytes = 1024;
const int _selectedFileLengthBytes = 2048;
final Uri _torrentFileUri = Uri.parse('file:///tmp/anime.torrent');

void main() {
  test('libtorrent adapter maps sources and lifecycle commands', () async {
    final _FakeLibtorrentBackend backend = _FakeLibtorrentBackend();
    final LibtorrentDownloadEngineAdapter adapter =
        LibtorrentDownloadEngineAdapter(backend: backend);

    final BtTaskId magnetTask = await adapter.createTask(
      const BtTaskCreateRequest(
        source: MagnetBtTaskSource(uri: _magnetUri),
      ),
    );
    final BtTaskId torrentTask = await adapter.createTask(
      BtTaskCreateRequest(
        source: TorrentDataBtTaskSource(uri: _torrentFileUri),
      ),
    );
    await adapter.pause(magnetTask);
    await adapter.resume(magnetTask);
    await adapter.remove(magnetTask);

    expect(magnetTask.value, _torrentIdValue);
    expect(torrentTask.value, '2');
    expect(backend.createdMagnets, <String>[_magnetUri]);
    expect(backend.createdTorrentFiles, <Uri>[_torrentFileUri]);
    expect(backend.pausedTorrentIds, <int>[_torrentId]);
    expect(backend.resumedTorrentIds, <int>[_torrentId]);
    expect(backend.removedTorrentIds, <int>[_torrentId]);
  });

  test('libtorrent adapter maps complete metadata and file offsets', () async {
    final _FakeLibtorrentBackend backend = _FakeLibtorrentBackend(
      supportsCompleteMetadata: true,
    )..seedMetadata(_torrentId);
    final LibtorrentDownloadEngineAdapter adapter =
        LibtorrentDownloadEngineAdapter(backend: backend);

    final BtTaskMetadata metadata =
        await adapter.ensureMetadata(const BtTaskId(_torrentIdValue));

    expect(metadata.infoHash.value, _infoHash);
    expect(metadata.name, 'Episode Pack');
    expect(metadata.totalSizeBytes, 3072);
    expect(metadata.pieceLengthBytes, _pieceLengthBytes);
    expect(
      metadata.files.map((BtTaskFile file) => file.offsetBytes),
      <int>[0, 1024],
    );
    expect(
      metadata.files.map((BtTaskFile file) => file.path),
      <String>['Episode 1.mkv', 'Episode 2.mkv'],
    );
  });

  test('libtorrent adapter applies named file priority values', () async {
    final _FakeLibtorrentBackend backend = _FakeLibtorrentBackend()
      ..filesByTorrentId[_torrentId] = const <LibtorrentFileSnapshot>[
        LibtorrentFileSnapshot(
          index: 0,
          path: 'Episode 1.mkv',
          lengthBytes: 1024,
          isStreamable: true,
        ),
        LibtorrentFileSnapshot(
          index: 1,
          path: 'Episode 2.mkv',
          lengthBytes: 2048,
          isStreamable: true,
        ),
        LibtorrentFileSnapshot(
          index: 2,
          path: 'Bonus.txt',
          lengthBytes: 128,
          isStreamable: false,
        ),
      ];
    final LibtorrentDownloadEngineAdapter adapter =
        LibtorrentDownloadEngineAdapter(backend: backend);

    await adapter.selectFiles(
      const BtTaskId(_torrentIdValue),
      const <BtFileIndex>[BtFileIndex(1)],
    );

    expect(
      backend.filePrioritiesByTorrentId[_torrentId],
      <int>[
        libtorrentSkipFilePriority,
        libtorrentSelectedFilePriority,
        libtorrentSkipFilePriority,
      ],
    );
  });

  test('libtorrent adapter maps status and events to neutral contracts',
      () async {
    final _FakeLibtorrentBackend backend = _FakeLibtorrentBackend(
      supportsCompleteMetadata: true,
    )..seedMetadata(_torrentId);
    final LibtorrentDownloadEngineAdapter adapter =
        LibtorrentDownloadEngineAdapter(backend: backend);

    final Future<BtTaskStatus> statusFuture =
        adapter.watchStatus(const BtTaskId(_torrentIdValue)).first;
    await Future<void>.delayed(Duration.zero);
    backend.emitSnapshot(
      _torrentId,
      _snapshot(state: LibtorrentTaskState.downloading, progress: 0.5),
    );
    final BtTaskStatus status = await statusFuture;
    expect(status.state, BtTaskLifecycleState.downloading);
    expect(status.progress, 0.5);

    final Future<List<BtTaskEvent>> eventsFuture =
        adapter.watchEvents(const BtTaskId(_torrentIdValue)).take(2).toList();
    await Future<void>.delayed(Duration.zero);
    backend.emitSnapshot(_torrentId, _snapshot());
    backend.emitSnapshot(
      _torrentId,
      _snapshot(
        state: LibtorrentTaskState.error,
        message: 'Tracker failed.',
      ),
    );
    final List<BtTaskEvent> events = await eventsFuture;
    expect(events.first, isA<BtMetadataReceived>());
    expect((events.first as BtMetadataReceived).metadata.infoHash.value,
        _infoHash);
    expect(events.last, isA<BtTaskFailed>());
    expect((events.last as BtTaskFailed).message, 'Tracker failed.');
  });

  test('missing complete metadata is normalized by the BT task core', () async {
    final _FakeLibtorrentBackend backend = _FakeLibtorrentBackend(
      supportsCompleteMetadata: true,
    )
      ..snapshotsByTorrentId[_torrentId] = _snapshot(pieceLengthBytes: null)
      ..filesByTorrentId[_torrentId] = _fileSnapshots();
    final DeterministicBtTaskCore core = DeterministicBtTaskCore(
      adapter: LibtorrentDownloadEngineAdapter(backend: backend),
      store: DeterministicBtTaskStore(),
    );

    await core.createTask(
      const BtTaskCreateRequest(
        source: MagnetBtTaskSource(uri: _magnetUri),
      ),
    );
    final BtTaskMetadataOutcome outcome =
        await core.ensureMetadata(const BtTaskId(_torrentIdValue));

    expect(outcome.isSuccess, isFalse);
    expect(outcome.failure?.kind, BtTaskFailureKind.engineError);
  });

  test('libtorrent adapter declares concrete BT and priority capabilities', () {
    final LibtorrentDownloadEngineAdapter completeMetadataAdapter =
        LibtorrentDownloadEngineAdapter(
      backend: _FakeLibtorrentBackend(supportsCompleteMetadata: true),
    );
    final LibtorrentDownloadEngineAdapter incompleteMetadataAdapter =
        LibtorrentDownloadEngineAdapter(
      backend: _FakeLibtorrentBackend(),
    );

    expect(
      completeMetadataAdapter.capabilities
          .statusOf(BtStreamingCapability.taskManagement)
          .supported,
      isTrue,
    );
    expect(
      completeMetadataAdapter.capabilities
          .statusOf(BtStreamingCapability.metadataFetching)
          .supported,
      isTrue,
    );
    expect(
      incompleteMetadataAdapter.capabilities
          .statusOf(BtStreamingCapability.metadataFetching)
          .supported,
      isFalse,
    );
    expect(
      completeMetadataAdapter.capabilities
          .statusOf(BtStreamingCapability.piecePriorityScheduling)
          .supported,
      isTrue,
    );
    for (final BtStreamingCapability capability in <BtStreamingCapability>[
      BtStreamingCapability.virtualMediaStream,
      BtStreamingCapability.timelineOverlay,
      BtStreamingCapability.longBackgroundDownload,
    ]) {
      expect(
        completeMetadataAdapter.capabilities.statusOf(capability).supported,
        isFalse,
      );
    }
  });

  test('libtorrent applier records accepted scheduler plan application',
      () async {
    final _FakeLibtorrentBackend backend = _FakeLibtorrentBackend(
      supportsCompleteMetadata: true,
    )..seedMetadata(_torrentId);
    final _PiecePriorityHarness harness =
        await _PiecePriorityHarness.create(backend);

    final PiecePriorityPlanOutcome planned = await harness.runtime.plan(
      const PiecePriorityPlanRequest(
        taskId: BtTaskId(_torrentIdValue),
        streamId: VirtualMediaStreamId(_virtualStreamIdValue),
        profile: PiecePrioritySchedulerRuntime.balancedProfile,
        playbackWindow: PlaybackWindow(
          streamId: VirtualMediaStreamId(_virtualStreamIdValue),
          currentByteOffset: 0,
          lookaheadBytes: _pieceLengthBytes,
        ),
      ),
    );
    final PiecePriorityApplicationOutcome applied =
        await harness.runtime.applyPlan(planId: planned.plan!.id);
    final StoredPiecePriorityPlanApplicationEventRecord? application =
        await harness.schedulerStore
            .latestApplicationEvent(planned.plan!.id.value);

    expect(planned.isSuccess, isTrue);
    expect(applied.isSuccess, isTrue);
    expect(application?.outcome,
        StoredPiecePriorityApplicationOutcomeKind.accepted);
    expect(
      backend.filePrioritiesByTorrentId[_torrentId],
      <int>[
        libtorrentSkipFilePriority,
        libtorrentSelectedFilePriority,
      ],
    );
    // The plan must reach the engine's streaming window, not just file
    // selection: a preload budget and bounded cache are primed.
    expect(backend.primedStreamWindows, hasLength(1));
    expect(backend.primedStreamWindows.single.preloadBytes,
        greaterThanOrEqualTo(libtorrentMinPreloadBytes));
    expect(backend.primedStreamWindows.single.cacheBytes,
        lessThanOrEqualTo(libtorrentMaxStreamCacheBytes));
    await harness.close();
  });

  test('libtorrent applier normalizes backend priority rejection', () async {
    final _FakeLibtorrentBackend backend = _FakeLibtorrentBackend(
      supportsCompleteMetadata: true,
      priorityApplicationError: StateError('priority rejected'),
    )..seedMetadata(_torrentId);
    final _PiecePriorityHarness harness =
        await _PiecePriorityHarness.create(backend);

    final PiecePriorityPlanOutcome planned = await harness.runtime.plan(
      const PiecePriorityPlanRequest(
        taskId: BtTaskId(_torrentIdValue),
        streamId: VirtualMediaStreamId(_virtualStreamIdValue),
        profile: PiecePrioritySchedulerRuntime.balancedProfile,
        seekTarget: SeekTarget(
          streamId: VirtualMediaStreamId(_virtualStreamIdValue),
          targetByteOffset: _pieceLengthBytes,
        ),
      ),
    );
    final PiecePriorityApplicationOutcome applied =
        await harness.runtime.applyPlan(planId: planned.plan!.id);
    final StoredPiecePriorityPlanApplicationEventRecord? application =
        await harness.schedulerStore
            .latestApplicationEvent(planned.plan!.id.value);

    expect(planned.isSuccess, isTrue);
    expect(applied.isSuccess, isFalse);
    expect(applied.failure?.kind,
        PiecePriorityApplicationFailureKind.adapterRejected);
    expect(application?.outcome,
        StoredPiecePriorityApplicationOutcomeKind.rejected);
    expect(application?.failureKind,
        PiecePriorityApplicationFailureKind.adapterRejected.name);
    await harness.close();
  });

  test('libtorrent runtime composition wires lifecycle metadata and selection',
      () async {
    final _FakeLibtorrentBackend backend = _FakeLibtorrentBackend(
      supportsCompleteMetadata: true,
    )..seedMetadata(_torrentId);
    final DeterministicBtTaskStore store = DeterministicBtTaskStore();
    final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
    final BtTaskRuntimeCompositionContract composition =
        libtorrentBtTaskRuntimeComposition(
      backend: backend,
      store: store,
      cacheInvalidationBus: bus,
      clock: _now,
    );
    final BtTaskCoreBootstrap bootstrap =
        BtTaskCoreBootstrap.withComposition(composition: composition);

    final Future<CacheInvalidationEvent> createdEvent = bus.events.first;
    final BtTaskCoreRuntimeActionResult<BtTaskProjection> created =
        await bootstrap.runtime.createTask(
      const BtTaskCreateRequest(
        source: MagnetBtTaskSource(uri: _magnetUri),
      ),
    );
    final BtTaskCoreRuntimeActionResult<BtTaskProjection> metadata =
        await bootstrap.runtime.ensureMetadata(const BtTaskId(_torrentIdValue));
    final BtTaskCoreRuntimeActionResult<BtTaskProjection> selected =
        await bootstrap.runtime.selectFiles(
      const BtTaskId(_torrentIdValue),
      const <BtFileIndex>[BtFileIndex(1)],
    );
    await bootstrap.runtime.pause(const BtTaskId(_torrentIdValue));
    await bootstrap.runtime.resume(const BtTaskId(_torrentIdValue));
    await bootstrap.runtime.remove(const BtTaskId(_torrentIdValue));

    expect(created.isSuccess, isTrue);
    expect(await createdEvent, isA<BtTaskCreated>());
    expect(metadata.value?.metadata?.infoHash.value, _infoHash);
    expect(
      selected.value?.files.map((BtTaskFileProjection file) {
        return file.selectionState;
      }),
      <BtFileSelectionState>[
        BtFileSelectionState.skipped,
        BtFileSelectionState.selected,
      ],
    );
    expect(
      backend.filePrioritiesByTorrentId[_torrentId],
      <int>[
        libtorrentSkipFilePriority,
        libtorrentSelectedFilePriority,
      ],
    );
    expect(backend.pausedTorrentIds, <int>[_torrentId]);
    expect(backend.resumedTorrentIds, <int>[_torrentId]);
    expect(backend.removedTorrentIds, <int>[_torrentId]);
    expect((await store.findTaskById(_torrentIdValue))?.lifecycleState,
        StoredBtTaskLifecycleState.removed);
    await bus.close();
  });

  test('libtorrent runtime composition observes and replays task state',
      () async {
    final _FakeLibtorrentBackend backend = _FakeLibtorrentBackend(
      supportsCompleteMetadata: true,
    )..seedMetadata(_torrentId);
    final DeterministicBtTaskStore store = DeterministicBtTaskStore();
    final BtTaskCoreRuntime runtime = BtTaskCoreBootstrap.withComposition(
      composition: libtorrentBtTaskRuntimeComposition(
        backend: backend,
        store: store,
        clock: _now,
      ),
    ).runtime;

    await runtime.createTask(
      const BtTaskCreateRequest(
        source: MagnetBtTaskSource(uri: _magnetUri),
      ),
    );

    final BtTaskCoreRuntimeActionResult<BtTaskRuntimeObservation<BtTaskStatus>>
        statusObservation =
        runtime.observeStatus(const BtTaskId(_torrentIdValue));
    final Future<BtTaskStatus> observedStatus =
        statusObservation.value!.values.first;
    await Future<void>.delayed(Duration.zero);
    backend.emitSnapshot(
      _torrentId,
      _snapshot(state: LibtorrentTaskState.downloading, progress: 0.5),
    );
    expect((await observedStatus).state, BtTaskLifecycleState.downloading);
    expect(
        (await store.latestTransferSnapshot(_torrentIdValue))?.progress, 0.5);

    final BtTaskCoreRuntimeActionResult<BtTaskRuntimeObservation<BtTaskEvent>>
        eventObservation =
        runtime.observeEvents(const BtTaskId(_torrentIdValue));
    final Future<List<BtTaskEvent>> observedEvents =
        eventObservation.value!.values.take(2).toList();
    await Future<void>.delayed(Duration.zero);
    backend.emitSnapshot(_torrentId, _snapshot());
    backend.emitSnapshot(
      _torrentId,
      _snapshot(
        state: LibtorrentTaskState.error,
        message: 'Tracker failed.',
      ),
    );
    final List<BtTaskEvent> events = await observedEvents;
    final BtTaskCoreRuntimeActionResult<List<BtTaskRestartProjection>> restart =
        await runtime.restartReconciliation();

    expect(events.first, isA<BtMetadataReceived>());
    expect(events.last, isA<BtTaskFailed>());
    expect((await store.latestEvent(_torrentIdValue))?.eventKind,
        StoredBtTaskEventKind.failed);
    expect(
        restart.value?.single.disposition, BtRuntimeRestartDisposition.failed);
  });
}

final class _PiecePriorityHarness {
  const _PiecePriorityHarness({
    required this.runtime,
    required this.schedulerStore,
    required this.bus,
  });

  final PiecePrioritySchedulerRuntime runtime;
  final DeterministicPiecePrioritySchedulerStore schedulerStore;
  final StreamCacheInvalidationBus bus;

  static Future<_PiecePriorityHarness> create(
      _FakeLibtorrentBackend backend) async {
    final DeterministicBtTaskStore btStore = DeterministicBtTaskStore();
    final DeterministicVirtualMediaStreamStore streamStore =
        DeterministicVirtualMediaStreamStore();
    final DeterministicPiecePrioritySchedulerStore schedulerStore =
        DeterministicPiecePrioritySchedulerStore();
    final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();

    await btStore.storeTask(_storedTask());
    await btStore.storeMetadata(const StoredBtTaskMetadataRecord(
      taskId: _torrentIdValue,
      infoHash: _infoHash,
      name: 'Episode Pack',
      totalSizeBytes: _pieceLengthBytes + _selectedFileLengthBytes,
      pieceLengthBytes: _pieceLengthBytes,
    ));
    await btStore.storeFiles(
      taskId: _torrentIdValue,
      files: const <StoredBtTaskFileRecord>[
        StoredBtTaskFileRecord(
          taskId: _torrentIdValue,
          index: 0,
          path: 'Episode 1.mkv',
          lengthBytes: _pieceLengthBytes,
          offsetBytes: 0,
          selectionState: StoredBtFileSelectionState.skipped,
        ),
        StoredBtTaskFileRecord(
          taskId: _torrentIdValue,
          index: _selectedFileIndex,
          path: 'Episode 2.mkv',
          lengthBytes: _selectedFileLengthBytes,
          offsetBytes: _pieceLengthBytes,
          selectionState: StoredBtFileSelectionState.streamingTarget,
        ),
      ],
    );
    await streamStore.storeStream(StoredVirtualMediaStreamRecord(
      id: _virtualStreamIdValue,
      taskId: _torrentIdValue,
      fileIndex: _selectedFileIndex,
      lengthBytes: _selectedFileLengthBytes,
      lifecycleState: StoredVirtualMediaStreamLifecycleState.active,
      createdAt: _now(),
      updatedAt: _now(),
    ));

    return _PiecePriorityHarness(
      runtime: libtorrentPiecePrioritySchedulerRuntime(
        btTaskStore: btStore,
        streamStore: streamStore,
        schedulerStore: schedulerStore,
        cacheInvalidationBus: bus,
        backend: backend,
        clock: _now,
      ),
      schedulerStore: schedulerStore,
      bus: bus,
    );
  }

  Future<void> close() => bus.close();
}

List<LibtorrentFileSnapshot> _fileSnapshots() {
  return const <LibtorrentFileSnapshot>[
    LibtorrentFileSnapshot(
      index: 1,
      path: 'Episode 2.mkv',
      lengthBytes: 2048,
      isStreamable: true,
    ),
    LibtorrentFileSnapshot(
      index: 0,
      path: 'Episode 1.mkv',
      lengthBytes: 1024,
      isStreamable: true,
    ),
  ];
}

LibtorrentTorrentSnapshot _snapshot({
  LibtorrentTaskState state = LibtorrentTaskState.finished,
  double progress = 1,
  bool hasMetadata = true,
  bool isPaused = false,
  bool isFinished = false,
  String? message,
  String? infoHash = _infoHash,
  int? pieceLengthBytes = _pieceLengthBytes,
}) {
  return LibtorrentTorrentSnapshot(
    id: _torrentId,
    name: 'Episode Pack',
    state: state,
    progress: progress,
    downloadRateBytesPerSecond: 2048,
    uploadRateBytesPerSecond: 256,
    totalSizeBytes: 0,
    connectedPeers: 3,
    hasMetadata: hasMetadata,
    isPaused: isPaused,
    isFinished: isFinished,
    message: message,
    infoHash: infoHash,
    pieceLengthBytes: pieceLengthBytes,
  );
}

DateTime _now() => DateTime.utc(2026, 6, 18, 12);

StoredBtTaskRecord _storedTask() {
  return StoredBtTaskRecord(
    id: _torrentIdValue,
    sourceKind: StoredBtTaskSourceKind.magnet,
    sourceUri: _magnetUri,
    lifecycleState: StoredBtTaskLifecycleState.ready,
    createdAt: _now(),
    updatedAt: _now(),
    infoHash: _infoHash,
  );
}

final class _FakeLibtorrentBackend implements LibtorrentEngineBackend {
  _FakeLibtorrentBackend({
    this.supportsCompleteMetadata = false,
    this.priorityApplicationError,
  });

  @override
  final bool supportsCompleteMetadata;
  final Object? priorityApplicationError;

  final List<String> createdMagnets = <String>[];
  final List<Uri> createdTorrentFiles = <Uri>[];
  final List<int> pausedTorrentIds = <int>[];
  final List<int> resumedTorrentIds = <int>[];
  final List<int> removedTorrentIds = <int>[];
  final Map<int, LibtorrentTorrentSnapshot> snapshotsByTorrentId =
      <int, LibtorrentTorrentSnapshot>{};
  final Map<int, List<LibtorrentFileSnapshot>> filesByTorrentId =
      <int, List<LibtorrentFileSnapshot>>{};
  final Map<int, List<int>> filePrioritiesByTorrentId = <int, List<int>>{};
  final List<({int torrentId, int fileIndex, int preloadBytes, int cacheBytes})>
      primedStreamWindows =
      <({int torrentId, int fileIndex, int preloadBytes, int cacheBytes})>[];
  final Map<int, StreamController<LibtorrentTorrentSnapshot>>
      _controllersByTorrentId =
      <int, StreamController<LibtorrentTorrentSnapshot>>{};

  int _nextTorrentId = _torrentId;

  void seedMetadata(int torrentId) {
    snapshotsByTorrentId[torrentId] = _snapshot();
    filesByTorrentId[torrentId] = _fileSnapshots();
  }

  void emitSnapshot(int torrentId, LibtorrentTorrentSnapshot snapshot) {
    snapshotsByTorrentId[torrentId] = snapshot;
    _controllerFor(torrentId).add(snapshot);
  }

  @override
  Future<int> addMagnet(String magnetUri) {
    createdMagnets.add(magnetUri);
    return Future<int>.value(_nextTorrentId++);
  }

  @override
  Future<int> addTorrentFile(Uri uri) {
    createdTorrentFiles.add(uri);
    return Future<int>.value(_nextTorrentId++);
  }

  @override
  Future<List<LibtorrentFileSnapshot>> filesFor(int torrentId) {
    return Future<List<LibtorrentFileSnapshot>>.value(
      filesByTorrentId[torrentId] ?? const <LibtorrentFileSnapshot>[],
    );
  }

  @override
  Future<void> pause(int torrentId) {
    pausedTorrentIds.add(torrentId);
    return Future<void>.value();
  }

  @override
  Future<void> remove(int torrentId) {
    removedTorrentIds.add(torrentId);
    return Future<void>.value();
  }

  @override
  Future<void> resume(int torrentId) {
    resumedTorrentIds.add(torrentId);
    return Future<void>.value();
  }

  @override
  Future<void> setFilePriorities(int torrentId, List<int> priorities) {
    final Object? error = priorityApplicationError;
    if (error != null) {
      throw error;
    }
    filePrioritiesByTorrentId[torrentId] = <int>[...priorities];
    return Future<void>.value();
  }

  @override
  Future<void> primeStreamWindow({
    required int torrentId,
    required int fileIndex,
    required int preloadBytes,
    required int cacheBytes,
  }) async {
    primedStreamWindows.add((
      torrentId: torrentId,
      fileIndex: fileIndex,
      preloadBytes: preloadBytes,
      cacheBytes: cacheBytes,
    ));
  }

  @override
  Future<LibtorrentTorrentSnapshot?> torrentById(int torrentId) {
    return Future<LibtorrentTorrentSnapshot?>.value(
      snapshotsByTorrentId[torrentId],
    );
  }

  @override
  Stream<LibtorrentTorrentSnapshot> watchTorrent(int torrentId) {
    return _controllerFor(torrentId).stream;
  }

  StreamController<LibtorrentTorrentSnapshot> _controllerFor(int torrentId) {
    return _controllersByTorrentId.putIfAbsent(
      torrentId,
      () => StreamController<LibtorrentTorrentSnapshot>.broadcast(sync: true),
    );
  }
}
