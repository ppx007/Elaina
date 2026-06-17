import '../../foundation/baseline_defaults.dart';
import '../../foundation/cache_invalidation/cache_invalidation_bus.dart';
import '../../foundation/storage/storage_contracts.dart';
import '../playback/playback_source_handoff.dart';
import 'local_file_media_scanner.dart';
import 'media_library.dart';
import 'media_library_runtime.dart';

const String storageProviderBindingAuthorityAutomatic = 'automatic';
const String storageProviderBindingAuthorityUserConfirmed = 'user-confirmed';
const String storageMediaLibraryItemIdPrefix = 'stored-media';

final class StorageMediaLibraryCatalogRepository
    implements MediaLibraryCatalogRepository {
  const StorageMediaLibraryCatalogRepository(this._store);

  final MediaLibraryStore _store;

  @override
  Future<int> count() => _store.count();

  @override
  Future<MediaLibraryItem?> findByFingerprint(
    MediaFileFingerprint fingerprint,
  ) async {
    final StoredMediaLibraryItemRecord? record =
        await _store.findByFingerprint(_storedFingerprint(fingerprint));
    return record == null ? null : _mediaLibraryItem(record);
  }

  @override
  Future<MediaLibraryItem?> findById(MediaLibraryItemId id) async {
    final StoredMediaLibraryItemRecord? record =
        await _store.findById(id.value);
    return record == null ? null : _mediaLibraryItem(record);
  }

  @override
  Future<MediaLibraryItem?> findByLocalMediaId(LocalMediaId mediaId) async {
    final StoredMediaLibraryItemRecord? record =
        await _store.findByLocalMediaId(mediaId.value);
    return record == null ? null : _mediaLibraryItem(record);
  }

  @override
  Future<MediaLibraryItem?> findByUri(Uri uri) async {
    final StoredMediaLibraryItemRecord? record = await _store.findByUri(uri);
    return record == null ? null : _mediaLibraryItem(record);
  }

  @override
  Future<List<MediaLibraryItem>> list({
    MediaLibraryQuery query = const MediaLibraryQuery(),
  }) async {
    final List<StoredMediaLibraryItemRecord> records = await _store.list(
      offset: query.offset,
      limit: query.limit,
    );
    return <MediaLibraryItem>[
      for (final StoredMediaLibraryItemRecord record in records)
        _mediaLibraryItem(record),
    ];
  }

  @override
  Future<bool> remove(MediaLibraryItemId id) => _store.remove(id.value);

  @override
  Future<MediaLibraryItem> store(MediaLibraryItem item) async {
    final StoredMediaLibraryItemRecord record =
        await _store.store(_storedMediaLibraryItem(item));
    return _mediaLibraryItem(record);
  }

  @override
  Future<MediaLibraryItem> update(MediaLibraryItem item) async {
    final StoredMediaLibraryItemRecord record =
        await _store.update(_storedMediaLibraryItem(item));
    return _mediaLibraryItem(record);
  }
}

final class StoragePlaybackHistoryStore implements PlaybackHistoryStore {
  const StoragePlaybackHistoryStore(this.repository);

  final PlaybackHistoryRepository repository;

  @override
  Future<List<ContinueWatchingState>> continueWatching({
    int limit = defaultRecentListLimit,
  }) async {
    final List<StoredPlaybackHistoryRecord> records =
        await repository.continueWatching(limit: limit);
    return <ContinueWatchingState>[
      for (final StoredPlaybackHistoryRecord record in records)
        ContinueWatchingState(
          mediaId: LocalMediaId(record.localMediaId),
          position: record.position,
          duration: record.duration,
          updatedAt: record.updatedAt,
        ),
    ];
  }

  @override
  Future<PlaybackHistoryEntry?> latestFor(LocalMediaId mediaId) async {
    final StoredPlaybackHistoryRecord? record =
        await repository.latestFor(mediaId.value);
    return record == null ? null : _playbackHistoryEntry(record);
  }

  @override
  Future<void> record(PlaybackHistoryEntry entry) {
    return repository.record(_storedPlaybackHistory(entry));
  }
}

final class StorageProviderBindingStore implements ProviderBindingStore {
  const StorageProviderBindingStore(this.repository);

  final ProviderBindingRepository repository;

  @override
  Future<ProviderBinding?> bindingFor(LocalMediaId mediaId) async {
    final StoredProviderBindingRecord? record =
        await repository.bindingFor(mediaId.value);
    return record == null ? null : _providerBinding(record);
  }

  @override
  Future<ProviderBinding?> bindingForProvider({
    required LocalMediaId mediaId,
    required String providerId,
  }) async {
    final StoredProviderBindingRecord? record =
        await repository.bindingForProvider(
      localMediaId: mediaId.value,
      providerId: providerId,
    );
    return record == null ? null : _providerBinding(record);
  }

  @override
  Future<List<ProviderBinding>> bindingsFor(LocalMediaId mediaId) async {
    final List<StoredProviderBindingRecord> records =
        await repository.bindingsFor(mediaId.value);
    return <ProviderBinding>[
      for (final StoredProviderBindingRecord record in records)
        _providerBinding(record),
    ];
  }

  @override
  Future<ProviderBinding> saveAutomaticIfAllowed(ProviderBinding candidate) {
    return repository
        .saveAutomaticIfAllowed(_storedProviderBinding(candidate))
        .then(_providerBinding);
  }

  @override
  Future<ProviderBinding> saveUserConfirmed(ProviderBinding binding) {
    return repository
        .saveUserConfirmed(_storedProviderBinding(binding))
        .then(_providerBinding);
  }
}

final class StorageMediaBatchImportContract
    implements MediaBatchImportContract {
  StorageMediaBatchImportContract({
    required this.repository,
    DateTime Function()? clock,
    this.itemIdPrefix = storageMediaLibraryItemIdPrefix,
  })  : assert(itemIdPrefix != '', 'itemIdPrefix must not be empty.'),
        _clock = clock ?? _defaultClock;

  final MediaLibraryCatalogRepository repository;
  final DateTime Function() _clock;
  final String itemIdPrefix;

  @override
  Future<MediaImportResult> importBatch(
    Iterable<MediaScanCandidate> candidates,
  ) async {
    final List<MediaImportItemOutcome> outcomes = <MediaImportItemOutcome>[];
    var index = 0;
    for (final MediaScanCandidate candidate in candidates) {
      final MediaLibraryItem? uriMatch =
          await repository.findByUri(candidate.identity.uri);
      final MediaFileFingerprint? fingerprint = candidate.identity.fingerprint;
      final MediaLibraryItem? fingerprintMatch = fingerprint == null
          ? null
          : await repository.findByFingerprint(fingerprint);

      if (uriMatch != null &&
          fingerprintMatch != null &&
          uriMatch.id.value != fingerprintMatch.id.value) {
        outcomes.add(
          MediaImportItemOutcome.failed(
            MediaImportFailure(
              kind: MediaImportFailureKind.duplicateConflict,
              candidate: candidate,
              message:
                  'Candidate URI and fingerprint match different catalog items.',
            ),
          ),
        );
        index += 1;
        continue;
      }

      final MediaLibraryItem? duplicate = uriMatch ?? fingerprintMatch;
      if (duplicate != null) {
        outcomes.add(
          MediaImportItemOutcome.skippedDuplicate(
            candidate: candidate,
            item: duplicate,
          ),
        );
        index += 1;
        continue;
      }

      final MediaLibraryItem item = MediaLibraryItem(
        id: MediaLibraryItemId(
          '$itemIdPrefix-${candidate.identity.id.value}-$index',
        ),
        identity: candidate.identity,
        addedAt: _clock(),
        duration: candidate.duration,
      );
      outcomes.add(
        MediaImportItemOutcome.imported(
          candidate: candidate,
          item: await repository.store(item),
        ),
      );
      index += 1;
    }
    return MediaImportResult(outcomes: outcomes);
  }

  static DateTime _defaultClock() => deterministicContractEpoch;
}

MediaLibraryBootstrap storageBackedMediaLibraryBootstrap({
  required StorageFoundation storage,
  required CacheInvalidationBus invalidationBus,
  MediaLibraryScanner? scanner,
  PlaybackSourceHandoffContract playbackSourceHandoff =
      const LocalPlaybackSourceHandoff(),
  DateTime Function()? now,
}) {
  final StorageMediaLibraryCatalogRepository catalog =
      StorageMediaLibraryCatalogRepository(storage.mediaLibrary);
  return MediaLibraryBootstrap(
    scanner: scanner ?? LocalFileMediaLibraryScanner(clock: now),
    catalogRepository: catalog,
    importer: StorageMediaBatchImportContract(
      repository: catalog,
      clock: now,
    ),
    historyStore: StoragePlaybackHistoryStore(storage.playbackHistory),
    bindingStore: StorageProviderBindingStore(storage.providerBinding),
    playbackSourceHandoff: playbackSourceHandoff,
    invalidationBus: invalidationBus,
    now: now,
  );
}

StoredMediaLibraryItemRecord _storedMediaLibraryItem(MediaLibraryItem item) {
  return StoredMediaLibraryItemRecord(
    id: item.id.value,
    localMediaId: item.identity.id.value,
    uri: item.identity.uri,
    basename: item.identity.basename,
    addedAt: item.addedAt,
    fingerprint: item.identity.fingerprint == null
        ? null
        : _storedFingerprint(item.identity.fingerprint!),
    duration: item.duration,
  );
}

MediaLibraryItem _mediaLibraryItem(StoredMediaLibraryItemRecord record) {
  return MediaLibraryItem(
    id: MediaLibraryItemId(record.id),
    identity: LocalMediaIdentity(
      id: LocalMediaId(record.localMediaId),
      uri: record.uri,
      basename: record.basename,
      fingerprint: record.fingerprint == null
          ? null
          : _mediaFingerprint(record.fingerprint!),
    ),
    addedAt: record.addedAt,
    duration: record.duration,
  );
}

StoredMediaFileFingerprint _storedFingerprint(
  MediaFileFingerprint fingerprint,
) {
  return StoredMediaFileFingerprint(
    algorithm: fingerprint.algorithm,
    value: fingerprint.value,
  );
}

MediaFileFingerprint _mediaFingerprint(
  StoredMediaFileFingerprint fingerprint,
) {
  return MediaFileFingerprint(
    algorithm: fingerprint.algorithm,
    value: fingerprint.value,
  );
}

StoredPlaybackHistoryRecord _storedPlaybackHistory(
  PlaybackHistoryEntry entry,
) {
  return StoredPlaybackHistoryRecord(
    id: entry.id.value,
    localMediaId: entry.mediaId.value,
    position: entry.position,
    duration: entry.duration,
    updatedAt: entry.updatedAt,
  );
}

PlaybackHistoryEntry _playbackHistoryEntry(
  StoredPlaybackHistoryRecord record,
) {
  return PlaybackHistoryEntry(
    id: PlaybackHistoryEntryId(record.id),
    mediaId: LocalMediaId(record.localMediaId),
    position: record.position,
    duration: record.duration,
    updatedAt: record.updatedAt,
  );
}

StoredProviderBindingRecord _storedProviderBinding(ProviderBinding binding) {
  return StoredProviderBindingRecord(
    id: binding.id.value,
    localMediaId: binding.localMediaId.value,
    providerId: binding.providerId,
    providerSubjectId: binding.subjectId?.value,
    authority: _storageAuthority(binding.authority),
    confidence: binding.confidence,
    createdAt: binding.createdAt,
  );
}

ProviderBinding _providerBinding(StoredProviderBindingRecord record) {
  return ProviderBinding(
    id: ProviderBindingId(record.id),
    localMediaId: LocalMediaId(record.localMediaId),
    providerId: record.providerId,
    subjectId: record.providerSubjectId == null
        ? null
        : ProviderSubjectId(record.providerSubjectId!),
    authority: _providerBindingAuthority(record.authority),
    confidence: record.confidence,
    createdAt: record.createdAt,
  );
}

String _storageAuthority(ProviderBindingAuthority authority) {
  return switch (authority) {
    ProviderBindingAuthority.automatic =>
      storageProviderBindingAuthorityAutomatic,
    ProviderBindingAuthority.userConfirmed =>
      storageProviderBindingAuthorityUserConfirmed,
  };
}

ProviderBindingAuthority _providerBindingAuthority(String authority) {
  return authority == storageProviderBindingAuthorityUserConfirmed
      ? ProviderBindingAuthority.userConfirmed
      : ProviderBindingAuthority.automatic;
}
