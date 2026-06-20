import 'dart:async';
import 'dart:io';

import 'package:elaina/elaina.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('records catalog-backed playback snapshot and publishes history event',
      () async {
    final DateTime observedAt = DateTime.utc(2026, 6, 17, 15);
    final MediaLibraryItem item = _item('media-1', 'episode-1.mkv');
    final DeterministicMediaLibraryCatalogRepository catalog =
        DeterministicMediaLibraryCatalogRepository(
      seedItems: <MediaLibraryItem>[item],
    );
    final DeterministicPlaybackHistoryStore historyStore =
        DeterministicPlaybackHistoryStore();
    final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
    final List<CacheInvalidationEvent> events = <CacheInvalidationEvent>[];
    final StreamSubscription<CacheInvalidationEvent> subscription =
        bus.events.listen(events.add);
    addTearDown(subscription.cancel);
    addTearDown(bus.close);
    final PlaybackHistoryRecorder recorder = PlaybackHistoryRecorder(
      catalogRepository: catalog,
      historyStore: historyStore,
      invalidationBus: bus,
      now: () => DateTime.utc(2026, 6, 17, 16),
    );

    final PlaybackHistoryRecordingResult result = await recorder.record(
      PlaybackStateSnapshot(
        status: PlaybackLifecycleStatus.playing,
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
    expect(result.isRecorded, isTrue);
    expect(result.entry?.mediaId.value, item.identity.id.value);
    expect(result.entry?.updatedAt, observedAt);
    expect(latest?.position, const Duration(minutes: 4));
    expect(latest?.duration, const Duration(minutes: 24));
    expect(
      events.whereType<HistoryRecorded>().single.localMediaId,
      item.identity.id.value,
    );
  });

  test('skips incomplete and non-recordable snapshots without writes',
      () async {
    final MediaLibraryItem item = _item('media-1', 'episode-1.mkv');
    final DeterministicMediaLibraryCatalogRepository catalog =
        DeterministicMediaLibraryCatalogRepository(
      seedItems: <MediaLibraryItem>[item],
    );
    final _RecordingHistoryStore historyStore = _RecordingHistoryStore();
    final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
    final List<CacheInvalidationEvent> events = <CacheInvalidationEvent>[];
    final StreamSubscription<CacheInvalidationEvent> subscription =
        bus.events.listen(events.add);
    addTearDown(subscription.cancel);
    addTearDown(bus.close);
    final PlaybackHistoryRecorder recorder = PlaybackHistoryRecorder(
      catalogRepository: catalog,
      historyStore: historyStore,
      invalidationBus: bus,
    );

    final List<PlaybackHistoryRecordingResult> results =
        <PlaybackHistoryRecordingResult>[
      await recorder.record(
        const PlaybackStateSnapshot(status: PlaybackLifecycleStatus.idle),
      ),
      await recorder.record(
        const PlaybackStateSnapshot(
          status: PlaybackLifecycleStatus.playing,
          timeline: PlaybackTimelineState(
            position: Duration(minutes: 1),
            duration: Duration(minutes: 24),
          ),
        ),
      ),
      await recorder.record(
        PlaybackStateSnapshot(
          status: PlaybackLifecycleStatus.playing,
          sourceUri: item.identity.uri,
          timeline: const PlaybackTimelineState(
            position: Duration(minutes: 1),
          ),
        ),
      ),
      await recorder.record(
        PlaybackStateSnapshot(
          status: PlaybackLifecycleStatus.playing,
          sourceUri: Uri.parse('file:///D:/media/missing.mkv'),
          timeline: const PlaybackTimelineState(
            position: Duration(minutes: 1),
            duration: Duration(minutes: 24),
          ),
        ),
      ),
    ];

    expect(
      results.map(
        (PlaybackHistoryRecordingResult result) => result.failure?.kind,
      ),
      <PlaybackHistoryRecordingFailureKind>[
        PlaybackHistoryRecordingFailureKind.nonRecordableStatus,
        PlaybackHistoryRecordingFailureKind.missingSourceUri,
        PlaybackHistoryRecordingFailureKind.missingDuration,
        PlaybackHistoryRecordingFailureKind.catalogItemNotFound,
      ],
    );
    expect(
      results.every(
        (PlaybackHistoryRecordingResult result) =>
            result.kind == PlaybackHistoryRecordingResultKind.skipped,
      ),
      isTrue,
    );
    expect(historyStore.entries, isEmpty);
    expect(events.whereType<HistoryRecorded>(), isEmpty);
  });

  test('observer attaches to playback observable and stops after dispose',
      () async {
    final MediaLibraryItem item = _item('media-1', 'episode-1.mkv');
    final _RecordingHistoryStore historyStore = _RecordingHistoryStore();
    final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
    addTearDown(bus.close);
    final PlaybackHistoryRecorder recorder = PlaybackHistoryRecorder(
      catalogRepository: DeterministicMediaLibraryCatalogRepository(
        seedItems: <MediaLibraryItem>[item],
      ),
      historyStore: historyStore,
      invalidationBus: bus,
    );
    final MockPlaybackController controller = MockPlaybackController(
      matrix: PlaybackCapabilityMatrix(
        capabilities: <PlaybackCapability, CapabilityStatus>{
          PlaybackCapability.localFilePlayback: CapabilityStatus.supported(),
          PlaybackCapability.playPause: CapabilityStatus.supported(),
          PlaybackCapability.seek: CapabilityStatus.supported(),
        },
      ),
      initialState: PlaybackStateSnapshot(
        status: PlaybackLifecycleStatus.idle,
        timeline: PlaybackTimelineState(
          position: Duration.zero,
          duration: const Duration(minutes: 24),
          observedAt: DateTime.utc(2026, 6, 17, 15),
        ),
      ),
    );
    final PlaybackHistoryRecordingObserver observer =
        PlaybackHistoryRecordingObserver(
      observable: controller,
      recorder: recorder,
    );

    await controller.open(LocalFilePlaybackSource(uri: item.identity.uri));
    final PlaybackHistoryRecordingResult first = await observer.lastRecording!;
    await controller.play();
    final PlaybackHistoryRecordingResult second = await observer.lastRecording!;
    observer.dispose();
    await controller.seek(const Duration(minutes: 8));

    expect(first.isRecorded, isTrue);
    expect(second.isRecorded, isTrue);
    expect(historyStore.entries, hasLength(2));
    expect(historyStore.entries.last.mediaId.value, item.identity.id.value);
    expect(historyStore.entries.last.position, Duration.zero);
  });

  test('sqlite-backed recorder persists continue watching after reopen',
      () async {
    final Directory root = await Directory.systemTemp.createTemp(
      'elaina-playback-history-',
    );
    addTearDown(() async {
      if (root.existsSync()) await root.delete(recursive: true);
    });
    final String databasePath = _join(root.path, 'history.sqlite');
    final MediaLibraryItem item = _item('media-1', 'episode-1.mkv');
    final DateTime observedAt = DateTime.utc(2026, 6, 17, 17);
    final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
    final List<CacheInvalidationEvent> events = <CacheInvalidationEvent>[];
    final StreamSubscription<CacheInvalidationEvent> subscription =
        bus.events.listen(events.add);
    addTearDown(subscription.cancel);
    addTearDown(bus.close);

    final SqliteStorageFoundation firstStorage =
        SqliteStorageFoundation.open(databasePath);
    final StorageMediaLibraryCatalogRepository firstCatalog =
        StorageMediaLibraryCatalogRepository(firstStorage.mediaLibrary);
    await firstCatalog.store(item);
    final PlaybackHistoryRecorder recorder = PlaybackHistoryRecorder(
      catalogRepository: firstCatalog,
      historyStore: StoragePlaybackHistoryStore(firstStorage.playbackHistory),
      invalidationBus: bus,
    );
    await recorder.record(
      PlaybackStateSnapshot(
        status: PlaybackLifecycleStatus.paused,
        sourceUri: item.identity.uri,
        timeline: PlaybackTimelineState(
          position: const Duration(minutes: 7),
          duration: const Duration(minutes: 24),
          observedAt: observedAt,
        ),
      ),
    );
    firstStorage.dispose();

    final SqliteStorageFoundation secondStorage =
        SqliteStorageFoundation.open(databasePath);
    addTearDown(secondStorage.dispose);
    final StoragePlaybackHistoryStore secondHistory =
        StoragePlaybackHistoryStore(secondStorage.playbackHistory);
    final List<ContinueWatchingState> continueWatching =
        await secondHistory.continueWatching();

    expect(continueWatching.single.mediaId.value, item.identity.id.value);
    expect(continueWatching.single.position, const Duration(minutes: 7));
    expect(continueWatching.single.duration, const Duration(minutes: 24));
    expect(continueWatching.single.updatedAt, observedAt);
    expect(events.whereType<HistoryRecorded>(), hasLength(1));
  });
}

MediaLibraryItem _item(String mediaId, String basename) {
  final Uri uri = Uri.parse('file:///D:/media/$basename');
  return MediaLibraryItem(
    id: MediaLibraryItemId('item-$mediaId'),
    identity: LocalMediaIdentity(
      id: LocalMediaId(mediaId),
      uri: uri,
      basename: basename,
    ),
    addedAt: DateTime.utc(2026, 6, 17),
    duration: const Duration(minutes: 24),
  );
}

String _join(String directory, String name) {
  return '$directory${Platform.pathSeparator}$name';
}

final class _RecordingHistoryStore implements PlaybackHistoryStore {
  final List<PlaybackHistoryEntry> entries = <PlaybackHistoryEntry>[];

  @override
  Future<List<ContinueWatchingState>> continueWatching({int limit = 20}) async {
    final List<PlaybackHistoryEntry> sorted = <PlaybackHistoryEntry>[...entries]
      ..sort(
        (PlaybackHistoryEntry left, PlaybackHistoryEntry right) =>
            right.updatedAt.compareTo(left.updatedAt),
      );
    return <ContinueWatchingState>[
      for (final PlaybackHistoryEntry entry in sorted.take(limit))
        ContinueWatchingState(
          mediaId: entry.mediaId,
          position: entry.position,
          duration: entry.duration,
          updatedAt: entry.updatedAt,
        ),
    ];
  }

  @override
  Future<PlaybackHistoryEntry?> latestFor(LocalMediaId mediaId) async {
    PlaybackHistoryEntry? latest;
    for (final PlaybackHistoryEntry entry in entries) {
      if (entry.mediaId.value != mediaId.value) continue;
      if (latest == null || entry.updatedAt.isAfter(latest.updatedAt)) {
        latest = entry;
      }
    }
    return latest;
  }

  @override
  Future<void> record(PlaybackHistoryEntry entry) async {
    entries.add(entry);
  }
}
