import 'dart:async';

import 'package:celesteria/celesteria.dart';
import 'package:flutter_test/flutter_test.dart';

const int _torrentId = 1;
const String _torrentIdValue = '1';
const String _magnetUri = 'magnet:?xt=urn:btih:abc123';
const String _infoHash = 'abc123';
const int _pieceLengthBytes = 1024;
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

  test('libtorrent adapter declares only Step 51 capabilities', () {
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
    for (final BtStreamingCapability capability in <BtStreamingCapability>[
      BtStreamingCapability.virtualMediaStream,
      BtStreamingCapability.piecePriorityScheduling,
      BtStreamingCapability.timelineOverlay,
      BtStreamingCapability.longBackgroundDownload,
    ]) {
      expect(
        completeMetadataAdapter.capabilities.statusOf(capability).supported,
        isFalse,
      );
    }
  });
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

final class _FakeLibtorrentBackend implements LibtorrentEngineBackend {
  _FakeLibtorrentBackend({this.supportsCompleteMetadata = false});

  @override
  final bool supportsCompleteMetadata;

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
    filePrioritiesByTorrentId[torrentId] = <int>[...priorities];
    return Future<void>.value();
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
