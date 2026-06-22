// Media library persistence contract tests protect stored item, binding, and
// history shape before concrete storage adapters implement it.
import 'package:elaina/elaina.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('catalog repository stores, updates, lists, and removes media items',
      () async {
    final DeterministicMediaLibraryCatalogRepository repository =
        DeterministicMediaLibraryCatalogRepository();
    final MediaLibraryItem item = _item(
        id: 'item-1',
        mediaId: 'media-1',
        uri: Uri.parse('file:///D:/media/episode-1.mkv'));

    final MediaLibraryItem stored = await repository.store(item);
    final MediaLibraryItem updated = MediaLibraryItem(
      id: stored.id,
      identity: stored.identity,
      addedAt: stored.addedAt,
      duration: const Duration(minutes: 24),
    );

    expect(await repository.findById(item.id), item);
    expect(await repository.findByLocalMediaId(item.identity.id), item);
    expect(await repository.findByUri(item.identity.uri), item);
    expect(await repository.count(), 1);

    await repository.update(updated);
    expect(
        (await repository.list()).single.duration, const Duration(minutes: 24));
    expect(await repository.remove(item.id), isTrue);
    expect(await repository.count(), 0);
  });

  test('batch import creates catalog items and skips URI duplicates', () async {
    final DeterministicMediaLibraryCatalogRepository repository =
        DeterministicMediaLibraryCatalogRepository();
    final MediaScanCandidate candidate = _candidate(
        mediaId: 'media-1', uri: Uri.parse('file:///D:/media/episode-1.mkv'));
    final DeterministicMediaBatchImportContract importer =
        DeterministicMediaBatchImportContract(repository: repository);

    final MediaImportResult firstImport =
        await importer.importBatch(<MediaScanCandidate>[candidate]);
    final MediaImportResult secondImport =
        await importer.importBatch(<MediaScanCandidate>[candidate]);

    expect(firstImport.importedCount, 1);
    expect(firstImport.skippedDuplicateCount, 0);
    expect(secondImport.importedCount, 0);
    expect(secondImport.skippedDuplicateCount, 1);
    expect(secondImport.skippedDuplicates.single.identity.uri,
        candidate.identity.uri);
  });

  test(
      'batch import reports conflict when URI and fingerprint match different items',
      () async {
    final MediaFileFingerprint fingerprint =
        const MediaFileFingerprint(algorithm: 'sha256', value: 'fingerprint-a');
    final DeterministicMediaLibraryCatalogRepository repository =
        DeterministicMediaLibraryCatalogRepository(
      seedItems: <MediaLibraryItem>[
        _item(
            id: 'item-uri',
            mediaId: 'media-uri',
            uri: Uri.parse('file:///D:/media/conflict.mkv')),
        _item(
          id: 'item-fingerprint',
          mediaId: 'media-fingerprint',
          uri: Uri.parse('file:///D:/media/other.mkv'),
          fingerprint: fingerprint,
        ),
      ],
    );
    final DeterministicMediaBatchImportContract importer =
        DeterministicMediaBatchImportContract(repository: repository);

    final MediaImportResult result =
        await importer.importBatch(<MediaScanCandidate>[
      _candidate(
          mediaId: 'media-candidate',
          uri: Uri.parse('file:///D:/media/conflict.mkv'),
          fingerprint: fingerprint),
    ]);

    expect(result.importedCount, 0);
    expect(result.failureCount, 1);
    expect(
        result.failures.single.kind, MediaImportFailureKind.duplicateConflict);
  });

  test(
      'playback history records latest entries and continue watching summaries',
      () async {
    final DeterministicPlaybackHistoryStore store =
        DeterministicPlaybackHistoryStore();
    final DateTime earlier = DateTime.utc(2026, 6, 4, 10, 0);
    final DateTime later = DateTime.utc(2026, 6, 4, 10, 5);

    await store.record(_historyEntry(
        id: 'history-1',
        mediaId: 'media-1',
        position: const Duration(minutes: 2),
        updatedAt: earlier));
    await store.record(_historyEntry(
        id: 'history-2',
        mediaId: 'media-1',
        position: const Duration(minutes: 8),
        updatedAt: later));

    final PlaybackHistoryEntry? latest =
        await store.latestFor(const LocalMediaId('media-1'));
    final List<ContinueWatchingState> summaries =
        await store.continueWatching(limit: 1);

    expect(latest?.id.value, 'history-2');
    expect(summaries.single.mediaId.value, 'media-1');
    expect(summaries.single.position, const Duration(minutes: 8));
    expect(summaries.single.progress, 0.5);
  });

  test('provider binding store preserves user-confirmed authority', () async {
    final DeterministicProviderBindingStore store =
        DeterministicProviderBindingStore();
    final ProviderBinding automatic = _binding(
      id: 'binding-auto',
      mediaId: 'media-1',
      authority: ProviderBindingAuthority.automatic,
      confidence: 1,
    );
    final ProviderBinding confirmed = _binding(
      id: 'binding-confirmed',
      mediaId: 'media-1',
      authority: ProviderBindingAuthority.userConfirmed,
      confidence: 0.2,
    );

    await store.saveUserConfirmed(confirmed);
    final ProviderBinding savedAutomatic =
        await store.saveAutomaticIfAllowed(automatic);
    final ProviderBinding? strongest =
        await store.bindingFor(const LocalMediaId('media-1'));

    expect(savedAutomatic, confirmed);
    expect(strongest, confirmed);
    expect((await store.bindingsFor(const LocalMediaId('media-1'))).length, 1);
  });

  test('cache invalidation bus publishes library and history events', () async {
    final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
    final DateTime observedAt = DateTime.utc(2026, 6, 4, 11, 0);
    final Future<List<CacheInvalidationEvent>> publishedEvents =
        bus.events.take(2).toList();

    bus.publish(
      LibraryItemAdded(
        occurredAt: observedAt,
        mediaLibraryItemId: 'item-1',
        localMediaId: 'media-1',
      ),
    );
    bus.publish(
        HistoryRecorded(occurredAt: observedAt, localMediaId: 'media-1'));
    final List<CacheInvalidationEvent> events = await publishedEvents;
    await bus.close();

    expect(events.whereType<LibraryItemAdded>().single.changeKind,
        MediaLibraryChangeKind.created);
    expect(events.whereType<HistoryRecorded>().single.localMediaId, 'media-1');
  });
}

MediaLibraryItem _item({
  required String id,
  required String mediaId,
  required Uri uri,
  MediaFileFingerprint? fingerprint,
}) {
  return MediaLibraryItem(
    id: MediaLibraryItemId(id),
    identity: _identity(mediaId: mediaId, uri: uri, fingerprint: fingerprint),
    addedAt: DateTime.utc(2026, 6, 4),
  );
}

MediaScanCandidate _candidate(
    {required String mediaId,
    required Uri uri,
    MediaFileFingerprint? fingerprint}) {
  return MediaScanCandidate(
    identity: _identity(mediaId: mediaId, uri: uri, fingerprint: fingerprint),
    sizeBytes: 42,
  );
}

LocalMediaIdentity _identity(
    {required String mediaId,
    required Uri uri,
    MediaFileFingerprint? fingerprint}) {
  return LocalMediaIdentity(
    id: LocalMediaId(mediaId),
    uri: uri,
    basename: uri.pathSegments.isEmpty ? 'episode.mkv' : uri.pathSegments.last,
    fingerprint: fingerprint,
  );
}

PlaybackHistoryEntry _historyEntry({
  required String id,
  required String mediaId,
  required Duration position,
  required DateTime updatedAt,
}) {
  return PlaybackHistoryEntry(
    id: PlaybackHistoryEntryId(id),
    mediaId: LocalMediaId(mediaId),
    position: position,
    duration: const Duration(minutes: 16),
    updatedAt: updatedAt,
  );
}

ProviderBinding _binding({
  required String id,
  required String mediaId,
  required ProviderBindingAuthority authority,
  required double confidence,
}) {
  return ProviderBinding(
    id: ProviderBindingId(id),
    localMediaId: LocalMediaId(mediaId),
    providerId: defaultVideoDetailMetadataProviderId,
    subjectId: const ProviderSubjectId('subject-1'),
    authority: authority,
    confidence: confidence,
    createdAt: DateTime.utc(2026, 6, 4),
  );
}
