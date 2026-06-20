import 'dart:async';
import 'dart:io';

import '../lib/elaina.dart';

const String _smokeDatabaseName = 'library-smoke.sqlite';
const String _smokeFirstFileName = 'Library Smoke 01.mkv';
const String _smokeSecondFileName = 'Library Smoke 02.mkv';
const String _smokeSubjectId = 'library-smoke-subject';
const String _smokeSubjectTitle = 'Library Smoke Subject';
const String _smokeScanId = 'library-smoke-scan';
const Duration _smokePosition = Duration(minutes: 6);
const Duration _smokeDuration = Duration(minutes: 24);

Future<void> main() async {
  final LibrarySmokeGateResult result = await runLibrarySmokeGate();
  stdout.writeln(
    'Library smoke gate passed: '
    '${result.importedItemCount} imports, '
    '${result.detailEpisodeCount} detail episodes, '
    'continue ${result.continueWatchingPosition.inMinutes}m.',
  );
}

final class LibrarySmokeGateResult {
  const LibrarySmokeGateResult({
    required this.scannedCandidateCount,
    required this.importedItemCount,
    required this.detailEpisodeCount,
    required this.handoffUri,
    required this.continueWatchingPosition,
    required this.continueWatchingDuration,
    required this.historyEventCount,
    required this.bindingEventCount,
    required this.replayedContinueWatching,
  });

  final int scannedCandidateCount;
  final int importedItemCount;
  final int detailEpisodeCount;
  final Uri handoffUri;
  final Duration continueWatchingPosition;
  final Duration continueWatchingDuration;
  final int historyEventCount;
  final int bindingEventCount;
  final bool replayedContinueWatching;
}

Future<LibrarySmokeGateResult> runLibrarySmokeGate() async {
  final Directory root = await Directory.systemTemp.createTemp(
    'elaina-library-smoke-',
  );
  final String databasePath = _join(root.path, _smokeDatabaseName);
  final DateTime now = _smokeNow();
  final StreamCacheInvalidationBus invalidationBus =
      StreamCacheInvalidationBus();
  final List<CacheInvalidationEvent> events = <CacheInvalidationEvent>[];
  final StreamSubscription<CacheInvalidationEvent> subscription =
      invalidationBus.events.listen(events.add);

  try {
    await _writeSmokeFiles(root);
    final _InitialSmokeState initial = await _runInitialFlow(
      databasePath: databasePath,
      root: root,
      invalidationBus: invalidationBus,
      now: now,
    );
    final _ReplaySmokeState replay = await _runReplayFlow(
      databasePath: databasePath,
      now: now,
    );

    _expect(
      replay.continueWatchingPosition == _smokePosition,
      'Library smoke gate must replay continue-watching position.',
    );
    _expect(
      replay.detailContinueWatchingPosition == _smokePosition,
      'Library smoke gate must replay detail continue-watching position.',
    );

    return LibrarySmokeGateResult(
      scannedCandidateCount: initial.scannedCandidateCount,
      importedItemCount: initial.importedItemCount,
      detailEpisodeCount: initial.detailEpisodeCount,
      handoffUri: initial.handoffUri,
      continueWatchingPosition: replay.continueWatchingPosition,
      continueWatchingDuration: replay.continueWatchingDuration,
      historyEventCount: events.whereType<HistoryRecorded>().length,
      bindingEventCount: events.whereType<BindingChanged>().length,
      replayedContinueWatching: true,
    );
  } finally {
    await subscription.cancel();
    await invalidationBus.close();
    if (root.existsSync()) {
      await root.delete(recursive: true);
    }
  }
}

Future<_InitialSmokeState> _runInitialFlow({
  required String databasePath,
  required Directory root,
  required StreamCacheInvalidationBus invalidationBus,
  required DateTime now,
}) async {
  final SqliteStorageFoundation storage =
      SqliteStorageFoundation.open(databasePath);
  final DeterministicProviderGateway gateway =
      DeterministicProviderGateway(storage: storage);
  final BangumiProviderRuntime metadataProvider = _metadataProvider(gateway);
  await metadataProvider.initialize();
  final MediaLibraryBootstrap mediaLibrary = _mediaLibraryBootstrap(
    storage: storage,
    invalidationBus: invalidationBus,
    now: now,
  );
  final VideoDetailBootstrap detail = storageBackedVideoDetailBootstrap(
    storage: storage,
    metadataProvider: metadataProvider,
    invalidationBus: invalidationBus,
    now: () => now,
  );

  try {
    final MediaScanResult scan = (await mediaLibrary.scan(
      MediaScanScope(
        roots: <Uri>[root.uri],
        extensions: const <String>{'mkv'},
      ),
    ))
        .value!;
    _expect(
      scan.candidates.length == 2,
      'Library smoke gate must scan both local media files.',
    );

    final MediaImportResult import =
        (await mediaLibrary.importCandidates(scan.candidates)).value!;
    final List<MediaLibraryItem> items = _sortItems(import.imported);
    _expect(
      items.length == 2,
      'Library smoke gate must import both scanned files.',
    );

    for (var index = 0; index < items.length; index += 1) {
      await mediaLibrary.runtime.saveUserBinding(
        _bindingFor(items[index], index: index, now: now),
      );
    }

    final MediaLibraryItem continueItem = items.last;
    final PlaybackHistoryRecorder recorder = PlaybackHistoryRecorder(
      catalogRepository:
          StorageMediaLibraryCatalogRepository(storage.mediaLibrary),
      historyStore: StoragePlaybackHistoryStore(storage.playbackHistory),
      invalidationBus: invalidationBus,
    );
    final PlaybackHistoryRecordingResult recording = await recorder.record(
      PlaybackStateSnapshot(
        status: PlaybackLifecycleStatus.paused,
        sourceUri: continueItem.identity.uri,
        timeline: PlaybackTimelineState(
          position: _smokePosition,
          duration: _smokeDuration,
          observedAt: now,
        ),
      ),
    );
    _expect(
      recording.isRecorded,
      'Library smoke gate must record playback history from playback state.',
    );

    final VideoDetailViewData data =
        await detail.load(const VideoDetailId(_smokeSubjectId));
    _expect(
      data.episodes.length == 2,
      'Library smoke gate must load storage-backed detail episodes.',
    );
    _expect(
      data.continueWatching?.mediaId.value == continueItem.identity.id.value,
      'Library smoke gate detail must surface latest continue-watching media.',
    );

    final VideoDetailActionResult continueResult =
        await detail.controller.continuePlayback(
      const VideoDetailId(_smokeSubjectId),
    );
    _expect(
      continueResult.isSuccess,
      'Library smoke gate must route detail continue-playback through handoff.',
    );

    final MediaLibraryActionResult<PlaybackSourceHandoffResult> handoff =
        await mediaLibrary.runtime.playItem(continueItem.id);
    final PlaybackSource? source = handoff.value?.source;
    _expect(
      handoff.isSuccess && source is LocalFilePlaybackSource,
      'Library smoke gate must prepare a local file playback source.',
    );

    return _InitialSmokeState(
      scannedCandidateCount: scan.candidates.length,
      importedItemCount: items.length,
      detailEpisodeCount: data.episodes.length,
      handoffUri: (source! as LocalFilePlaybackSource).uri,
    );
  } finally {
    detail.dispose();
    mediaLibrary.dispose();
    metadataProvider.dispose();
    gateway.close();
    storage.dispose();
  }
}

Future<_ReplaySmokeState> _runReplayFlow({
  required String databasePath,
  required DateTime now,
}) async {
  final SqliteStorageFoundation storage =
      SqliteStorageFoundation.open(databasePath);
  final StreamCacheInvalidationBus replayBus = StreamCacheInvalidationBus();
  final DeterministicProviderGateway gateway =
      DeterministicProviderGateway(storage: storage);
  final BangumiProviderRuntime metadataProvider = _metadataProvider(gateway);
  await metadataProvider.initialize();
  final MediaLibraryBootstrap mediaLibrary = _mediaLibraryBootstrap(
    storage: storage,
    invalidationBus: replayBus,
    now: now,
  );
  final VideoDetailBootstrap detail = storageBackedVideoDetailBootstrap(
    storage: storage,
    metadataProvider: metadataProvider,
    invalidationBus: replayBus,
    now: () => now,
  );

  try {
    final MediaLibraryRuntimeSnapshot snapshot =
        (await mediaLibrary.refresh()).value!;
    _expect(
      snapshot.catalogItems.length == 2,
      'Library smoke gate must replay catalog items after storage reopen.',
    );
    _expect(
      snapshot.continueWatching.length == 1,
      'Library smoke gate must replay continue-watching after storage reopen.',
    );

    final VideoDetailViewData data =
        await detail.load(const VideoDetailId(_smokeSubjectId));
    _expect(
      data.episodes.length == 2,
      'Library smoke gate must replay detail episodes after storage reopen.',
    );

    return _ReplaySmokeState(
      continueWatchingPosition: snapshot.continueWatching.single.position,
      continueWatchingDuration: snapshot.continueWatching.single.duration,
      detailContinueWatchingPosition:
          data.continueWatching?.position ?? Duration.zero,
    );
  } finally {
    detail.dispose();
    mediaLibrary.dispose();
    metadataProvider.dispose();
    gateway.close();
    await replayBus.close();
    storage.dispose();
  }
}

MediaLibraryBootstrap _mediaLibraryBootstrap({
  required SqliteStorageFoundation storage,
  required StreamCacheInvalidationBus invalidationBus,
  required DateTime now,
}) {
  return storageBackedMediaLibraryBootstrap(
    storage: storage,
    invalidationBus: invalidationBus,
    scanner: LocalFileMediaLibraryScanner(
      scanIdFactory: () => const MediaScanId(_smokeScanId),
      clock: () => now,
    ),
    now: () => now,
  );
}

BangumiProviderRuntime _metadataProvider(ProviderGateway gateway) {
  return BangumiProviderRuntime(
    gateway: gateway,
    subjects: const <BangumiSubject>[
      BangumiSubject(
        id: BangumiSubjectId(_smokeSubjectId),
        title: _smokeSubjectTitle,
        summary: 'Non-UI library smoke metadata.',
      ),
    ],
  );
}

ProviderBinding _bindingFor(
  MediaLibraryItem item, {
  required int index,
  required DateTime now,
}) {
  return ProviderBinding(
    id: ProviderBindingId('library-smoke-binding-$index'),
    localMediaId: item.identity.id,
    providerId: defaultVideoDetailMetadataProviderId,
    subjectId: const ProviderSubjectId(_smokeSubjectId),
    authority: ProviderBindingAuthority.userConfirmed,
    confidence: 1,
    createdAt: now.add(Duration(minutes: index)),
  );
}

Future<void> _writeSmokeFiles(Directory root) async {
  await File(_join(root.path, _smokeFirstFileName)).writeAsString('first');
  await File(_join(root.path, _smokeSecondFileName)).writeAsString('second');
}

List<MediaLibraryItem> _sortItems(List<MediaLibraryItem> items) {
  return <MediaLibraryItem>[...items]..sort(
      (MediaLibraryItem left, MediaLibraryItem right) =>
          left.identity.basename.compareTo(right.identity.basename),
    );
}

DateTime _smokeNow() => DateTime.utc(2026, 6, 17, 18);

String _join(String directory, String name) {
  return '$directory${Platform.pathSeparator}$name';
}

void _expect(bool condition, String message) {
  if (!condition) throw StateError(message);
}

final class _InitialSmokeState {
  const _InitialSmokeState({
    required this.scannedCandidateCount,
    required this.importedItemCount,
    required this.detailEpisodeCount,
    required this.handoffUri,
  });

  final int scannedCandidateCount;
  final int importedItemCount;
  final int detailEpisodeCount;
  final Uri handoffUri;
}

final class _ReplaySmokeState {
  const _ReplaySmokeState({
    required this.continueWatchingPosition,
    required this.continueWatchingDuration,
    required this.detailContinueWatchingPosition,
  });

  final Duration continueWatchingPosition;
  final Duration continueWatchingDuration;
  final Duration detailContinueWatchingPosition;
}
