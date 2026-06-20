import 'package:elaina/elaina.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('virtual stream store persists streams ranges and latest events',
      () async {
    final DeterministicVirtualMediaStreamStore store =
        DeterministicVirtualMediaStreamStore();
    final DateTime observedAt = DateTime.utc(2026, 6, 5, 12);

    await store.storeStream(
      StoredVirtualMediaStreamRecord(
        id: 'stream-1',
        taskId: 'task-1',
        fileIndex: 0,
        lengthBytes: 1024,
        lifecycleState: StoredVirtualMediaStreamLifecycleState.active,
        createdAt: observedAt,
        updatedAt: observedAt,
      ),
    );
    await store.recordBufferedRange(
      StoredVirtualStreamBufferedRangeRecord(
        streamId: 'stream-1',
        startByte: 0,
        endByte: 255,
        observedAt: observedAt,
      ),
    );
    await store.recordBufferedRange(
      StoredVirtualStreamBufferedRangeRecord(
        streamId: 'stream-1',
        startByte: 256,
        endByte: 511,
        observedAt: observedAt.add(const Duration(seconds: 1)),
      ),
    );
    await store.recordEvent(
      StoredVirtualStreamEventRecord(
        streamId: 'stream-1',
        eventKind: StoredVirtualStreamEventKind.rangeBuffered,
        occurredAt: observedAt,
        rangeStart: 0,
        rangeEnd: 511,
      ),
    );

    expect((await store.findStreamById('stream-1'))?.taskId, 'task-1');
    expect(
        (await store.findStreamForTaskFile(taskId: 'task-1', fileIndex: 0))?.id,
        'stream-1');
    expect((await store.bufferedRangesFor('stream-1')).single.startByte, 0);
    expect((await store.bufferedRangesFor('stream-1')).single.endByte, 511);
    expect((await store.latestEvent('stream-1'))?.eventKind,
        StoredVirtualStreamEventKind.rangeBuffered);
    expect(await store.count(), 1);
  });

  test('registry creates streams from persisted selected BT files', () async {
    final DeterministicBtTaskStore taskStore = DeterministicBtTaskStore();
    final DeterministicVirtualMediaStreamStore streamStore =
        DeterministicVirtualMediaStreamStore();
    final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
    await _seedTask(taskStore);
    final DeterministicVirtualMediaStreamRegistry registry =
        DeterministicVirtualMediaStreamRegistry(
      btTaskStore: taskStore,
      streamStore: streamStore,
      cacheInvalidationBus: bus,
      clock: () => DateTime.utc(2026, 6, 5, 12),
    );

    final Future<CacheInvalidationEvent> createdEvent = bus.events.first;
    final VirtualMediaStreamCreateOutcome outcome =
        await registry.createForFile(
      taskId: const BtTaskId('task-1'),
      fileIndex: const BtFileIndex(1),
    );
    final CacheInvalidationEvent delivered = await createdEvent;

    expect(outcome.isSuccess, isTrue);
    expect(outcome.descriptor?.taskId.value, 'task-1');
    expect(outcome.descriptor?.fileIndex.value, 1);
    expect(outcome.descriptor?.lengthBytes, 2048);
    expect(outcome.descriptor?.mimeType, 'video/x-matroska');
    expect((await streamStore.findStreamById('task-1::1'))?.lifecycleState,
        StoredVirtualMediaStreamLifecycleState.active);
    expect((await streamStore.latestEvent('task-1::1'))?.eventKind,
        StoredVirtualStreamEventKind.created);
    expect(delivered, isA<VirtualStreamCreated>());
    await bus.close();
  });

  test('registry rejects missing metadata and skipped files', () async {
    final DeterministicBtTaskStore missingMetadataStore =
        DeterministicBtTaskStore();
    await missingMetadataStore.storeTask(_taskRecord());
    final DeterministicVirtualMediaStreamRegistry missingMetadataRegistry =
        DeterministicVirtualMediaStreamRegistry(
      btTaskStore: missingMetadataStore,
      streamStore: DeterministicVirtualMediaStreamStore(),
    );

    final VirtualMediaStreamCreateOutcome missingMetadata =
        await missingMetadataRegistry.createForFile(
      taskId: const BtTaskId('task-1'),
      fileIndex: const BtFileIndex(0),
    );

    expect(missingMetadata.isSuccess, isFalse);
    expect(missingMetadata.failure?.kind,
        VirtualMediaStreamFailureKind.metadataUnavailable);

    final DeterministicBtTaskStore skippedFileStore =
        DeterministicBtTaskStore();
    await _seedTask(skippedFileStore);
    final DeterministicVirtualMediaStreamRegistry skippedFileRegistry =
        DeterministicVirtualMediaStreamRegistry(
      btTaskStore: skippedFileStore,
      streamStore: DeterministicVirtualMediaStreamStore(),
    );
    final VirtualMediaStreamCreateOutcome skippedFile =
        await skippedFileRegistry.createForFile(
      taskId: const BtTaskId('task-1'),
      fileIndex: const BtFileIndex(0),
    );

    expect(skippedFile.isSuccess, isFalse);
    expect(
        skippedFile.failure?.kind, VirtualMediaStreamFailureKind.fileSkipped);
  });

  test('stream records buffered ranges failures closure and invalidations',
      () async {
    final DeterministicBtTaskStore taskStore = DeterministicBtTaskStore();
    final DeterministicVirtualMediaStreamStore streamStore =
        DeterministicVirtualMediaStreamStore();
    final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
    await _seedTask(taskStore);
    final DeterministicVirtualMediaStreamRegistry registry =
        DeterministicVirtualMediaStreamRegistry(
      btTaskStore: taskStore,
      streamStore: streamStore,
      cacheInvalidationBus: bus,
      clock: () => DateTime.utc(2026, 6, 5, 12),
    );
    await registry.createForFile(
      taskId: const BtTaskId('task-1'),
      fileIndex: const BtFileIndex(1),
    );
    final VirtualMediaStream stream =
        (await registry.streamFor(const VirtualMediaStreamId('task-1::1')))!;

    final Future<List<CacheInvalidationEvent>> events =
        bus.events.take(3).toList();
    final VirtualRangeEnsureOutcome ensured = await stream.ensureRange(
      const VirtualByteRangeRequest(
        streamId: VirtualMediaStreamId('task-1::1'),
        range: BtByteRange(start: 0, endInclusive: 511),
      ),
    );
    final VirtualRangeEnsureOutcome failed = await stream.ensureRange(
      const VirtualByteRangeRequest(
        streamId: VirtualMediaStreamId('task-1::1'),
        range: BtByteRange(start: 2048, endInclusive: 2050),
      ),
    );
    final VirtualStreamCommandOutcome closed = await stream.close();
    final List<CacheInvalidationEvent> delivered = await events;

    expect(ensured.isSuccess, isTrue);
    expect(failed.isSuccess, isFalse);
    expect(
        failed.failure?.kind, VirtualMediaStreamFailureKind.rangeUnavailable);
    expect(closed.isSuccess, isTrue);
    expect((await stream.bufferedRanges()).single.range.endByte, 511);
    expect((await streamStore.findStreamById('task-1::1'))?.lifecycleState,
        StoredVirtualMediaStreamLifecycleState.closed);
    expect(delivered.whereType<VirtualStreamRangeBuffered>().length, 1);
    expect(delivered.whereType<VirtualStreamRangeFailed>().length, 1);
    expect(delivered.whereType<VirtualStreamClosed>().length, 1);
    await bus.close();
  });

  test('openRange reports typed failures without byte-serving implementation',
      () async {
    final DeterministicVirtualMediaStreamStore streamStore =
        DeterministicVirtualMediaStreamStore();
    final DateTime observedAt = DateTime.utc(2026, 6, 5, 12);
    await streamStore.storeStream(
      StoredVirtualMediaStreamRecord(
        id: 'stream-1',
        taskId: 'task-1',
        fileIndex: 0,
        lengthBytes: 1024,
        lifecycleState: StoredVirtualMediaStreamLifecycleState.active,
        createdAt: observedAt,
        updatedAt: observedAt,
      ),
    );
    final DeterministicVirtualMediaStream stream =
        DeterministicVirtualMediaStream(
      descriptor: const VirtualMediaStreamDescriptor(
        id: VirtualMediaStreamId('stream-1'),
        taskId: BtTaskId('task-1'),
        fileIndex: BtFileIndex(0),
        lengthBytes: 1024,
      ),
      store: streamStore,
    );

    expect(
      stream
          .openRange(
            const VirtualByteRangeRequest(
              streamId: VirtualMediaStreamId('other-stream'),
              range: BtByteRange(start: 0, endInclusive: 1),
            ),
          )
          .toList(),
      throwsA(isA<VirtualMediaStreamFailure>()),
    );
  });
}

Future<void> _seedTask(DeterministicBtTaskStore store) async {
  await store.storeTask(_taskRecord());
  await store.storeMetadata(
    const StoredBtTaskMetadataRecord(
      taskId: 'task-1',
      infoHash: 'abc',
      name: 'Episode Pack',
      totalSizeBytes: 3072,
      pieceLengthBytes: 1024,
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

StoredBtTaskRecord _taskRecord() {
  final DateTime observedAt = DateTime.utc(2026, 6, 5, 12);
  return StoredBtTaskRecord(
    id: 'task-1',
    sourceKind: StoredBtTaskSourceKind.magnet,
    sourceUri: 'magnet:?xt=urn:btih:abc',
    lifecycleState: StoredBtTaskLifecycleState.ready,
    createdAt: observedAt,
    updatedAt: observedAt,
  );
}
