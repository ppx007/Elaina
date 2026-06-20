import 'package:elaina/elaina.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('runtime creates deterministic snapshots from selected BT files',
      () async {
    final _RuntimeHarness harness = _RuntimeHarness();
    await _seedTask(harness.taskStore);

    final Future<CacheInvalidationEvent> createdEvent =
        harness.bus.events.first;
    final VirtualMediaStreamRuntimeActionResult<VirtualMediaStreamSnapshot>
        created = await harness.runtime.createStream(
      const VirtualMediaStreamCreateRequest(
        taskId: BtTaskId('task-1'),
        fileIndex: BtFileIndex(1),
      ),
    );

    expect(created.isSuccess, isTrue);
    expect(created.value?.descriptor.id.value, 'task-1::1');
    expect(created.value?.descriptor.taskId.value, 'task-1');
    expect(created.value?.descriptor.fileIndex.value, 1);
    expect(created.value?.descriptor.lengthBytes, 2048);
    expect(created.value?.lifecycleState,
        StoredVirtualMediaStreamLifecycleState.active);
    expect(created.value?.restart.disposition,
        VirtualStreamRestartDisposition.active);
    expect((await createdEvent) is VirtualStreamCreated, isTrue);

    final VirtualMediaStreamRuntimeActionResult<
            List<VirtualMediaStreamSnapshot>> listed =
        await harness.runtime.listStreams();
    expect(listed.value?.single.descriptor.id.value, 'task-1::1');
    expect(
        () => listed.value!.add(listed.value!.single), throwsUnsupportedError);
    expect(created.value!.bufferedRanges, isEmpty);
    await harness.close();
  });

  test(
      'runtime normalizes missing skipped closed failed range and lifecycle failures',
      () async {
    final DeterministicVirtualMediaStreamStore streamStore =
        DeterministicVirtualMediaStreamStore();

    final VirtualMediaStreamRuntime missingTask =
        VirtualMediaStreamRuntime.withDependencies(
      btTaskStore: DeterministicBtTaskStore(),
      streamStore: streamStore,
      clock: _now,
    );
    final VirtualMediaStreamRuntimeActionResult<VirtualMediaStreamSnapshot>
        missingTaskResult = await missingTask.createStream(
      const VirtualMediaStreamCreateRequest(
        taskId: BtTaskId('missing-task'),
        fileIndex: BtFileIndex(0),
      ),
    );
    expect(missingTaskResult.failure?.kind,
        VirtualMediaStreamRuntimeFailureKind.taskUnavailable);

    final DeterministicBtTaskStore missingMetadataStore =
        DeterministicBtTaskStore();
    await missingMetadataStore.storeTask(_taskRecord());
    final VirtualMediaStreamRuntime missingMetadata =
        VirtualMediaStreamRuntime.withDependencies(
      btTaskStore: missingMetadataStore,
      streamStore: DeterministicVirtualMediaStreamStore(),
      clock: _now,
    );
    final VirtualMediaStreamRuntimeActionResult<VirtualMediaStreamSnapshot>
        missingMetadataResult = await missingMetadata.createStream(
      const VirtualMediaStreamCreateRequest(
        taskId: BtTaskId('task-1'),
        fileIndex: BtFileIndex(1),
      ),
    );
    expect(missingMetadataResult.failure?.kind,
        VirtualMediaStreamRuntimeFailureKind.metadataUnavailable);

    final DeterministicBtTaskStore skippedStore = DeterministicBtTaskStore();
    await _seedTask(skippedStore);
    final VirtualMediaStreamRuntime skippedRuntime =
        VirtualMediaStreamRuntime.withDependencies(
      btTaskStore: skippedStore,
      streamStore: DeterministicVirtualMediaStreamStore(),
      clock: _now,
    );
    final VirtualMediaStreamRuntimeActionResult<VirtualMediaStreamSnapshot>
        skippedResult = await skippedRuntime.createStream(
      const VirtualMediaStreamCreateRequest(
        taskId: BtTaskId('task-1'),
        fileIndex: BtFileIndex(0),
      ),
    );
    expect(skippedResult.failure?.kind,
        VirtualMediaStreamRuntimeFailureKind.fileSkipped);

    final _RuntimeHarness harness = _RuntimeHarness();
    await _seedTask(harness.taskStore);
    await harness.runtime.createStream(const VirtualMediaStreamCreateRequest(
      taskId: BtTaskId('task-1'),
      fileIndex: BtFileIndex(1),
    ));
    await harness.runtime.closeStream(const VirtualMediaStreamId('task-1::1'));
    final VirtualMediaStreamRuntimeActionResult<VirtualMediaStreamSnapshot>
        closedRange = await harness.runtime.ensureRange(
      const VirtualByteRangeRequest(
        streamId: VirtualMediaStreamId('task-1::1'),
        range: BtByteRange(start: 0, endInclusive: 255),
      ),
    );
    expect(closedRange.failure?.kind,
        VirtualMediaStreamRuntimeFailureKind.streamClosed);

    final _RuntimeHarness failedHarness = _RuntimeHarness();
    await _seedTask(failedHarness.taskStore);
    await failedHarness.runtime
        .createStream(const VirtualMediaStreamCreateRequest(
      taskId: BtTaskId('task-1'),
      fileIndex: BtFileIndex(1),
    ));
    await failedHarness.runtime.failStream(
      const VirtualMediaStreamId('task-1::1'),
      message: 'Range adapter unavailable.',
    );
    final VirtualMediaStreamRuntimeActionResult<VirtualMediaStreamSnapshot>
        failedRange = await failedHarness.runtime.ensureRange(
      const VirtualByteRangeRequest(
        streamId: VirtualMediaStreamId('task-1::1'),
        range: BtByteRange(start: 0, endInclusive: 255),
      ),
    );
    expect(failedRange.failure?.kind,
        VirtualMediaStreamRuntimeFailureKind.streamFailed);

    final _RuntimeHarness rangeHarness = _RuntimeHarness();
    await _seedTask(rangeHarness.taskStore);
    await rangeHarness.runtime
        .createStream(const VirtualMediaStreamCreateRequest(
      taskId: BtTaskId('task-1'),
      fileIndex: BtFileIndex(1),
    ));
    final VirtualMediaStreamRuntimeActionResult<VirtualMediaStreamSnapshot>
        outOfRange = await rangeHarness.runtime.ensureRange(
      const VirtualByteRangeRequest(
        streamId: VirtualMediaStreamId('task-1::1'),
        range: BtByteRange(start: 2048, endInclusive: 2050),
      ),
    );
    expect(outOfRange.failure?.kind,
        VirtualMediaStreamRuntimeFailureKind.rangeUnavailable);

    await rangeHarness.runtime.dispose();
    final VirtualMediaStreamRuntimeActionResult<
            List<VirtualMediaStreamSnapshot>> disposed =
        await rangeHarness.runtime.listStreams();
    expect(disposed.kind, VirtualMediaStreamRuntimeActionResultKind.disposed);
    expect(
        disposed.failure?.kind, VirtualMediaStreamRuntimeFailureKind.disposed);

    final VirtualMediaStreamRuntime unavailable =
        VirtualMediaStreamRuntime.unavailable(reason: 'No range adapter.');
    final VirtualMediaStreamRuntimeActionResult<VirtualMediaStreamSnapshot>
        unavailableResult = await unavailable.createStream(
      const VirtualMediaStreamCreateRequest(
        taskId: BtTaskId('task-1'),
        fileIndex: BtFileIndex(1),
      ),
    );
    expect(unavailableResult.kind,
        VirtualMediaStreamRuntimeActionResultKind.unavailable);
    expect(unavailableResult.failure?.kind,
        VirtualMediaStreamRuntimeFailureKind.unavailable);

    await harness.close();
    await failedHarness.close();
    await rangeHarness.close();
  });

  test('runtime replays buffered ranges events and restart dispositions',
      () async {
    final DateTime now = _now();
    final DeterministicBtTaskStore taskStore = DeterministicBtTaskStore(
      seedTasks: <StoredBtTaskRecord>[
        _taskRecord(id: 'active-task'),
        _taskRecord(id: 'closed-task'),
        _taskRecord(id: 'failed-task'),
        _taskRecord(id: 'range-task'),
        _taskRecord(id: 'incomplete-task'),
      ],
    );
    await taskStore.storeMetadata(const StoredBtTaskMetadataRecord(
      taskId: 'active-task',
      infoHash: 'active-hash',
      name: 'Active Pack',
      totalSizeBytes: 2048,
      pieceLengthBytes: 1024,
    ));
    await taskStore.storeMetadata(const StoredBtTaskMetadataRecord(
      taskId: 'closed-task',
      infoHash: 'closed-hash',
      name: 'Closed Pack',
      totalSizeBytes: 2048,
      pieceLengthBytes: 1024,
    ));
    await taskStore.storeMetadata(const StoredBtTaskMetadataRecord(
      taskId: 'failed-task',
      infoHash: 'failed-hash',
      name: 'Failed Pack',
      totalSizeBytes: 2048,
      pieceLengthBytes: 1024,
    ));
    await taskStore.storeMetadata(const StoredBtTaskMetadataRecord(
      taskId: 'range-task',
      infoHash: 'range-hash',
      name: 'Range Pack',
      totalSizeBytes: 2048,
      pieceLengthBytes: 1024,
    ));
    await taskStore.storeFiles(
      taskId: 'active-task',
      files: const <StoredBtTaskFileRecord>[
        StoredBtTaskFileRecord(
          taskId: 'active-task',
          index: 0,
          path: 'active.mkv',
          lengthBytes: 2048,
          offsetBytes: 0,
          selectionState: StoredBtFileSelectionState.streamingTarget,
          mediaMimeType: 'video/x-matroska',
        ),
      ],
    );
    await taskStore.storeFiles(
      taskId: 'closed-task',
      files: const <StoredBtTaskFileRecord>[
        StoredBtTaskFileRecord(
          taskId: 'closed-task',
          index: 0,
          path: 'closed.mkv',
          lengthBytes: 2048,
          offsetBytes: 0,
          selectionState: StoredBtFileSelectionState.streamingTarget,
        ),
      ],
    );
    await taskStore.storeFiles(
      taskId: 'failed-task',
      files: const <StoredBtTaskFileRecord>[
        StoredBtTaskFileRecord(
          taskId: 'failed-task',
          index: 0,
          path: 'failed.mkv',
          lengthBytes: 2048,
          offsetBytes: 0,
          selectionState: StoredBtFileSelectionState.streamingTarget,
        ),
      ],
    );
    await taskStore.storeFiles(
      taskId: 'range-task',
      files: const <StoredBtTaskFileRecord>[
        StoredBtTaskFileRecord(
          taskId: 'range-task',
          index: 0,
          path: 'range.mkv',
          lengthBytes: 2048,
          offsetBytes: 0,
          selectionState: StoredBtFileSelectionState.streamingTarget,
        ),
      ],
    );

    final DeterministicVirtualMediaStreamStore streamStore =
        DeterministicVirtualMediaStreamStore(
      seedStreams: <StoredVirtualMediaStreamRecord>[
        _streamRecord('active-task::0', 'active-task', 0,
            StoredVirtualMediaStreamLifecycleState.active, now),
        _streamRecord('closed-task::0', 'closed-task', 0,
            StoredVirtualMediaStreamLifecycleState.closed, now),
        _streamRecord('failed-task::0', 'failed-task', 0,
            StoredVirtualMediaStreamLifecycleState.failed, now,
            message: 'Upstream failed.'),
        _streamRecord('missing-task::0', 'missing-task', 0,
            StoredVirtualMediaStreamLifecycleState.active, now),
        _streamRecord('incomplete-task::0', 'incomplete-task', 0,
            StoredVirtualMediaStreamLifecycleState.active, now),
        _streamRecord('range-task::0', 'range-task', 0,
            StoredVirtualMediaStreamLifecycleState.active, now),
      ],
    );
    await streamStore
        .recordBufferedRange(StoredVirtualStreamBufferedRangeRecord(
      streamId: 'active-task::0',
      startByte: 0,
      endByte: 511,
      observedAt: now,
    ));
    await streamStore.recordEvent(StoredVirtualStreamEventRecord(
      streamId: 'range-task::0',
      eventKind: StoredVirtualStreamEventKind.rangeFailed,
      occurredAt: now,
      rangeStart: 1024,
      rangeEnd: 1535,
      failureKind: VirtualMediaStreamFailureKind.rangeUnavailable.name,
      message: 'Requested range exceeds virtual stream length.',
    ));
    await streamStore.recordEvent(StoredVirtualStreamEventRecord(
      streamId: 'failed-task::0',
      eventKind: StoredVirtualStreamEventKind.failed,
      occurredAt: now,
      failureKind: VirtualMediaStreamFailureKind.streamFailed.name,
      message: 'Upstream failed.',
    ));

    final VirtualMediaStreamRuntime runtime =
        VirtualMediaStreamRuntime.withDependencies(
      btTaskStore: taskStore,
      streamStore: streamStore,
      clock: _now,
    );

    final VirtualMediaStreamRuntimeActionResult<
            List<VirtualMediaStreamSnapshot>> listed =
        await runtime.listStreams(limit: 10);
    final VirtualMediaStreamRuntimeActionResult<
            List<VirtualStreamRestartProjection>> restart =
        await runtime.restartReconciliation();
    final Map<String, VirtualStreamRestartDisposition> dispositions =
        <String, VirtualStreamRestartDisposition>{
      for (final VirtualStreamRestartProjection projection in restart.value!)
        projection.streamId.value: projection.disposition,
    };
    final VirtualMediaStreamSnapshot active = listed.value!.firstWhere(
        (VirtualMediaStreamSnapshot s) =>
            s.descriptor.id.value == 'active-task::0');

    expect(
        dispositions['active-task::0'], VirtualStreamRestartDisposition.active);
    expect(
        dispositions['closed-task::0'], VirtualStreamRestartDisposition.closed);
    expect(
        dispositions['failed-task::0'], VirtualStreamRestartDisposition.failed);
    expect(dispositions['missing-task::0'],
        VirtualStreamRestartDisposition.missingTask);
    expect(dispositions['incomplete-task::0'],
        VirtualStreamRestartDisposition.incomplete);
    expect(dispositions['range-task::0'],
        VirtualStreamRestartDisposition.rangeFailed);
    expect(active.bufferedRanges.single.range.endByte, 511);
    expect(active.latestFailure, isNull);
    expect(() => active.bufferedRanges.add(active.bufferedRanges.single),
        throwsUnsupportedError);
  });

  test('runtime publishes invalidations after durable mutations', () async {
    final _RuntimeHarness harness = _RuntimeHarness();
    await _seedTask(harness.taskStore);
    await harness.runtime.createStream(const VirtualMediaStreamCreateRequest(
      taskId: BtTaskId('task-1'),
      fileIndex: BtFileIndex(1),
    ));

    final Future<List<CacheInvalidationEvent>> events =
        harness.bus.events.take(3).toList();
    final VirtualMediaStreamRuntimeActionResult<VirtualMediaStreamSnapshot>
        buffered = await harness.runtime.ensureRange(
      const VirtualByteRangeRequest(
        streamId: VirtualMediaStreamId('task-1::1'),
        range: BtByteRange(start: 0, endInclusive: 255),
      ),
    );
    final VirtualMediaStreamRuntimeActionResult<VirtualMediaStreamSnapshot>
        rangeFailed = await harness.runtime.ensureRange(
      const VirtualByteRangeRequest(
        streamId: VirtualMediaStreamId('task-1::1'),
        range: BtByteRange(start: 4096, endInclusive: 4097),
      ),
    );
    final VirtualMediaStreamRuntimeActionResult<VirtualMediaStreamSnapshot>
        failed = await harness.runtime.failStream(
      const VirtualMediaStreamId('task-1::1'),
      message: 'Adapter went away.',
    );
    final List<CacheInvalidationEvent> delivered = await events;

    expect(buffered.isSuccess, isTrue);
    expect(
        (await harness.streamStore.bufferedRangesFor('task-1::1'))
            .single
            .endByte,
        255);
    expect(rangeFailed.failure?.kind,
        VirtualMediaStreamRuntimeFailureKind.rangeUnavailable);
    expect((await harness.streamStore.latestEvent('task-1::1'))?.eventKind,
        StoredVirtualStreamEventKind.failed);
    expect(failed.value?.lifecycleState,
        StoredVirtualMediaStreamLifecycleState.failed);
    expect(delivered.whereType<VirtualStreamRangeBuffered>().length, 1);
    expect(delivered.whereType<VirtualStreamRangeFailed>().length, 1);
    expect(delivered.whereType<VirtualStreamFailed>().length, 1);
    await harness.close();
  });
}

final class _RuntimeHarness {
  _RuntimeHarness()
      : taskStore = DeterministicBtTaskStore(),
        streamStore = DeterministicVirtualMediaStreamStore(),
        bus = StreamCacheInvalidationBus() {
    runtime = VirtualMediaStreamRuntime.withDependencies(
      btTaskStore: taskStore,
      streamStore: streamStore,
      cacheInvalidationBus: bus,
      clock: _now,
    );
  }

  final DeterministicBtTaskStore taskStore;
  final DeterministicVirtualMediaStreamStore streamStore;
  final StreamCacheInvalidationBus bus;
  late final VirtualMediaStreamRuntime runtime;

  Future<void> close() => bus.close();
}

Future<void> _seedTask(DeterministicBtTaskStore store) async {
  await store.storeTask(_taskRecord());
  await store.storeMetadata(const StoredBtTaskMetadataRecord(
    taskId: 'task-1',
    infoHash: 'hash-1',
    name: 'Episode Pack',
    totalSizeBytes: 3072,
    pieceLengthBytes: 1024,
  ));
  await store.storeFiles(
    taskId: 'task-1',
    files: const <StoredBtTaskFileRecord>[
      StoredBtTaskFileRecord(
        taskId: 'task-1',
        index: 0,
        path: 'Episode 1.mkv',
        lengthBytes: 1024,
        offsetBytes: 0,
        selectionState: StoredBtFileSelectionState.skipped,
      ),
      StoredBtTaskFileRecord(
        taskId: 'task-1',
        index: 1,
        path: 'Episode 2.mkv',
        lengthBytes: 2048,
        offsetBytes: 1024,
        selectionState: StoredBtFileSelectionState.streamingTarget,
        mediaMimeType: 'video/x-matroska',
      ),
    ],
  );
}

StoredBtTaskRecord _taskRecord({
  String id = 'task-1',
  StoredBtTaskLifecycleState lifecycleState = StoredBtTaskLifecycleState.ready,
}) {
  return StoredBtTaskRecord(
    id: id,
    sourceKind: StoredBtTaskSourceKind.magnet,
    sourceUri: 'magnet:?xt=urn:btih:$id',
    lifecycleState: lifecycleState,
    createdAt: _now(),
    updatedAt: _now(),
  );
}

StoredVirtualMediaStreamRecord _streamRecord(
  String id,
  String taskId,
  int fileIndex,
  StoredVirtualMediaStreamLifecycleState lifecycleState,
  DateTime now, {
  String? message,
}) {
  return StoredVirtualMediaStreamRecord(
    id: id,
    taskId: taskId,
    fileIndex: fileIndex,
    lengthBytes: 2048,
    lifecycleState: lifecycleState,
    createdAt: now,
    updatedAt: now,
    message: message,
  );
}

DateTime _now() => DateTime.utc(2026, 6, 12, 12);
