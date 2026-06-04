enum StorageDomain {
  sqliteMetadata,
  blobCache,
  mediaCache,
  userSettings,
  migrationState,
  mediaLibrary,
  playbackHistory,
  providerBinding,
}

final class SchemaVersion implements Comparable<SchemaVersion> {
  const SchemaVersion(this.value) : assert(value >= 0, 'Schema version must be non-negative.');

  final int value;

  @override
  int compareTo(SchemaVersion other) => value.compareTo(other.value);
}

abstract interface class SchemaMigration {
  SchemaVersion get from;
  SchemaVersion get to;

  Future<void> migrate(MigrationExecutor executor);
}

abstract interface class MigrationExecutor {
  Future<void> execute(String statement);
}

abstract interface class MetadataStore {
  SchemaVersion get schemaVersion;

  Future<void> migrateToLatest(Iterable<SchemaMigration> migrations);
}

abstract interface class BlobCacheStore {
  Future<Uri> putBlob({
    required String key,
    required Stream<List<int>> bytes,
  });

  Future<Stream<List<int>>?> readBlob(String key);

  Future<void> evictBlob(String key);
}

abstract interface class MediaCacheStore {
  Future<void> recordBufferedRange({
    required String mediaId,
    required int startByte,
    required int endByte,
  });

  Future<List<BufferedRange>> bufferedRanges(String mediaId);
}

final class BufferedRange {
  const BufferedRange({required this.startByte, required this.endByte});

  final int startByte;
  final int endByte;
}

abstract interface class SettingsStore {
  Future<String?> readString(String key);

  Future<void> writeString({required String key, required String value});
}

final class StoredMediaFileFingerprint {
  const StoredMediaFileFingerprint({required this.algorithm, required this.value})
      : assert(algorithm != '', 'Fingerprint algorithm must not be empty.'),
        assert(value != '', 'Fingerprint value must not be empty.');

  final String algorithm;
  final String value;
}

final class StoredMediaLibraryItemRecord {
  const StoredMediaLibraryItemRecord({
    required this.id,
    required this.localMediaId,
    required this.uri,
    required this.basename,
    required this.addedAt,
    this.fingerprint,
    this.duration,
  })  : assert(id != '', 'Media library item id must not be empty.'),
        assert(localMediaId != '', 'Local media id must not be empty.'),
        assert(basename != '', 'Media basename must not be empty.');

  final String id;
  final String localMediaId;
  final Uri uri;
  final String basename;
  final DateTime addedAt;
  final StoredMediaFileFingerprint? fingerprint;
  final Duration? duration;
}

abstract interface class MediaLibraryStore {
  Future<StoredMediaLibraryItemRecord> store(StoredMediaLibraryItemRecord record);

  Future<StoredMediaLibraryItemRecord?> findById(String id);

  Future<StoredMediaLibraryItemRecord?> findByLocalMediaId(String localMediaId);

  Future<StoredMediaLibraryItemRecord?> findByUri(Uri uri);

  Future<StoredMediaLibraryItemRecord?> findByFingerprint(StoredMediaFileFingerprint fingerprint);

  Future<List<StoredMediaLibraryItemRecord>> list({int offset = 0, int limit = 50});

  Future<StoredMediaLibraryItemRecord> update(StoredMediaLibraryItemRecord record);

  Future<bool> remove(String id);

  Future<int> count();
}

final class StoredPlaybackHistoryRecord {
  const StoredPlaybackHistoryRecord({
    required this.id,
    required this.localMediaId,
    required this.position,
    required this.duration,
    required this.updatedAt,
  })  : assert(id != '', 'Playback history entry id must not be empty.'),
        assert(localMediaId != '', 'Local media id must not be empty.'),
        assert(position >= Duration.zero, 'position must not be negative.'),
        assert(duration >= Duration.zero, 'duration must not be negative.');

  final String id;
  final String localMediaId;
  final Duration position;
  final Duration duration;
  final DateTime updatedAt;
}

abstract interface class PlaybackHistoryRepository {
  Future<void> record(StoredPlaybackHistoryRecord record);

  Future<StoredPlaybackHistoryRecord?> latestFor(String localMediaId);

  Future<List<StoredPlaybackHistoryRecord>> continueWatching({int limit = 20});
}

final class StoredProviderBindingRecord {
  const StoredProviderBindingRecord({
    required this.id,
    required this.localMediaId,
    required this.providerId,
    required this.authority,
    required this.confidence,
    required this.createdAt,
    this.providerSubjectId,
  })  : assert(id != '', 'Provider binding id must not be empty.'),
        assert(localMediaId != '', 'Local media id must not be empty.'),
        assert(providerId != '', 'Provider id must not be empty.'),
        assert(authority != '', 'Provider binding authority must not be empty.'),
        assert(confidence >= 0 && confidence <= 1, 'confidence must be between 0 and 1.');

  final String id;
  final String localMediaId;
  final String providerId;
  final String? providerSubjectId;
  final String authority;
  final double confidence;
  final DateTime createdAt;
}

abstract interface class ProviderBindingRepository {
  Future<StoredProviderBindingRecord?> bindingFor(String localMediaId);

  Future<StoredProviderBindingRecord?> bindingForProvider({required String localMediaId, required String providerId});

  Future<List<StoredProviderBindingRecord>> bindingsFor(String localMediaId);

  Future<StoredProviderBindingRecord> saveUserConfirmed(StoredProviderBindingRecord binding);

  Future<StoredProviderBindingRecord> saveAutomaticIfAllowed(StoredProviderBindingRecord candidate);
}

abstract interface class StorageFoundation {
  MetadataStore get metadata;
  BlobCacheStore get blobCache;
  MediaCacheStore get mediaCache;
  SettingsStore get settings;
  MediaLibraryStore get mediaLibrary;
  PlaybackHistoryRepository get playbackHistory;
  ProviderBindingRepository get providerBinding;
}
