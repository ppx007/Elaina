import 'dart:async';

import 'package:libtorrent_flutter/libtorrent_flutter.dart' as lt;

import '../foundation/cache_invalidation/cache_invalidation_bus.dart';
import '../foundation/storage/storage_contracts.dart';
import 'bt_task_core.dart';
import 'bt_task_core_runtime.dart';
import 'piece_priority_scheduler.dart';
import 'piece_priority_scheduler_runtime.dart';

typedef LibtorrentEngineBackendFactory = Future<LibtorrentEngineBackend>
    Function();

typedef LibtorrentMetadataResolver = LibtorrentResolvedMetadata? Function(
    LibtorrentMetadataResolveRequest request);

const String libtorrentDownloadEngineAdapterId = 'libtorrent-download-engine';
const String libtorrentDownloadEngineAdapterDisplayName =
    'libtorrent Download Engine';
const int libtorrentSkipFilePriority = 0;
const int libtorrentSelectedFilePriority = 1;

/// Lower bound for the preload budget derived from a piece-priority plan, so a
/// plan with only a couple of head/tail pieces still primes a usable buffer.
const int libtorrentMinPreloadBytes = 16 * 1024 * 1024; // 16 MiB

/// Cap on the RAM piece cache requested when applying a plan's playback window.
const int libtorrentMaxStreamCacheBytes = 256 * 1024 * 1024; // 256 MiB
const int libtorrentDefaultVirtualStreamCacheBytes =
    256 * 1024 * 1024; // 256 MiB
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

  /// Primes streaming for [fileIndex] within [torrentId] using the engine's
  /// own piece-window machinery.
  ///
  /// libtorrent_flutter does not expose per-piece priorities; instead it
  /// streams a file through a sliding window primed by a head/tail preload and
  /// a bounded RAM cache.  A piece-priority plan is therefore mapped onto these
  /// two levers ([preloadBytes], [cacheBytes]).
  Future<void> primeStreamWindow({
    required int torrentId,
    required int fileIndex,
    required int preloadBytes,
    required int cacheBytes,
  });

  Future<Uri> streamUriFor({
    required int torrentId,
    required int fileIndex,
    required int cacheBytes,
  });

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
  // Active stream id keyed by (torrentId, fileIndex) so repeated plan
  // applications reuse the same engine stream instead of leaking one per call.
  final Map<(int, int), int> _streamIdByFile = <(int, int), int>{};

  @override
  bool get supportsCompleteMetadata => true;

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
  Future<void> primeStreamWindow({
    required int torrentId,
    required int fileIndex,
    required int preloadBytes,
    required int cacheBytes,
  }) async {
    // Reuse an existing stream for this file if one is already active,
    // otherwise open one bounded by the requested cache budget.
    int? streamId = _streamIdByFile[(torrentId, fileIndex)];
    if (streamId == null) {
      final lt.StreamInfo info = _engine.startStream(
        torrentId,
        fileIndex: fileIndex,
        maxCacheBytes: cacheBytes,
      );
      streamId = info.id;
      _streamIdByFile[(torrentId, fileIndex)] = streamId;
    } else {
      _engine.setCacheSettings(streamId, capacity: cacheBytes);
    }
    _engine.preloadStream(streamId, preloadBytes: preloadBytes);
  }

  @override
  Future<Uri> streamUriFor({
    required int torrentId,
    required int fileIndex,
    required int cacheBytes,
  }) async {
    final lt.StreamInfo info = _engine.startStream(
      torrentId,
      fileIndex: fileIndex,
      maxCacheBytes: cacheBytes,
    );
    _streamIdByFile[(torrentId, fileIndex)] = info.id;
    return Uri.parse(info.url);
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
    bool backgroundDownloadSupported = false,
    bool virtualMediaStreamSupported = false,
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
          backgroundDownloadSupported: backgroundDownloadSupported,
          virtualMediaStreamSupported: virtualMediaStreamSupported,
        );

  static Future<LibtorrentDownloadEngineAdapter> initialize({
    String? defaultSavePath,
    Duration? pollInterval,
    LibtorrentMetadataResolver? metadataResolver,
    bool backgroundDownloadSupported = false,
    bool virtualMediaStreamSupported = false,
  }) async {
    final _LibtorrentFlutterEngineBackend backend =
        await _LibtorrentFlutterEngineBackend.initialize(
      defaultSavePath: defaultSavePath,
      pollInterval: pollInterval,
      metadataResolver: metadataResolver,
    );
    return LibtorrentDownloadEngineAdapter(
      backend: backend,
      backgroundDownloadSupported: backgroundDownloadSupported,
      virtualMediaStreamSupported: virtualMediaStreamSupported,
    );
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
    final List<LibtorrentFileSnapshot> files =
        await backend.filesFor(torrentId);
    return BtTaskMetadata(
      infoHash: infoHash == null || infoHash == '' ? null : InfoHash(infoHash),
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

  /// Applies a piece-priority [plan] to the engine.
  ///
  /// libtorrent_flutter has no per-piece API, so the plan's rules are mapped
  /// onto the engine's streaming window: the file is selected for download and
  /// the head/tail + playback-window pieces are translated into a preload
  /// budget and a bounded RAM cache via [LibtorrentEngineBackend.primeStreamWindow].
  Future<void> applyPiecePriorityPlan(PiecePriorityPlan plan) async {
    final LibtorrentEngineBackend backend = await _requireBackend();
    await selectFiles(plan.taskId, <BtFileIndex>[plan.fileIndex]);

    final BtTaskMetadata metadata = await ensureMetadata(plan.taskId);
    final int? pieceLengthBytes = metadata.pieceLengthBytes;
    if (pieceLengthBytes == null || pieceLengthBytes <= 0) {
      throw StateError(
        'libtorrent piece priority requires torrent piece length metadata.',
      );
    }
    final (int preloadBytes, int cacheBytes) =
        _streamWindowBudget(plan, pieceLengthBytes);
    await backend.primeStreamWindow(
      torrentId: _torrentId(plan.taskId),
      fileIndex: plan.fileIndex.value,
      preloadBytes: preloadBytes,
      cacheBytes: cacheBytes,
    );
  }

  Future<Uri> streamUriForTaskFile(
    BtTaskId taskId,
    BtFileIndex fileIndex, {
    int cacheBytes = libtorrentDefaultVirtualStreamCacheBytes,
  }) async {
    final LibtorrentEngineBackend backend = await _requireBackend();
    return backend.streamUriFor(
      torrentId: _torrentId(taskId),
      fileIndex: fileIndex.value,
      cacheBytes: cacheBytes,
    );
  }

  /// Derives `(preloadBytes, cacheBytes)` from a plan's rules.
  ///
  /// Head/tail/seek pieces drive the preload budget (fast start + seekability);
  /// playback-window pieces drive the RAM cache. Both are clamped to sane
  /// bounds so a sparse plan still primes a usable buffer and a huge one cannot
  /// request an unbounded cache.
  (int, int) _streamWindowBudget(PiecePriorityPlan plan, int pieceLengthBytes) {
    int preloadPieces = 0;
    int windowPieces = 0;
    for (final PiecePriorityRule rule in plan.rules) {
      switch (rule.reason) {
        case PiecePriorityRuleReason.firstPiece:
        case PiecePriorityRuleReason.tailPiece:
        case PiecePriorityRuleReason.seekTarget:
          preloadPieces += 1;
        case PiecePriorityRuleReason.playbackWindow:
        case PiecePriorityRuleReason.staleWindow:
          windowPieces += 1;
      }
    }
    final int preloadBytes =
        _max(preloadPieces * pieceLengthBytes, libtorrentMinPreloadBytes);
    final int cacheBytes = _min(
      _max((preloadPieces + windowPieces) * pieceLengthBytes,
          libtorrentMinPreloadBytes),
      libtorrentMaxStreamCacheBytes,
    );
    return (preloadBytes, cacheBytes);
  }

  @override
  Stream<BtTaskEvent> watchEvents(BtTaskId taskId) async* {
    final LibtorrentEngineBackend backend = await _requireBackend();
    bool metadataEmitted = false;
    bool failureEmitted = false;
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

final class LibtorrentPiecePriorityPlanApplier
    implements PiecePriorityPlanApplier {
  const LibtorrentPiecePriorityPlanApplier({required this.adapter});

  final LibtorrentDownloadEngineAdapter adapter;

  @override
  Future<PiecePriorityApplicationOutcome> apply(PiecePriorityPlan plan) async {
    try {
      await adapter.applyPiecePriorityPlan(plan);
      return const PiecePriorityApplicationOutcome.accepted();
    } on Object catch (error) {
      return PiecePriorityApplicationOutcome.rejected(
        failure: PiecePriorityApplicationFailure(
          kind: PiecePriorityApplicationFailureKind.adapterRejected,
          message: error.toString(),
        ),
      );
    }
  }
}

BtTaskRuntimeCompositionContract libtorrentBtTaskRuntimeComposition({
  required BtTaskStore store,
  CacheInvalidationBus? cacheInvalidationBus,
  DateTime Function()? clock,
  LibtorrentEngineBackend? backend,
  LibtorrentEngineBackendFactory? backendFactory,
  String? defaultSavePath,
  Duration? pollInterval,
  LibtorrentMetadataResolver? metadataResolver,
  bool metadataFetchingSupported = false,
  bool backgroundDownloadSupported = false,
  bool virtualMediaStreamSupported = false,
}) {
  final LibtorrentEngineBackendFactory? effectiveBackendFactory =
      backend == null
          ? backendFactory ??
              () => _LibtorrentFlutterEngineBackend.initialize(
                    defaultSavePath: defaultSavePath,
                    pollInterval: pollInterval,
                    metadataResolver: metadataResolver,
                  )
          : backendFactory;
  final LibtorrentDownloadEngineAdapter adapter =
      LibtorrentDownloadEngineAdapter(
    backend: backend,
    backendFactory: effectiveBackendFactory,
    metadataFetchingSupported:
        metadataResolver != null || metadataFetchingSupported,
    backgroundDownloadSupported: backgroundDownloadSupported,
    virtualMediaStreamSupported: virtualMediaStreamSupported,
  );
  return BtTaskRuntimeCompositionContract(
    adapter: adapter,
    store: store,
    cacheInvalidationBus: cacheInvalidationBus,
    clock: clock,
  );
}

PiecePrioritySchedulerRuntime libtorrentPiecePrioritySchedulerRuntime({
  required BtTaskStore btTaskStore,
  required VirtualMediaStreamStore streamStore,
  required PiecePrioritySchedulerStore schedulerStore,
  CacheInvalidationBus? cacheInvalidationBus,
  Iterable<PiecePriorityStrategyProfile> profiles =
      const <PiecePriorityStrategyProfile>[
    PiecePrioritySchedulerRuntime.balancedProfile,
  ],
  DateTime Function()? clock,
  LibtorrentDownloadEngineAdapter? adapter,
  LibtorrentEngineBackend? backend,
  LibtorrentEngineBackendFactory? backendFactory,
  bool metadataFetchingSupported = false,
  bool backgroundDownloadSupported = false,
  bool virtualMediaStreamSupported = false,
}) {
  final LibtorrentDownloadEngineAdapter effectiveAdapter = adapter ??
      LibtorrentDownloadEngineAdapter(
        backend: backend,
        backendFactory: backendFactory,
        metadataFetchingSupported: metadataFetchingSupported,
        backgroundDownloadSupported: backgroundDownloadSupported,
        virtualMediaStreamSupported: virtualMediaStreamSupported,
      );
  return PiecePrioritySchedulerRuntime(
    btTaskStore: btTaskStore,
    streamStore: streamStore,
    schedulerStore: schedulerStore,
    cacheInvalidationBus: cacheInvalidationBus,
    profiles: profiles,
    planApplier: LibtorrentPiecePriorityPlanApplier(
      adapter: effectiveAdapter,
    ),
    clock: clock,
  );
}

BtCapabilityMatrix libtorrentDownloadEngineCapabilities({
  required bool metadataFetchingSupported,
  required bool backgroundDownloadSupported,
  required bool virtualMediaStreamSupported,
}) {
  return BtCapabilityMatrix(
    capabilities: <BtStreamingCapability, BtCapabilityStatus>{
      BtStreamingCapability.taskManagement:
          const BtCapabilityStatus.supported(),
      BtStreamingCapability.metadataFetching: metadataFetchingSupported
          ? const BtCapabilityStatus.supported()
          : const BtCapabilityStatus.unsupported(
              'libtorrent metadata and file projection is not configured.'),
      BtStreamingCapability.virtualMediaStream: virtualMediaStreamSupported
          ? const BtCapabilityStatus.supported()
          : const BtCapabilityStatus.unsupported(
              'Virtual stream runtime is not composed with this adapter.'),
      BtStreamingCapability.piecePriorityScheduling:
          const BtCapabilityStatus.supported(),
      BtStreamingCapability.timelineOverlay:
          const BtCapabilityStatus.unsupported(
              'Timeline overlay is not owned by the BT engine adapter.'),
      BtStreamingCapability.longBackgroundDownload:
          backgroundDownloadSupported
              ? const BtCapabilityStatus.supported()
              : const BtCapabilityStatus.unsupported(
                  'Application-lifetime background download is not composed.'),
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
  int offsetBytes = 0;
  for (final LibtorrentFileSnapshot file in ordered) {
    result.add(
      BtTaskFile(
        index: BtFileIndex(file.index),
        path: file.path,
        lengthBytes: file.lengthBytes,
        offsetBytes: offsetBytes,
        selectionState: BtFileSelectionState.selected,
        isStreamable: file.isStreamable,
      ),
    );
    offsetBytes += file.lengthBytes;
  }
  return result;
}

int _priorityCount(List<LibtorrentFileSnapshot> files) {
  int maxIndex = -1;
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
  int totalSizeBytes = 0;
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

int _max(int a, int b) => a > b ? a : b;

int _min(int a, int b) => a < b ? a : b;
