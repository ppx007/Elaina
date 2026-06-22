// Virtual media stream runtime contract validates stream creation and byte-range
// restart state from the CLI, separate from playback adapter tests.
// Byte-source serving tests own range content assertions.
import '../../lib/elaina.dart';

Future<void> main() async {
  await verifyVirtualMediaStreamRuntimeContract();
}

Future<void> verifyVirtualMediaStreamRuntimeContract() async {
  final DeterministicBtTaskStore taskStore = DeterministicBtTaskStore();
  final DeterministicVirtualMediaStreamStore streamStore =
      DeterministicVirtualMediaStreamStore();
  final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
  final VirtualMediaStreamRuntime runtime =
      VirtualMediaStreamRuntime.withDependencies(
    btTaskStore: taskStore,
    streamStore: streamStore,
    cacheInvalidationBus: bus,
    clock: _now,
  );

  await _seedTask(taskStore);

  final Future<CacheInvalidationEvent> createdEvent = bus.events.first;
  final VirtualMediaStreamRuntimeActionResult<VirtualMediaStreamSnapshot>
      created = await runtime.createStream(
    const VirtualMediaStreamCreateRequest(
      taskId: BtTaskId('check-task-1'),
      fileIndex: BtFileIndex(1),
    ),
  );
  _expect(created.isSuccess, 'Runtime must create a stream snapshot.');
  _expect(created.value?.descriptor.id.value == 'check-task-1::1',
      'Runtime must create deterministic stream ids.');
  _expect((await createdEvent) is VirtualStreamCreated,
      'Runtime must publish created invalidation.');

  final Future<List<CacheInvalidationEvent>> mutationEvents =
      bus.events.take(3).toList();
  final VirtualMediaStreamRuntimeActionResult<VirtualMediaStreamSnapshot>
      ensured = await runtime.ensureRange(
    const VirtualByteRangeRequest(
      streamId: VirtualMediaStreamId('check-task-1::1'),
      range: BtByteRange(start: 0, endInclusive: 511),
    ),
  );
  _expect(ensured.isSuccess, 'Runtime must record buffered ranges.');
  _expect(ensured.value?.bufferedRanges.single.range.endByte == 511,
      'Runtime must project buffered ranges from storage.');

  final VirtualMediaStreamRuntimeActionResult<VirtualMediaStreamSnapshot>
      rangeFailed = await runtime.ensureRange(
    const VirtualByteRangeRequest(
      streamId: VirtualMediaStreamId('check-task-1::1'),
      range: BtByteRange(start: 5000, endInclusive: 5001),
    ),
  );
  _expect(
      rangeFailed.failure?.kind ==
          VirtualMediaStreamRuntimeFailureKind.rangeUnavailable,
      'Runtime must normalize out-of-range failures.');

  final VirtualMediaStreamRuntimeActionResult<VirtualMediaStreamSnapshot>
      failed = await runtime.failStream(
    const VirtualMediaStreamId('check-task-1::1'),
    message: 'Adapter boundary unavailable.',
  );
  _expect(
      failed.value?.lifecycleState ==
          StoredVirtualMediaStreamLifecycleState.failed,
      'Runtime must persist failed lifecycle state.');

  final List<CacheInvalidationEvent> delivered = await mutationEvents;
  _expect(delivered.whereType<VirtualStreamRangeBuffered>().length == 1,
      'Runtime must publish range-buffered invalidation.');
  _expect(delivered.whereType<VirtualStreamRangeFailed>().length == 1,
      'Runtime must publish range-failed invalidation.');
  _expect(delivered.whereType<VirtualStreamFailed>().length == 1,
      'Runtime must publish failed invalidation.');

  final DeterministicBtTaskStore restartTaskStore = DeterministicBtTaskStore(
    seedTasks: <StoredBtTaskRecord>[
      _taskRecord('active-task'),
      _taskRecord('closed-task'),
      _taskRecord('failed-task'),
      _taskRecord('range-task'),
      _taskRecord('incomplete-task'),
    ],
  );
  await restartTaskStore.storeMetadata(const StoredBtTaskMetadataRecord(
    taskId: 'active-task',
    infoHash: 'active-hash',
    name: 'Active Pack',
    totalSizeBytes: 2048,
    pieceLengthBytes: 1024,
  ));
  await restartTaskStore.storeMetadata(const StoredBtTaskMetadataRecord(
    taskId: 'closed-task',
    infoHash: 'closed-hash',
    name: 'Closed Pack',
    totalSizeBytes: 2048,
    pieceLengthBytes: 1024,
  ));
  await restartTaskStore.storeMetadata(const StoredBtTaskMetadataRecord(
    taskId: 'failed-task',
    infoHash: 'failed-hash',
    name: 'Failed Pack',
    totalSizeBytes: 2048,
    pieceLengthBytes: 1024,
  ));
  await restartTaskStore.storeMetadata(const StoredBtTaskMetadataRecord(
    taskId: 'range-task',
    infoHash: 'range-hash',
    name: 'Range Pack',
    totalSizeBytes: 2048,
    pieceLengthBytes: 1024,
  ));
  for (final String taskId in <String>[
    'active-task',
    'closed-task',
    'failed-task',
    'range-task',
  ]) {
    await restartTaskStore.storeFiles(
      taskId: taskId,
      files: <StoredBtTaskFileRecord>[
        StoredBtTaskFileRecord(
          taskId: taskId,
          index: 0,
          path: '$taskId.mkv',
          lengthBytes: 2048,
          offsetBytes: 0,
          selectionState: StoredBtFileSelectionState.streamingTarget,
        ),
      ],
    );
  }

  final DeterministicVirtualMediaStreamStore restartStreamStore =
      DeterministicVirtualMediaStreamStore(
    seedStreams: <StoredVirtualMediaStreamRecord>[
      _streamRecord('active-task::0', 'active-task', 0,
          StoredVirtualMediaStreamLifecycleState.active),
      _streamRecord('closed-task::0', 'closed-task', 0,
          StoredVirtualMediaStreamLifecycleState.closed),
      _streamRecord('failed-task::0', 'failed-task', 0,
          StoredVirtualMediaStreamLifecycleState.failed,
          message: 'Persistent failure.'),
      _streamRecord('range-task::0', 'range-task', 0,
          StoredVirtualMediaStreamLifecycleState.active),
      _streamRecord('missing-task::0', 'missing-task', 0,
          StoredVirtualMediaStreamLifecycleState.active),
      _streamRecord('incomplete-task::0', 'incomplete-task', 0,
          StoredVirtualMediaStreamLifecycleState.active),
    ],
  );
  await restartStreamStore.recordEvent(StoredVirtualStreamEventRecord(
    streamId: 'range-task::0',
    eventKind: StoredVirtualStreamEventKind.rangeFailed,
    occurredAt: _now(),
    failureKind: VirtualMediaStreamFailureKind.rangeUnavailable.name,
    message: 'Requested range exceeds virtual stream length.',
  ));

  final VirtualMediaStreamRuntime restartRuntime =
      VirtualMediaStreamRuntime.withDependencies(
    btTaskStore: restartTaskStore,
    streamStore: restartStreamStore,
    clock: _now,
  );
  final VirtualMediaStreamRuntimeActionResult<
          List<VirtualStreamRestartProjection>> restart =
      await restartRuntime.restartReconciliation();
  final Map<String, VirtualStreamRestartDisposition> dispositions =
      <String, VirtualStreamRestartDisposition>{
    for (final VirtualStreamRestartProjection projection in restart.value!)
      projection.streamId.value: projection.disposition,
  };
  _expect(
      dispositions['active-task::0'] == VirtualStreamRestartDisposition.active,
      'Restart must classify active streams.');
  _expect(
      dispositions['closed-task::0'] == VirtualStreamRestartDisposition.closed,
      'Restart must classify closed streams.');
  _expect(
      dispositions['failed-task::0'] == VirtualStreamRestartDisposition.failed,
      'Restart must classify failed streams.');
  _expect(
      dispositions['range-task::0'] ==
          VirtualStreamRestartDisposition.rangeFailed,
      'Restart must classify range-failed streams.');
  _expect(
      dispositions['missing-task::0'] ==
          VirtualStreamRestartDisposition.missingTask,
      'Restart must classify missing-task streams.');
  _expect(
      dispositions['incomplete-task::0'] ==
          VirtualStreamRestartDisposition.incomplete,
      'Restart must classify incomplete streams.');

  const LocalPlaybackSourceHandoff handoff = LocalPlaybackSourceHandoff();
  final PlaybackSourceHandoffResult handoffResult = handoff.prepare(
    PlaybackSourceHandoffInput.virtualStreamDescriptor(
      _playbackDescriptorFromVirtualSnapshot(created.value!),
    ),
  );
  _expect(handoffResult.source is VirtualStreamPlaybackSource,
      'Playback handoff must stay on virtual stream abstraction.');

  await bus.close();
}

void _expect(bool condition, String message) {
  if (!condition) throw StateError(message);
}

PlaybackVirtualStreamDescriptor _playbackDescriptorFromVirtualSnapshot(
  VirtualMediaStreamSnapshot snapshot,
) {
  return PlaybackVirtualStreamDescriptor(
    id: VirtualPlaybackStreamId(snapshot.descriptor.id.value),
    contentUri: snapshot.descriptor.contentUri,
  );
}

Future<void> _seedTask(DeterministicBtTaskStore store) async {
  await store.storeTask(_taskRecord('check-task-1'));
  await store.storeMetadata(const StoredBtTaskMetadataRecord(
    taskId: 'check-task-1',
    infoHash: 'check-hash',
    name: 'Runtime Check Pack',
    totalSizeBytes: 3072,
    pieceLengthBytes: 1024,
  ));
  await store.storeFiles(
    taskId: 'check-task-1',
    files: const <StoredBtTaskFileRecord>[
      StoredBtTaskFileRecord(
        taskId: 'check-task-1',
        index: 0,
        path: 'Check 1.mkv',
        lengthBytes: 1024,
        offsetBytes: 0,
        selectionState: StoredBtFileSelectionState.skipped,
      ),
      StoredBtTaskFileRecord(
        taskId: 'check-task-1',
        index: 1,
        path: 'Check 2.mkv',
        lengthBytes: 2048,
        offsetBytes: 1024,
        selectionState: StoredBtFileSelectionState.streamingTarget,
        mediaMimeType: 'video/x-matroska',
      ),
    ],
  );
}

StoredBtTaskRecord _taskRecord(String id) {
  return StoredBtTaskRecord(
    id: id,
    sourceKind: StoredBtTaskSourceKind.magnet,
    sourceUri: 'magnet:?xt=urn:btih:$id',
    lifecycleState: StoredBtTaskLifecycleState.ready,
    createdAt: _now(),
    updatedAt: _now(),
  );
}

StoredVirtualMediaStreamRecord _streamRecord(
  String id,
  String taskId,
  int fileIndex,
  StoredVirtualMediaStreamLifecycleState lifecycleState, {
  String? message,
}) {
  return StoredVirtualMediaStreamRecord(
    id: id,
    taskId: taskId,
    fileIndex: fileIndex,
    lengthBytes: 2048,
    lifecycleState: lifecycleState,
    createdAt: _now(),
    updatedAt: _now(),
    message: message,
  );
}

DateTime _now() => DateTime.utc(2026, 6, 12, 12);
