enum StorageDomain {
  sqliteMetadata,
  blobCache,
  mediaCache,
  userSettings,
  migrationState,
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

abstract interface class StorageFoundation {
  MetadataStore get metadata;
  BlobCacheStore get blobCache;
  MediaCacheStore get mediaCache;
  SettingsStore get settings;
}
