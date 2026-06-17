import 'dart:async';

import 'package:libtorrent_flutter/libtorrent_flutter.dart' as lt;

import 'bt_task_core.dart';

typedef LibtorrentEngineBackendFactory = Future<LibtorrentEngineBackend>
    Function();

typedef LibtorrentMetadataResolver = LibtorrentResolvedMetadata? Function(
    LibtorrentMetadataResolveRequest request);

const String libtorrentDownloadEngineAdapterId = 'libtorrent-download-engine';
const String libtorrentDownloadEngineAdapterDisplayName =
    'libtorrent Download Engine';
const int libtorrentSkipFilePriority = 0;
const int libtorrentSelectedFilePriority = 1;
const String _magnetExactTopicPrefix = 'urn:btih:';

enum LibtorrentTaskState {
  error,
  unknown,
  checkingFiles,
  downloadingMetadata,
  downloading,
  finished,
  seeding,
  allocating,
  checkingResume,
}

final class LibtorrentResolvedMetadata {
  const LibtorrentResolvedMetadata({
    required this.infoHash,
    required this.pieceLengthBytes,
  });

  final String infoHash;
  final int pieceLengthBytes;
}

final class LibtorrentMetadataResolveRequest {
  const LibtorrentMetadataResolveRequest({
    required this.torrentId,
    required this.name,
    required this.totalSizeBytes,
    this.sourceUri,
  });

  final int torrentId;
  final String name;
  final int totalSizeBytes;
  final String? sourceUri;
}

final class LibtorrentTorrentSnapshot {
  const LibtorrentTorrentSnapshot({
    required this.id,
    required this.name,
    required this.state,
    required this.progress,
    required this.downloadRateBytesPerSecond,
    required this.uploadRateBytesPerSecond,
    required this.totalSizeBytes,
    required this.connectedPeers,
    required this.hasMetadata,
    required this.isPaused,
    required this.isFinished,
    this.message,
    this.infoHash,
    this.pieceLengthBytes,
  });

  final int id;
  final String name;
  final LibtorrentTaskState state;
  final double progress;
  final int downloadRateBytesPerSecond;
  final int uploadRateBytesPerSecond;
  final int totalSizeBytes;
  final int connectedPeers;
  final bool hasMetadata;
  final bool isPaused;
  final bool isFinished;
  final String? message;
  final String? infoHash;
  final int? pieceLengthBytes;
}

final class LibtorrentFileSnapshot {
  const LibtorrentFileSnapshot({
    required this.index,
    required this.path,
    required this.lengthBytes,
    required this.isStreamable,
  });

  final int index;
  final String path;
  final int lengthBytes;
  final bool isStreamable;
}

abstract interface class LibtorrentEngineBackend {
  bool get supportsCompleteMetadata;

  Future<int> addMagnet(String magnetUri);

  Future<int> addTorrentFile(Uri uri);

  Future<LibtorrentTorrentSnapshot?> torrentById(int torrentId);

  Future<List<LibtorrentFileSnapshot>> filesFor(int torrentId);

  Future<void> pause(int torrentId);

  Future<void> resume(int torrentId);

  Future<void> remove(int torrentId);

  Future<void> setFilePriorities(int torrentId, List<int> priorities);

  Stream<LibtorrentTorrentSnapshot> watchTorrent(int torrentId);
}

final class _LibtorrentFlutterEngineBackend implements LibtorrentEngineBackend {
  _LibtorrentFlutterEngineBackend({
    required lt.LibtorrentFlutter engine,
    LibtorrentMetadataResolver? metadataResolver,
  })  : _engine = engine,
        _metadataResolver = metadataResolver;

  static Future<_LibtorrentFlutterEngineBackend> initialize({
    String? defaultSavePath,
    Duration? pollInterval,
    LibtorrentMetadataResolver? metadataResolver,
  }) async {
    if (pollInterval == null) {
      await lt.LibtorrentFlutter.init(defaultSavePath: defaultSavePath);
    } else {
      await lt.LibtorrentFlutter.init(
        defaultSavePath: defaultSavePath,
        pollInterval: pollInterval,
      );
    }
    return _LibtorrentFlutterEngineBackend(
      engine: lt.LibtorrentFlutter.instance,
      metadataResolver: metadataResolver,
    );
  }

  final lt.LibtorrentFlutter _engine;
  final LibtorrentMetadataResolver? _metadataResolver;
  final Map<int, String> _sourceUriByTorrentId = <int, String>{};

  @override
  bool get supportsCompleteMetadata => _metadataResolver != null;

  @override
  Future<int> addMagnet(String magnetUri) {
    final int torrentId = _engine.addMagnet(magnetUri);
    _sourceUriByTorrentId[torrentId] = magnetUri;
    return Future<int>.value(torrentId);
  }

  @override
  Future<int> addTorrentFile(Uri uri) {
    if (!uri.isScheme('file')) {
      throw UnsupportedError(
          'libtorrent torrent-data source requires a file URI.');
    }
    final int torrentId = _engine.addTorrentFile(uri.toFilePath());
    _sourceUriByTorrentId[torrentId] = uri.toString();
    return Future<int>.value(torrentId);
  }

  @override
  Future<List<LibtorrentFileSnapshot>> filesFor(int torrentId) {
    return Future<List<LibtorrentFileSnapshot>>.value(
      <LibtorrentFileSnapshot>[
        for (final lt.FileInfo file in _engine.getFiles(torrentId))
          LibtorrentFileSnapshot(
            index: file.index,
            path: file.path,
            lengthBytes: file.size,
            isStreamable: file.isStreamable,
          ),
      ],
    );
  }

  @override
  Future<void> pause(int torrentId) {
    _engine.pauseTorrent(torrentId);
    return Future<void>.value();
  }

  @override
  Future<void> remove(int torrentId) {
    _engine.removeTorrent(torrentId);
    _sourceUriByTorrentId.remove(torrentId);
    return Future<void>.value();
  }

  @override
  Future<void> resume(int torrentId) {
    _engine.resumeTorrent(torrentId);
    return Future<void>.value();
  }

  @override
  Future<void> setFilePriorities(int torrentId, List<int> priorities) {
    _engine.setFilePriorities(torrentId, priorities);
    return Future<void>.value();
  }

  @override
  Future<LibtorrentTorrentSnapshot?> torrentById(int torrentId) {
    return Future<LibtorrentTorrentSnapshot?>.value(
      _snapshotFromInfo(_engine.torrents[torrentId]),
    );
  }

  @override
  Stream<LibtorrentTorrentSnapshot> watchTorrent(int torrentId) async* {
    final LibtorrentTorrentSnapshot? current =
        _snapshotFromInfo(_engine.torrents[torrentId]);
    if (current != null) yield current;
    await for (final Map<int, lt.TorrentInfo> torrents
        in _engine.torrentUpdates) {
      final LibtorrentTorrentSnapshot? snapshot =
          _snapshotFromInfo(torrents[torrentId]);
      if (snapshot != null) yield snapshot;
    }
  }

  LibtorrentTorrentSnapshot? _snapshotFromInfo(lt.TorrentInfo? info) {
    if (info == null) return null;
    final LibtorrentResolvedMetadata? resolved = _metadataResolver?.call(
      LibtorrentMetadataResolveRequest(
        torrentId: info.id,
        name: info.name,
        totalSizeBytes: info.totalWanted,
        sourceUri: _sourceUriByTorrentId[info.id],
      ),
    );
    return LibtorrentTorrentSnapshot(
      id: info.id,
      name: info.name,
      state: _taskState(info.state),
      progress: info.progress,
      downloadRateBytesPerSecond: info.downloadRate,
      uploadRateBytesPerSecond: info.uploadRate,
      totalSizeBytes: info.totalWanted,
      connectedPeers: info.numPeers,
      hasMetadata: info.hasMetadata,
      isPaused: info.isPaused,
      isFinished: info.isFinished,
      message: info.errorMsg == '' ? null : info.errorMsg,
      infoHash:
          resolved?.infoHash ?? _magnetInfoHash(_sourceUriByTorrentId[info.id]),
      pieceLengthBytes: resolved?.pieceLengthBytes,
    );
  }
}

final class LibtorrentDownloadEngineAdapter implements DownloadEngineAdapter {
  LibtorrentDownloadEngineAdapter({
    LibtorrentEngineBackend? backend,
    LibtorrentEngineBackendFactory? backendFactory,
    bool metadataFetchingSupported = false,
  })  : assert(
          backend == null || backendFactory == null,
          'Provide either a backend instance or a backend factory, not both.',
        ),
        _backend = backend,
        _backendFactory =
            backendFactory ?? _LibtorrentFlutterEngineBackend.initialize,
        capabilities = libtorrentDownloadEngineCapabilities(
          metadataFetchingSupported:
              backend?.supportsCompleteMetadata ?? metadataFetchingSupported,
        );

  static Future<LibtorrentDownloadEngineAdapter> initialize({
    String? defaultSavePath,
    Duration? pollInterval,
    LibtorrentMetadataResolver? metadataResolver,
  }) async {
    final _LibtorrentFlutterEngineBackend backend =
        await _LibtorrentFlutterEngineBackend.initialize(
      defaultSavePath: defaultSavePath,
      pollInterval: pollInterval,
      metadataResolver: metadataResolver,
    );
    return LibtorrentDownloadEngineAdapter(backend: backend);
  }

  @override
  final BtCapabilityMatrix capabilities;

  LibtorrentEngineBackend? _backend;
  final LibtorrentEngineBackendFactory _backendFactory;

  @override
  String get displayName => libtorrentDownloadEngineAdapterDisplayName;

  @override
  String get id => libtorrentDownloadEngineAdapterId;

  @override
  Future<BtTaskId> createTask(BtTaskCreateRequest request) async {
    final LibtorrentEngineBackend backend = await _requireBackend();
    final int torrentId = switch (request.source) {
      MagnetBtTaskSource(:final uri) => await backend.addMagnet(uri),
      TorrentDataBtTaskSource(:final uri) => await backend.addTorrentFile(uri),
    };
    return BtTaskId(torrentId.toString());
  }

  @override
  Future<BtTaskMetadata> ensureMetadata(BtTaskId taskId) async {
    final LibtorrentEngineBackend backend = await _requireBackend();
    final int torrentId = _torrentId(taskId);
    final LibtorrentTorrentSnapshot? torrent =
        await backend.torrentById(torrentId);
    if (torrent == null) {
      throw StateError('libtorrent task ${taskId.value} was not found.');
    }
    if (!torrent.hasMetadata) {
      throw StateError(
          'libtorrent metadata is not available for task ${taskId.value}.');
    }
    final String? infoHash = torrent.infoHash;
    final int? pieceLengthBytes = torrent.pieceLengthBytes;
    if (infoHash == null || infoHash == '') {
      throw StateError(
          'libtorrent metadata is missing info hash for task ${taskId.value}.');
    }
    if (pieceLengthBytes == null || pieceLengthBytes <= 0) {
      throw StateError(
          'libtorrent metadata is missing piece length for task ${taskId.value}.');
    }
    final List<LibtorrentFileSnapshot> files =
        await backend.filesFor(torrentId);
    return BtTaskMetadata(
      infoHash: InfoHash(infoHash),
      name: torrent.name,
      totalSizeBytes: _totalSizeBytes(torrent, files),
      pieceLengthBytes: pieceLengthBytes,
      files: _files(files),
    );
  }

  @override
  Future<void> pause(BtTaskId taskId) async {
    await (await _requireBackend()).pause(_torrentId(taskId));
  }

  @override
  Future<void> remove(BtTaskId taskId) async {
    await (await _requireBackend()).remove(_torrentId(taskId));
  }

  @override
  Future<void> resume(BtTaskId taskId) async {
    await (await _requireBackend()).resume(_torrentId(taskId));
  }

  @override
  Future<void> selectFiles(BtTaskId taskId, Iterable<BtFileIndex> files) async {
    final LibtorrentEngineBackend backend = await _requireBackend();
    final int torrentId = _torrentId(taskId);
    final List<LibtorrentFileSnapshot> available =
        await backend.filesFor(torrentId);
    final Set<int> selected = <int>{
      for (final BtFileIndex file in files) file.value,
    };
    final int priorityCount = _priorityCount(available);
    final List<int> priorities =
        List<int>.filled(priorityCount, libtorrentSkipFilePriority);
    for (final int index in selected) {
      if (index >= 0 && index < priorities.length) {
        priorities[index] = libtorrentSelectedFilePriority;
      }
    }
    await backend.setFilePriorities(torrentId, priorities);
  }

  @override
  Stream<BtTaskEvent> watchEvents(BtTaskId taskId) async* {
    final LibtorrentEngineBackend backend = await _requireBackend();
    var metadataEmitted = false;
    var failureEmitted = false;
    await for (final LibtorrentTorrentSnapshot snapshot
        in backend.watchTorrent(_torrentId(taskId))) {
      if (!metadataEmitted &&
          snapshot.hasMetadata &&
          backend.supportsCompleteMetadata) {
        metadataEmitted = true;
        yield BtMetadataReceived(
          taskId: taskId,
          metadata: await ensureMetadata(taskId),
        );
      }
      if (!failureEmitted && snapshot.state == LibtorrentTaskState.error) {
        failureEmitted = true;
        yield BtTaskFailed(
          taskId: taskId,
          message: snapshot.message ?? 'libtorrent task failed.',
        );
      }
    }
  }

  @override
  Stream<BtTaskStatus> watchStatus(BtTaskId taskId) async* {
    final LibtorrentEngineBackend backend = await _requireBackend();
    await for (final LibtorrentTorrentSnapshot snapshot
        in backend.watchTorrent(_torrentId(taskId))) {
      yield _status(taskId, snapshot);
    }
  }

  Future<LibtorrentEngineBackend> _requireBackend() async {
    return _backend ??= await _backendFactory();
  }

  int _torrentId(BtTaskId taskId) {
    return int.parse(taskId.value);
  }
}

BtCapabilityMatrix libtorrentDownloadEngineCapabilities({
  required bool metadataFetchingSupported,
}) {
  return BtCapabilityMatrix(
    capabilities: <BtStreamingCapability, BtCapabilityStatus>{
      BtStreamingCapability.taskManagement:
          const BtCapabilityStatus.supported(),
      BtStreamingCapability.metadataFetching: metadataFetchingSupported
          ? const BtCapabilityStatus.supported()
          : const BtCapabilityStatus.unsupported(
              'Complete libtorrent metadata projection is not configured.'),
      BtStreamingCapability.virtualMediaStream:
          const BtCapabilityStatus.unsupported(
              'Virtual byte serving belongs to Step 53.'),
      BtStreamingCapability.piecePriorityScheduling:
          const BtCapabilityStatus.unsupported(
              'Piece priority application belongs to Step 54.'),
      BtStreamingCapability.timelineOverlay:
          const BtCapabilityStatus.unsupported(
              'Timeline overlay is not owned by the BT engine adapter.'),
      BtStreamingCapability.longBackgroundDownload: const BtCapabilityStatus
          .unsupported(
          'Long background download is platform-specific and not guaranteed.'),
    },
  );
}

LibtorrentTaskState _taskState(lt.TorrentState state) {
  return switch (state) {
    lt.TorrentState.error => LibtorrentTaskState.error,
    lt.TorrentState.unknown => LibtorrentTaskState.unknown,
    lt.TorrentState.checkingFiles => LibtorrentTaskState.checkingFiles,
    lt.TorrentState.downloadingMetadata =>
      LibtorrentTaskState.downloadingMetadata,
    lt.TorrentState.downloading => LibtorrentTaskState.downloading,
    lt.TorrentState.finished => LibtorrentTaskState.finished,
    lt.TorrentState.seeding => LibtorrentTaskState.seeding,
    lt.TorrentState.allocating => LibtorrentTaskState.allocating,
    lt.TorrentState.checkingResume => LibtorrentTaskState.checkingResume,
  };
}

BtTaskLifecycleState _lifecycleState(LibtorrentTorrentSnapshot snapshot) {
  if (snapshot.state == LibtorrentTaskState.error) {
    return BtTaskLifecycleState.failed;
  }
  if (snapshot.isPaused) return BtTaskLifecycleState.paused;
  if (snapshot.isFinished ||
      snapshot.state == LibtorrentTaskState.finished ||
      snapshot.state == LibtorrentTaskState.seeding) {
    return BtTaskLifecycleState.completed;
  }
  return switch (snapshot.state) {
    LibtorrentTaskState.downloadingMetadata =>
      BtTaskLifecycleState.fetchingMetadata,
    LibtorrentTaskState.downloading => BtTaskLifecycleState.downloading,
    LibtorrentTaskState.checkingFiles ||
    LibtorrentTaskState.allocating ||
    LibtorrentTaskState.checkingResume =>
      BtTaskLifecycleState.fetchingMetadata,
    LibtorrentTaskState.unknown => snapshot.hasMetadata
        ? BtTaskLifecycleState.ready
        : BtTaskLifecycleState.queued,
    LibtorrentTaskState.error => BtTaskLifecycleState.failed,
    LibtorrentTaskState.finished ||
    LibtorrentTaskState.seeding =>
      BtTaskLifecycleState.completed,
  };
}

BtTaskStatus _status(BtTaskId taskId, LibtorrentTorrentSnapshot snapshot) {
  return BtTaskStatus(
    taskId: taskId,
    state: _lifecycleState(snapshot),
    progress: snapshot.progress,
    downloadRateBytesPerSecond: snapshot.downloadRateBytesPerSecond,
    uploadRateBytesPerSecond: snapshot.uploadRateBytesPerSecond,
    connectedPeers: snapshot.connectedPeers,
    message: snapshot.message,
  );
}

List<BtTaskFile> _files(List<LibtorrentFileSnapshot> files) {
  final List<LibtorrentFileSnapshot> ordered = <LibtorrentFileSnapshot>[
    ...files,
  ]..sort((LibtorrentFileSnapshot left, LibtorrentFileSnapshot right) =>
      left.index.compareTo(right.index));
  final List<BtTaskFile> result = <BtTaskFile>[];
  var offsetBytes = 0;
  for (final LibtorrentFileSnapshot file in ordered) {
    result.add(
      BtTaskFile(
        index: BtFileIndex(file.index),
        path: file.path,
        lengthBytes: file.lengthBytes,
        offsetBytes: offsetBytes,
        selectionState: BtFileSelectionState.selected,
      ),
    );
    offsetBytes += file.lengthBytes;
  }
  return result;
}

int _priorityCount(List<LibtorrentFileSnapshot> files) {
  var maxIndex = -1;
  for (final LibtorrentFileSnapshot file in files) {
    if (file.index > maxIndex) maxIndex = file.index;
  }
  return maxIndex + 1;
}

int _totalSizeBytes(
  LibtorrentTorrentSnapshot torrent,
  List<LibtorrentFileSnapshot> files,
) {
  if (torrent.totalSizeBytes > 0) return torrent.totalSizeBytes;
  var totalSizeBytes = 0;
  for (final LibtorrentFileSnapshot file in files) {
    totalSizeBytes += file.lengthBytes;
  }
  return totalSizeBytes;
}

String? _magnetInfoHash(String? sourceUri) {
  if (sourceUri == null) return null;
  final Uri? uri = Uri.tryParse(sourceUri);
  final Iterable<String> exactTopics =
      uri?.queryParametersAll['xt'] ?? const <String>[];
  for (final String topic in exactTopics) {
    if (topic.toLowerCase().startsWith(_magnetExactTopicPrefix)) {
      return topic.substring(_magnetExactTopicPrefix.length);
    }
  }
  return null;
}
