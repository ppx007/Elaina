enum StorageDomain {
  sqliteMetadata,
  blobCache,
  mediaCache,
  userSettings,
  migrationState,
  mediaLibrary,
  playbackHistory,
  providerBinding,
  subtitleCache,
}

final class SchemaVersion implements Comparable<SchemaVersion> {
  const SchemaVersion(this.value)
      : assert(value >= 0, 'Schema version must be non-negative.');

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
  const StoredMediaFileFingerprint(
      {required this.algorithm, required this.value})
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
  Future<StoredMediaLibraryItemRecord> store(
      StoredMediaLibraryItemRecord record);

  Future<StoredMediaLibraryItemRecord?> findById(String id);

  Future<StoredMediaLibraryItemRecord?> findByLocalMediaId(String localMediaId);

  Future<StoredMediaLibraryItemRecord?> findByUri(Uri uri);

  Future<StoredMediaLibraryItemRecord?> findByFingerprint(
      StoredMediaFileFingerprint fingerprint);

  Future<List<StoredMediaLibraryItemRecord>> list(
      {int offset = 0, int limit = 50});

  Future<StoredMediaLibraryItemRecord> update(
      StoredMediaLibraryItemRecord record);

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
        assert(
            authority != '', 'Provider binding authority must not be empty.'),
        assert(confidence >= 0 && confidence <= 1,
            'confidence must be between 0 and 1.');

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

  Future<StoredProviderBindingRecord?> bindingForProvider(
      {required String localMediaId, required String providerId});

  Future<List<StoredProviderBindingRecord>> bindingsFor(String localMediaId);

  Future<StoredProviderBindingRecord> saveUserConfirmed(
      StoredProviderBindingRecord binding);

  Future<StoredProviderBindingRecord> saveAutomaticIfAllowed(
      StoredProviderBindingRecord candidate);
}

final class StoredSubtitleSearchCandidateRecord {
  const StoredSubtitleSearchCandidateRecord({
    required this.id,
    required this.providerId,
    required this.title,
    required this.format,
    required this.reference,
    required this.confidence,
    this.languageCode,
    this.sourceUri,
  })  : assert(id != '', 'Subtitle candidate id must not be empty.'),
        assert(providerId != '', 'Subtitle provider id must not be empty.'),
        assert(title != '', 'Subtitle candidate title must not be empty.'),
        assert(format != '', 'Subtitle candidate format must not be empty.'),
        assert(
            reference != '', 'Subtitle candidate reference must not be empty.'),
        assert(confidence >= 0 && confidence <= 1,
            'confidence must be between 0 and 1.');

  final String id;
  final String providerId;
  final String title;
  final String format;
  final String reference;
  final double confidence;
  final String? languageCode;
  final Uri? sourceUri;
}

final class StoredSubtitleSearchCacheRecord {
  const StoredSubtitleSearchCacheRecord({
    required this.providerId,
    required this.queryKey,
    required this.candidates,
    required this.cachedAt,
    required this.expiresAt,
  })  : assert(providerId != '', 'Subtitle provider id must not be empty.'),
        assert(queryKey != '', 'Subtitle search query key must not be empty.');

  final String providerId;
  final String queryKey;
  final List<StoredSubtitleSearchCandidateRecord> candidates;
  final DateTime cachedAt;
  final DateTime expiresAt;
}

final class StoredSubtitleContentCacheRecord {
  const StoredSubtitleContentCacheRecord({
    required this.providerId,
    required this.candidateReference,
    required this.content,
    required this.cachedAt,
    required this.expiresAt,
    this.encodingHint,
    this.cachedUri,
  })  : assert(providerId != '', 'Subtitle provider id must not be empty.'),
        assert(candidateReference != '',
            'Subtitle candidate reference must not be empty.'),
        assert(content != '', 'Subtitle content must not be empty.');

  final String providerId;
  final String candidateReference;
  final String content;
  final String? encodingHint;
  final Uri? cachedUri;
  final DateTime cachedAt;
  final DateTime expiresAt;
}

abstract interface class SubtitleCacheStore {
  Future<void> storeSearchResults(StoredSubtitleSearchCacheRecord record);

  Future<StoredSubtitleSearchCacheRecord?> searchResults(
      {required String providerId,
      required String queryKey,
      required DateTime now});

  Future<void> evictSearchResults(
      {required String providerId, required String queryKey});

  Future<void> storeContent(StoredSubtitleContentCacheRecord record);

  Future<StoredSubtitleContentCacheRecord?> content(
      {required String providerId,
      required String candidateReference,
      required DateTime now});

  Future<void> evictContent(
      {required String providerId, required String candidateReference});
}

final class DeterministicSubtitleCacheStore implements SubtitleCacheStore {
  final Map<String, StoredSubtitleSearchCacheRecord>
      _searchResultsByProviderAndQuery =
      <String, StoredSubtitleSearchCacheRecord>{};
  final Map<String, StoredSubtitleContentCacheRecord>
      _contentByProviderAndReference =
      <String, StoredSubtitleContentCacheRecord>{};

  @override
  Future<StoredSubtitleContentCacheRecord?> content(
      {required String providerId,
      required String candidateReference,
      required DateTime now}) {
    final String key = _key(providerId, candidateReference);
    final StoredSubtitleContentCacheRecord? record =
        _contentByProviderAndReference[key];
    if (record == null || _isExpired(record.expiresAt, now)) {
      _contentByProviderAndReference.remove(key);
      return Future<StoredSubtitleContentCacheRecord?>.value();
    }
    return Future<StoredSubtitleContentCacheRecord?>.value(record);
  }

  @override
  Future<void> evictContent(
      {required String providerId, required String candidateReference}) {
    _contentByProviderAndReference.remove(_key(providerId, candidateReference));
    return Future<void>.value();
  }

  @override
  Future<void> evictSearchResults(
      {required String providerId, required String queryKey}) {
    _searchResultsByProviderAndQuery.remove(_key(providerId, queryKey));
    return Future<void>.value();
  }

  @override
  Future<StoredSubtitleSearchCacheRecord?> searchResults(
      {required String providerId,
      required String queryKey,
      required DateTime now}) {
    final String key = _key(providerId, queryKey);
    final StoredSubtitleSearchCacheRecord? record =
        _searchResultsByProviderAndQuery[key];
    if (record == null || _isExpired(record.expiresAt, now)) {
      _searchResultsByProviderAndQuery.remove(key);
      return Future<StoredSubtitleSearchCacheRecord?>.value();
    }
    return Future<StoredSubtitleSearchCacheRecord?>.value(record);
  }

  @override
  Future<void> storeContent(StoredSubtitleContentCacheRecord record) {
    _contentByProviderAndReference[
        _key(record.providerId, record.candidateReference)] = record;
    return Future<void>.value();
  }

  @override
  Future<void> storeSearchResults(StoredSubtitleSearchCacheRecord record) {
    _searchResultsByProviderAndQuery[_key(record.providerId, record.queryKey)] =
        record;
    return Future<void>.value();
  }

  static bool _isExpired(DateTime expiresAt, DateTime now) =>
      !expiresAt.isAfter(now);

  static String _key(String providerId, String cacheKey) =>
      '$providerId::$cacheKey';
}

abstract interface class StorageFoundation {
  MetadataStore get metadata;
  BlobCacheStore get blobCache;
  MediaCacheStore get mediaCache;
  SettingsStore get settings;
  MediaLibraryStore get mediaLibrary;
  PlaybackHistoryRepository get playbackHistory;
  ProviderBindingRepository get providerBinding;
  SubtitleCacheStore get subtitleCache;
}
