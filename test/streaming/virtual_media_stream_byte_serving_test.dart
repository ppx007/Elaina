// Virtual media stream byte-serving tests assert range content and response
// behavior separately from runtime restart orchestration.
import 'dart:io';

import 'package:elaina/elaina.dart';
import 'package:flutter_test/flutter_test.dart';

const String _taskId = 'task-1';
const int _fileIndex = 1;
const int _fileLengthBytes = 8;
const List<int> _fileBytes = <int>[0, 1, 2, 3, 4, 5, 6, 7];
const BtByteRange _servedRange = BtByteRange(start: 2, endInclusive: 6);
const int _testChunkSizeBytes = 3;

void main() {
  test('file byte source serves selected virtual stream ranges', () async {
    final Directory directory =
        await Directory.systemTemp.createTemp('elaina-byte-serving-');
    try {
      final File mediaFile = File('${directory.path}/episode.mkv');
      await mediaFile.writeAsBytes(_fileBytes);
      final _VirtualByteServingHarness harness =
          await _VirtualByteServingHarness.create(mediaFile.uri);

      final VirtualMediaStreamRuntimeActionResult<VirtualMediaStreamSnapshot>
          created = await harness.runtime.createStream(
        const VirtualMediaStreamCreateRequest(
          taskId: BtTaskId(_taskId),
          fileIndex: BtFileIndex(_fileIndex),
        ),
      );
      final Future<CacheInvalidationEvent> bufferedEvent =
          harness.bus.events.firstWhere((CacheInvalidationEvent event) {
        return event is VirtualStreamRangeBuffered;
      });
      final VirtualMediaStreamRuntimeActionResult<Stream<VirtualByteRangeChunk>>
          opened = await harness.runtime.openRange(
        const VirtualByteRangeRequest(
          streamId: VirtualMediaStreamId('task-1::1'),
          range: _servedRange,
        ),
      );
      final List<VirtualByteRangeChunk> chunks = await opened.value!.toList();
      final List<StoredVirtualStreamBufferedRangeRecord> ranges =
          await harness.streamStore.bufferedRangesFor('task-1::1');

      expect(created.isSuccess, isTrue);
      expect(created.value?.descriptor.contentUri, mediaFile.uri);
      expect(opened.isSuccess, isTrue);
      expect(
        chunks.map((VirtualByteRangeChunk chunk) => chunk.bytes),
        <List<int>>[
          <int>[2, 3, 4],
          <int>[5, 6],
        ],
      );
      expect(chunks.first.range.start, _servedRange.start);
      expect(chunks.last.range.endInclusive, _servedRange.endInclusive);
      expect(ranges.single.startByte, _servedRange.start);
      expect(ranges.single.endByte, _servedRange.endInclusive);
      expect(await bufferedEvent, isA<VirtualStreamRangeBuffered>());
      await harness.close();
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('file byte source reports missing selected file as typed failure',
      () async {
    final Uri missingFileUri = Uri.file('Z:/elaina/missing-episode.mkv');
    final _VirtualByteServingHarness harness =
        await _VirtualByteServingHarness.create(missingFileUri);
    await harness.runtime.createStream(
      const VirtualMediaStreamCreateRequest(
        taskId: BtTaskId(_taskId),
        fileIndex: BtFileIndex(_fileIndex),
      ),
    );

    final VirtualMediaStreamRuntimeActionResult<VirtualMediaStreamSnapshot>
        ensured = await harness.runtime.ensureRange(
      const VirtualByteRangeRequest(
        streamId: VirtualMediaStreamId('task-1::1'),
        range: _servedRange,
      ),
    );
    final StoredVirtualStreamEventRecord? latestEvent =
        await harness.streamStore.latestEvent('task-1::1');

    expect(ensured.isSuccess, isFalse);
    expect(
      ensured.failure?.kind,
      VirtualMediaStreamRuntimeFailureKind.fileUnavailable,
    );
    expect(latestEvent?.eventKind, StoredVirtualStreamEventKind.rangeFailed);
    expect(
      latestEvent?.failureKind,
      VirtualMediaStreamFailureKind.fileUnavailable.name,
    );
    await harness.close();
  });
}

final class _VirtualByteServingHarness {
  _VirtualByteServingHarness._({
    required this.taskStore,
    required this.streamStore,
    required this.bus,
    required this.runtime,
  });

  final DeterministicBtTaskStore taskStore;
  final DeterministicVirtualMediaStreamStore streamStore;
  final StreamCacheInvalidationBus bus;
  final VirtualMediaStreamRuntime runtime;

  static Future<_VirtualByteServingHarness> create(Uri fileUri) async {
    final DeterministicBtTaskStore taskStore = DeterministicBtTaskStore();
    final DeterministicVirtualMediaStreamStore streamStore =
        DeterministicVirtualMediaStreamStore();
    final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
    await _seedTask(taskStore, fileUri);
    return _VirtualByteServingHarness._(
      taskStore: taskStore,
      streamStore: streamStore,
      bus: bus,
      runtime: VirtualMediaStreamRuntime.withDependencies(
        btTaskStore: taskStore,
        streamStore: streamStore,
        cacheInvalidationBus: bus,
        contentUriResolver: fileVirtualStreamContentUriResolver,
        byteSource: const FileVirtualByteSource(
          chunkSizeBytes: _testChunkSizeBytes,
        ),
        clock: _now,
      ),
    );
  }

  Future<void> close() => bus.close();
}

Future<void> _seedTask(DeterministicBtTaskStore store, Uri fileUri) async {
  await store.storeTask(
    StoredBtTaskRecord(
      id: _taskId,
      sourceKind: StoredBtTaskSourceKind.magnet,
      sourceUri: 'magnet:?xt=urn:btih:$_taskId',
      lifecycleState: StoredBtTaskLifecycleState.ready,
      createdAt: _now(),
      updatedAt: _now(),
    ),
  );
  await store.storeMetadata(const StoredBtTaskMetadataRecord(
    taskId: _taskId,
    infoHash: 'hash-1',
    name: 'Episode Pack',
    totalSizeBytes: _fileLengthBytes,
    pieceLengthBytes: _fileLengthBytes,
  ));
  await store.storeFiles(
    taskId: _taskId,
    files: <StoredBtTaskFileRecord>[
      StoredBtTaskFileRecord(
        taskId: _taskId,
        index: _fileIndex,
        path: fileUri.toString(),
        lengthBytes: _fileLengthBytes,
        offsetBytes: 0,
        selectionState: StoredBtFileSelectionState.streamingTarget,
        mediaMimeType: 'video/x-matroska',
      ),
    ],
  );
}

DateTime _now() => DateTime.utc(2026, 6, 18, 12);
