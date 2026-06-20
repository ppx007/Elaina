import 'dart:io';

import '../lib/elaina.dart';
import 'video_detail_runtime_check.dart';

Future<void> main() async {
  await verifyMediaLibraryRuntimeContract();
}

Future<void> verifyMediaLibraryRuntimeContract() async {
  await _verifyStorageBackedMediaLibraryRuntime();
  await _verifyPlaybackHistoryIntegration();

  final DateTime now = DateTime.utc(2026, 6, 10, 12);
  final MediaScanCandidate first = _candidate('check-media-1', 'check-1.mkv');
  final MediaScanCandidate second = _candidate('check-media-2', 'check-2.mkv');
  const MediaScanId scanId = MediaScanId('media-library-runtime-check');
  final DeterministicMediaLibraryCatalogRepository repository =
      DeterministicMediaLibraryCatalogRepository();
  final DeterministicPlaybackHistoryStore historyStore =
      DeterministicPlaybackHistoryStore();
  await historyStore.record(PlaybackHistoryEntry(
    id: const PlaybackHistoryEntryId('check-history'),
    mediaId: second.identity.id,
    position: const Duration(minutes: 6),
    duration: const Duration(minutes: 24),
    updatedAt: now,
  ));
  final DeterministicProviderBindingStore bindingStore =
      DeterministicProviderBindingStore();
  await bindingStore.saveUserConfirmed(ProviderBinding(
    id: const ProviderBindingId('check-binding'),
    localMediaId: first.identity.id,
    providerId: 'bangumi',
    subjectId: const ProviderSubjectId('check-subject'),
    authority: ProviderBindingAuthority.userConfirmed,
    confidence: 1,
    createdAt: now,
  ));
  final StreamCacheInvalidationBus invalidationBus =
      StreamCacheInvalidationBus();
  final List<CacheInvalidationEvent> events = <CacheInvalidationEvent>[];
  final subscription = invalidationBus.events.listen(events.add);
  final MediaLibraryBootstrap bootstrap = MediaLibraryBootstrap(
    scanner: DeterministicMediaLibraryScanner(
        scanId: scanId, candidates: <MediaScanCandidate>[first, second]),
    catalogRepository: repository,
    importer: DeterministicMediaBatchImportContract(
        repository: repository, clock: () => now),
    historyStore: historyStore,
    bindingStore: bindingStore,
    playbackSourceHandoff: const LocalPlaybackSourceHandoff(),
    invalidationBus: invalidationBus,
    now: () => now,
  );

  final MediaLibraryActionResult<MediaScanResult> scan =
      await bootstrap.scan(_scope());
  _expect(scan.isSuccess && scan.value?.candidates.length == 2,
      'Media library runtime must scan deterministic candidates.');
  final MediaLibraryActionResult<MediaImportResult> imported =
      await bootstrap.importCandidates(scan.value!.candidates);
  _expect(imported.value?.importedCount == 2,
      'Media library runtime must import scanned candidates.');
  final MediaLibraryRuntimeSnapshot snapshot =
      (await bootstrap.refresh()).value!;
  _expect(snapshot.catalogItems.length == 2,
      'Media library runtime must project imported catalog items.');
  _expect(
      snapshot.continueWatching.single.mediaId.value ==
          second.identity.id.value,
      'Media library runtime must expose continue-watching state.');
  _expect(
      snapshot.catalogItems.first.binding?.authority ==
          ProviderBindingAuthority.userConfirmed,
      'Media library runtime must expose strongest provider binding.');
  final MediaLibraryActionResult<PlaybackSourceHandoffResult> play =
      await bootstrap.runtime.playItem(snapshot.catalogItems.first.item.id);
  _expect(play.isSuccess,
      'Media library runtime must route playback through handoff.');
  _expect(events.whereType<MediaLibraryItemChanged>().length == 2,
      'Media library runtime must publish imported item invalidation events.');

  bootstrap.dispose();
  await subscription.cancel();
  await invalidationBus.close();
  await verifyVideoDetailRuntimeContract();
}

Future<void> _verifyPlaybackHistoryIntegration() async {
  final DateTime observedAt = DateTime.utc(2026, 6, 17, 15);
  final MediaLibraryItem item = MediaLibraryItem(
    id: const MediaLibraryItemId('check-history-item'),
    identity: LocalMediaIdentity(
      id: const LocalMediaId('check-history-media'),
      uri: Uri.parse('file:///D:/media/check-history.mkv'),
      basename: 'check-history.mkv',
    ),
    addedAt: observedAt,
    duration: const Duration(minutes: 24),
  );
  final DeterministicPlaybackHistoryStore historyStore =
      DeterministicPlaybackHistoryStore();
  final StreamCacheInvalidationBus invalidationBus =
      StreamCacheInvalidationBus();
  final List<CacheInvalidationEvent> events = <CacheInvalidationEvent>[];
  final subscription = invalidationBus.events.listen(events.add);
  try {
    final PlaybackHistoryRecorder recorder = PlaybackHistoryRecorder(
      catalogRepository: DeterministicMediaLibraryCatalogRepository(
        seedItems: <MediaLibraryItem>[item],
      ),
      historyStore: historyStore,
      invalidationBus: invalidationBus,
    );
    final PlaybackHistoryRecordingResult result = await recorder.record(
      PlaybackStateSnapshot(
        status: PlaybackLifecycleStatus.paused,
        sourceUri: item.identity.uri,
        timeline: PlaybackTimelineState(
          position: const Duration(minutes: 4),
          duration: const Duration(minutes: 24),
          observedAt: observedAt,
        ),
      ),
    );
    final PlaybackHistoryEntry? latest =
        await historyStore.latestFor(item.identity.id);
    _expect(
      result.isRecorded,
      'Playback history recorder must record catalog-backed snapshots.',
    );
    _expect(
      latest?.position == const Duration(minutes: 4),
      'Playback history recorder must persist snapshot position.',
    );
    _expect(
      events.whereType<HistoryRecorded>().length == 1,
      'Playback history recorder must publish HistoryRecorded.',
    );

    final PlaybackHistoryRecordingResult skipped = await recorder.record(
      const PlaybackStateSnapshot(status: PlaybackLifecycleStatus.idle),
    );
    _expect(
      skipped.kind == PlaybackHistoryRecordingResultKind.skipped &&
          skipped.failure?.kind ==
              PlaybackHistoryRecordingFailureKind.nonRecordableStatus,
      'Playback history recorder must skip non-recordable snapshots.',
    );
  } finally {
    await subscription.cancel();
    await invalidationBus.close();
  }
}

Future<void> _verifyStorageBackedMediaLibraryRuntime() async {
  final Directory root = await Directory.systemTemp.createTemp(
    'elaina-media-library-check-',
  );
  final DateTime now = DateTime.utc(2026, 6, 17, 14);
  final StreamCacheInvalidationBus invalidationBus =
      StreamCacheInvalidationBus();
  final List<CacheInvalidationEvent> events = <CacheInvalidationEvent>[];
  final subscription = invalidationBus.events.listen(events.add);
  final SqliteStorageFoundation storage = SqliteStorageFoundation.inMemory();
  try {
    await File(_join(root.path, 'check-real-1.mkv')).writeAsString('video');
    final MediaLibraryBootstrap bootstrap = storageBackedMediaLibraryBootstrap(
      storage: storage,
      invalidationBus: invalidationBus,
      scanner: LocalFileMediaLibraryScanner(
        scanIdFactory: () => const MediaScanId('real-media-library-check'),
        clock: () => now,
      ),
      now: () => now,
    );

    final MediaScanResult scan = (await bootstrap.scan(
      MediaScanScope(
        roots: <Uri>[root.uri],
        extensions: const <String>{'mkv'},
      ),
    ))
        .value!;
    _expect(
      scan.candidates.length == 1,
      'Concrete media library runtime must scan local files.',
    );
    final MediaImportResult imported =
        (await bootstrap.importCandidates(scan.candidates)).value!;
    _expect(
      imported.importedCount == 1,
      'Concrete media library runtime must import scanned local files.',
    );
    final MediaLibraryItem item = imported.imported.single;
    final PlaybackHistoryRecorder recorder = PlaybackHistoryRecorder(
      catalogRepository:
          StorageMediaLibraryCatalogRepository(storage.mediaLibrary),
      historyStore: StoragePlaybackHistoryStore(storage.playbackHistory),
      invalidationBus: invalidationBus,
    );
    final PlaybackHistoryRecordingResult historyResult = await recorder.record(
      PlaybackStateSnapshot(
        status: PlaybackLifecycleStatus.paused,
        sourceUri: item.identity.uri,
        timeline: PlaybackTimelineState(
          position: const Duration(minutes: 5),
          duration: const Duration(minutes: 24),
          observedAt: now,
        ),
      ),
    );
    _expect(
      historyResult.isRecorded,
      'Concrete media library runtime must record playback history from snapshots.',
    );
    await bootstrap.runtime.saveUserBinding(
      ProviderBinding(
        id: const ProviderBindingId('real-binding'),
        localMediaId: item.identity.id,
        providerId: 'bangumi',
        subjectId: const ProviderSubjectId('real-subject'),
        authority: ProviderBindingAuthority.userConfirmed,
        confidence: 1,
        createdAt: now,
      ),
    );
    final MediaLibraryRuntimeSnapshot snapshot =
        (await bootstrap.refresh()).value!;
    _expect(
      snapshot.catalogItems.single.binding?.authority ==
          ProviderBindingAuthority.userConfirmed,
      'Concrete media library runtime must project stored provider binding.',
    );
    _expect(
      snapshot.continueWatching.single.position == const Duration(minutes: 5),
      'Concrete media library runtime must project stored playback history.',
    );
    _expect(
      events.whereType<MediaLibraryItemChanged>().isNotEmpty,
      'Concrete media library runtime must publish import invalidations.',
    );
    _expect(
      events.whereType<HistoryRecorded>().isNotEmpty,
      'Concrete media library runtime must publish history invalidations.',
    );
    bootstrap.dispose();
  } finally {
    storage.dispose();
    await subscription.cancel();
    await invalidationBus.close();
    if (root.existsSync()) await root.delete(recursive: true);
  }
}

MediaScanScope _scope() {
  return MediaScanScope(
      roots: <Uri>[Uri.parse('file:///D:/media/')],
      extensions: const <String>{'mkv'});
}

MediaScanCandidate _candidate(String mediaId, String basename) {
  final Uri uri = Uri.parse('file:///D:/media/$basename');
  return MediaScanCandidate(
    identity: LocalMediaIdentity(
        id: LocalMediaId(mediaId), uri: uri, basename: basename),
    sizeBytes: 42,
    duration: const Duration(minutes: 24),
  );
}

String _join(String directory, String name) {
  return '$directory${Platform.pathSeparator}$name';
}

void _expect(bool condition, String message) {
  if (!condition) throw StateError(message);
}
