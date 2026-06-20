import 'dart:async';
import 'dart:io';

import '../lib/celesteria.dart';

const int _smokeTorrentId = 55;
const String _smokeInfoHash = 'step55btstreamingsmokegatehash';
const String _smokeMagnetUri =
    'magnet:?xt=urn:btih:$_smokeInfoHash&dn=Step55Smoke';
const int _skippedFileIndex = 0;
const int _selectedFileIndex = 1;
const int _skippedFileLengthBytes = 1024;
const int _selectedFileLengthBytes = 4096;
const int _pieceLengthBytes = 1024;
const int _servedRangeStartByte = 2;
const int _servedRangeEndByte = 17;
const int _smokeChunkSizeBytes = 5;
const String _selectedFileName = 'step55-smoke-episode.mkv';
const String _skippedFileName = 'step55-smoke-extra.mkv';

Future<void> main() async {
  final BtStreamingSmokeGateResult result = await runBtStreamingSmokeGate();
  stdout.writeln(
    'BT streaming smoke gate passed: '
    '${result.metadataFileCount} files, '
    '${result.bytesServed} bytes served, '
    '${result.planRuleCount} priority rules, '
    'priorities ${result.filePriorities}.',
  );
}

final class BtStreamingSmokeGateResult {
  const BtStreamingSmokeGateResult({
    required this.taskId,
    required this.streamId,
    required this.metadataFileCount,
    required this.selectedFileIndex,
    required this.streamCreated,
    required this.bytesServed,
    required this.servedBytes,
    required this.bufferedRangeCount,
    required this.planRuleCount,
    required this.priorityApplied,
    required this.filePriorities,
  });

  final String taskId;
  final String streamId;
  final int metadataFileCount;
  final int selectedFileIndex;
  final bool streamCreated;
  final int bytesServed;
  final List<int> servedBytes;
  final int bufferedRangeCount;
  final int planRuleCount;
  final bool priorityApplied;
  final List<int> filePriorities;
}

Future<BtStreamingSmokeGateResult> runBtStreamingSmokeGate() async {
  final Directory root =
      await Directory.systemTemp.createTemp('celesteria-bt-streaming-smoke-');
  final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
  final DeterministicBtTaskStore btTaskStore = DeterministicBtTaskStore();
  final DeterministicVirtualMediaStreamStore streamStore =
      DeterministicVirtualMediaStreamStore();
  final DeterministicPiecePrioritySchedulerStore schedulerStore =
      DeterministicPiecePrioritySchedulerStore();
  final _SmokeLibtorrentBackend backend = _SmokeLibtorrentBackend();

  try {
    final File mediaFile = File(_join(root.path, _selectedFileName));
    await mediaFile.writeAsBytes(_mediaBytes());
    backend.seedMediaFile(mediaFile.uri);

    final BtTaskCoreRuntime btRuntime = BtTaskCoreRuntime.withComposition(
      composition: libtorrentBtTaskRuntimeComposition(
        store: btTaskStore,
        cacheInvalidationBus: bus,
        backend: backend,
        clock: _now,
      ),
    );
    final BtTaskCoreRuntimeActionResult<BtTaskProjection> created =
        await btRuntime.createTask(
      const BtTaskCreateRequest(
        source: MagnetBtTaskSource(uri: _smokeMagnetUri),
      ),
    );
    _expect(created.isSuccess, 'BT smoke gate must create a task.');

    final BtTaskId taskId = created.value!.taskId;
    final BtTaskCoreRuntimeActionResult<BtTaskProjection> metadata =
        await btRuntime.ensureMetadata(taskId);
    _expect(metadata.isSuccess, 'BT smoke gate must ensure task metadata.');
    _expect(
      metadata.value!.files.length == 2,
      'BT smoke gate must project all backend files.',
    );

    final BtTaskCoreRuntimeActionResult<BtTaskProjection> selected =
        await btRuntime.selectFiles(
      taskId,
      const <BtFileIndex>[BtFileIndex(_selectedFileIndex)],
    );
    _expect(selected.isSuccess, 'BT smoke gate must select the stream file.');

    final VirtualMediaStreamRuntime streamRuntime =
        VirtualMediaStreamRuntime.withDependencies(
      btTaskStore: btTaskStore,
      streamStore: streamStore,
      cacheInvalidationBus: bus,
      contentUriResolver: fileVirtualStreamContentUriResolver,
      byteSource: const FileVirtualByteSource(
        chunkSizeBytes: _smokeChunkSizeBytes,
      ),
      clock: _now,
    );
    final VirtualMediaStreamRuntimeActionResult<VirtualMediaStreamSnapshot>
        stream = await streamRuntime.createStream(
      VirtualMediaStreamCreateRequest(
        taskId: taskId,
        fileIndex: const BtFileIndex(_selectedFileIndex),
      ),
    );
    _expect(stream.isSuccess, 'BT smoke gate must create a virtual stream.');

    const BtByteRange servedRange = BtByteRange(
      start: _servedRangeStartByte,
      endInclusive: _servedRangeEndByte,
    );
    final VirtualMediaStreamId streamId = stream.value!.descriptor.id;
    final VirtualMediaStreamRuntimeActionResult<Stream<VirtualByteRangeChunk>>
        opened = await streamRuntime.openRange(
      VirtualByteRangeRequest(streamId: streamId, range: servedRange),
    );
    _expect(opened.isSuccess, 'BT smoke gate must open virtual byte range.');

    final List<VirtualByteRangeChunk> chunks = await opened.value!.toList();
    final List<int> servedBytes = <int>[
      for (final VirtualByteRangeChunk chunk in chunks) ...chunk.bytes,
    ];
    final List<int> expectedBytes =
        _mediaBytes().sublist(servedRange.start, servedRange.endInclusive + 1);
    _expect(
      _sameBytes(servedBytes, expectedBytes),
      'BT smoke gate must serve selected file bytes.',
    );

    final PiecePrioritySchedulerRuntime schedulerRuntime =
        libtorrentPiecePrioritySchedulerRuntime(
      btTaskStore: btTaskStore,
      streamStore: streamStore,
      schedulerStore: schedulerStore,
      cacheInvalidationBus: bus,
      backend: backend,
      clock: _now,
    );
    final PiecePriorityPlanOutcome plan = await schedulerRuntime.plan(
      PiecePriorityPlanRequest(
        taskId: taskId,
        streamId: streamId,
        profile: PiecePrioritySchedulerRuntime.balancedProfile,
        playbackWindow: PlaybackWindow(
          streamId: streamId,
          currentByteOffset: _servedRangeStartByte,
          lookaheadBytes: _pieceLengthBytes,
        ),
      ),
    );
    _expect(plan.isSuccess, 'BT smoke gate must generate a priority plan.');

    final PiecePriorityApplicationOutcome applied =
        await schedulerRuntime.applyPlan(planId: plan.plan!.id);
    _expect(
      applied.isSuccess,
      'BT smoke gate must apply priority plan through libtorrent boundary.',
    );

    final List<StoredVirtualStreamBufferedRangeRecord> ranges =
        await streamStore.bufferedRangesFor(streamId.value);
    final List<int> priorities =
        backend.filePrioritiesByTorrentId[_smokeTorrentId] ?? const <int>[];
    _expect(
      priorities.length == 2 &&
          priorities[_skippedFileIndex] == libtorrentSkipFilePriority &&
          priorities[_selectedFileIndex] == libtorrentSelectedFilePriority,
      'BT smoke gate must apply selected-file priority through backend.',
    );

    await btRuntime.dispose();
    await streamRuntime.dispose();
    await schedulerRuntime.dispose();

    return BtStreamingSmokeGateResult(
      taskId: taskId.value,
      streamId: streamId.value,
      metadataFileCount: metadata.value!.files.length,
      selectedFileIndex: _selectedFileIndex,
      streamCreated: stream.value!.descriptor.contentUri == mediaFile.uri,
      bytesServed: servedBytes.length,
      servedBytes: List<int>.unmodifiable(servedBytes),
      bufferedRangeCount: ranges.length,
      planRuleCount: plan.plan!.rules.length,
      priorityApplied: applied.isSuccess,
      filePriorities: List<int>.unmodifiable(priorities),
    );
  } finally {
    await backend.close();
    await bus.close();
    if (root.existsSync()) {
      await root.delete(recursive: true);
    }
  }
}

final class _SmokeLibtorrentBackend implements LibtorrentEngineBackend {
  final Map<int, LibtorrentTorrentSnapshot> snapshotsByTorrentId =
      <int, LibtorrentTorrentSnapshot>{};
  final Map<int, List<LibtorrentFileSnapshot>> filesByTorrentId =
      <int, List<LibtorrentFileSnapshot>>{};
  final Map<int, List<int>> filePrioritiesByTorrentId = <int, List<int>>{};
  final Map<int, StreamController<LibtorrentTorrentSnapshot>>
      _controllersByTorrentId =
      <int, StreamController<LibtorrentTorrentSnapshot>>{};

  Uri? _mediaFileUri;

  @override
  bool get supportsCompleteMetadata => true;

  void seedMediaFile(Uri mediaFileUri) {
    _mediaFileUri = mediaFileUri;
  }

  @override
  Future<int> addMagnet(String magnetUri) {
    snapshotsByTorrentId[_smokeTorrentId] = _snapshot();
    filesByTorrentId[_smokeTorrentId] = _files();
    return Future<int>.value(_smokeTorrentId);
  }

  @override
  Future<int> addTorrentFile(Uri uri) {
    snapshotsByTorrentId[_smokeTorrentId] = _snapshot();
    filesByTorrentId[_smokeTorrentId] = _files();
    return Future<int>.value(_smokeTorrentId);
  }

  @override
  Future<List<LibtorrentFileSnapshot>> filesFor(int torrentId) {
    return Future<List<LibtorrentFileSnapshot>>.value(
      filesByTorrentId[torrentId] ?? const <LibtorrentFileSnapshot>[],
    );
  }

  @override
  Future<void> pause(int torrentId) => Future<void>.value();

  @override
  Future<void> remove(int torrentId) => Future<void>.value();

  @override
  Future<void> resume(int torrentId) => Future<void>.value();

  @override
  Future<void> setFilePriorities(int torrentId, List<int> priorities) {
    filePrioritiesByTorrentId[torrentId] = List<int>.unmodifiable(priorities);
    return Future<void>.value();
  }

  @override
  Future<void> primeStreamWindow({
    required int torrentId,
    required int fileIndex,
    required int preloadBytes,
    required int cacheBytes,
  }) async {}

  @override
  Future<LibtorrentTorrentSnapshot?> torrentById(int torrentId) {
    return Future<LibtorrentTorrentSnapshot?>.value(
      snapshotsByTorrentId[torrentId],
    );
  }

  @override
  Stream<LibtorrentTorrentSnapshot> watchTorrent(int torrentId) {
    return _controllersByTorrentId
        .putIfAbsent(
          torrentId,
          () => StreamController<LibtorrentTorrentSnapshot>.broadcast(
            sync: true,
          ),
        )
        .stream;
  }

  Future<void> close() async {
    for (final StreamController<LibtorrentTorrentSnapshot> controller
        in _controllersByTorrentId.values) {
      await controller.close();
    }
  }

  List<LibtorrentFileSnapshot> _files() {
    final Uri? mediaFileUri = _mediaFileUri;
    if (mediaFileUri == null) {
      throw StateError('BT smoke media file URI has not been seeded.');
    }
    return <LibtorrentFileSnapshot>[
      const LibtorrentFileSnapshot(
        index: _skippedFileIndex,
        path: _skippedFileName,
        lengthBytes: _skippedFileLengthBytes,
        isStreamable: false,
      ),
      LibtorrentFileSnapshot(
        index: _selectedFileIndex,
        path: mediaFileUri.toString(),
        lengthBytes: _selectedFileLengthBytes,
        isStreamable: true,
      ),
    ];
  }
}

LibtorrentTorrentSnapshot _snapshot() {
  return const LibtorrentTorrentSnapshot(
    id: _smokeTorrentId,
    name: 'Step 55 Smoke Pack',
    state: LibtorrentTaskState.downloading,
    progress: 0.25,
    downloadRateBytesPerSecond: _pieceLengthBytes,
    uploadRateBytesPerSecond: 0,
    totalSizeBytes: _skippedFileLengthBytes + _selectedFileLengthBytes,
    connectedPeers: 1,
    hasMetadata: true,
    isPaused: false,
    isFinished: false,
    infoHash: _smokeInfoHash,
    pieceLengthBytes: _pieceLengthBytes,
  );
}

List<int> _mediaBytes() {
  return List<int>.generate(
    _selectedFileLengthBytes,
    (int index) => index % 251,
    growable: false,
  );
}

bool _sameBytes(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

DateTime _now() => DateTime.utc(2026, 6, 18, 15);

String _join(String directory, String name) {
  return '$directory${Platform.pathSeparator}$name';
}

void _expect(bool condition, String message) {
  if (!condition) throw StateError(message);
}
