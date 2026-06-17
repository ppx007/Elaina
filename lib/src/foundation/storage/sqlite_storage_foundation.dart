import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart';

import '../baseline_defaults.dart';
import '../deterministic_storage_foundation.dart';
import 'storage_contracts.dart';

const int sqliteStorageSchemaVersion = 1;

final class SqliteStorageFoundation implements StorageFoundation {
  SqliteStorageFoundation._({
    required Database database,
    StorageFoundation? fallback,
  })  : _database = database,
        _fallback = fallback ?? DeterministicStorageFoundation() {
    _initializeCoreSchema(_database);
    _metadata = SqliteMetadataStore(_database);
    _settings = SqliteSettingsStore(_database);
    _blobCache = SqliteBlobCacheStore(_database);
    _mediaCache = SqliteMediaCacheStore(_database);
    _mediaLibrary = SqliteMediaLibraryStore(_database);
    _playbackHistory = SqlitePlaybackHistoryRepository(_database);
    _providerBinding = SqliteProviderBindingRepository(_database);
    _subtitleCache = SqliteSubtitleCacheStore(_database);
  }

  factory SqliteStorageFoundation.inMemory({StorageFoundation? fallback}) {
    return SqliteStorageFoundation._(
      database: sqlite3.openInMemory(),
      fallback: fallback,
    );
  }

  factory SqliteStorageFoundation.open(
    String path, {
    StorageFoundation? fallback,
  }) {
    return SqliteStorageFoundation._(
      database: sqlite3.open(path),
      fallback: fallback,
    );
  }

  final Database _database;
  final StorageFoundation _fallback;
  late final SqliteMetadataStore _metadata;
  late final SqliteSettingsStore _settings;
  late final SqliteBlobCacheStore _blobCache;
  late final SqliteMediaCacheStore _mediaCache;
  late final SqliteMediaLibraryStore _mediaLibrary;
  late final SqlitePlaybackHistoryRepository _playbackHistory;
  late final SqliteProviderBindingRepository _providerBinding;
  late final SqliteSubtitleCacheStore _subtitleCache;

  void dispose() {
    _database.close();
  }

  @override
  MetadataStore get metadata => _metadata;

  @override
  BlobCacheStore get blobCache => _blobCache;

  @override
  MediaCacheStore get mediaCache => _mediaCache;

  @override
  SettingsStore get settings => _settings;

  @override
  MediaLibraryStore get mediaLibrary => _mediaLibrary;

  @override
  PlaybackHistoryRepository get playbackHistory => _playbackHistory;

  @override
  ProviderBindingRepository get providerBinding => _providerBinding;

  @override
  SubtitleCacheStore get subtitleCache => _subtitleCache;

  @override
  RssFeedStore get rssFeed => _fallback.rssFeed;

  @override
  RssAutoDownloadPolicyStore get rssAutoDownloadPolicy =>
      _fallback.rssAutoDownloadPolicy;

  @override
  OnlineRuleRuntimeStore get onlineRuleRuntime => _fallback.onlineRuleRuntime;

  @override
  WebViewSessionBackfillStore get webViewSessionBackfill =>
      _fallback.webViewSessionBackfill;

  @override
  NetworkPolicyStore get networkPolicy => _fallback.networkPolicy;

  @override
  DiagnosticsStore get diagnostics => _fallback.diagnostics;

  @override
  SeasonalCatalogStore get seasonalCatalog => _fallback.seasonalCatalog;

  @override
  BangumiMatchQueueStore get bangumiMatchQueue => _fallback.bangumiMatchQueue;

  @override
  BtTaskStore get btTask => _fallback.btTask;

  @override
  VirtualMediaStreamStore get virtualMediaStream =>
      _fallback.virtualMediaStream;

  @override
  PiecePrioritySchedulerStore get piecePriorityScheduler =>
      _fallback.piecePriorityScheduler;

  @override
  TimelineOverlayStore get timelineOverlay => _fallback.timelineOverlay;

  @override
  EnhancementProfileStore get videoEnhancement => _fallback.videoEnhancement;

  @override
  AVSyncGuardStore get avSyncGuard => _fallback.avSyncGuard;

  @override
  AdvancedCaptionStore get advancedCaptions => _fallback.advancedCaptions;

  @override
  FallbackAdapterStore get fallbackAdapter => _fallback.fallbackAdapter;
}

final class SqliteMetadataStore implements MetadataStore {
  SqliteMetadataStore(this._database);

  final Database _database;

  @override
  SchemaVersion get schemaVersion {
    final ResultSet rows = _database.select(
      'select version from schema_version where id = 1',
    );
    return SchemaVersion(rows.isEmpty ? 0 : rows.first['version'] as int);
  }

  @override
  Future<void> migrateToLatest(Iterable<SchemaMigration> migrations) async {
    final List<SchemaMigration> ordered = migrations.toList()
      ..sort(
        (SchemaMigration a, SchemaMigration b) => a.from.compareTo(b.from),
      );
    int current = schemaVersion.value;
    _database.execute('begin immediate');
    try {
      for (final SchemaMigration migration in ordered) {
        if (migration.to.value <= current) continue;
        if (migration.from.value != current) {
          throw StateError(
            'Cannot migrate schema from $current using migration '
            '${migration.from.value}->${migration.to.value}.',
          );
        }
        await migration.migrate(_SqliteMigrationExecutor(_database));
        _database.execute(
          'update schema_version set version = ? where id = 1',
          <Object?>[migration.to.value],
        );
        current = migration.to.value;
      }
      _database.execute('commit');
    } catch (_) {
      _database.execute('rollback');
      rethrow;
    }
  }
}

final class SqliteSettingsStore implements SettingsStore {
  SqliteSettingsStore(this._database);

  final Database _database;

  @override
  Future<String?> readString(String key) async {
    final ResultSet rows = _database.select(
      'select value from settings where key = ?',
      <Object?>[key],
    );
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  @override
  Future<void> writeString({required String key, required String value}) async {
    _database.execute(
      'insert into settings(key, value) values(?, ?) '
      'on conflict(key) do update set value = excluded.value',
      <Object?>[key, value],
    );
  }
}

final class SqliteBlobCacheStore implements BlobCacheStore {
  SqliteBlobCacheStore(this._database);

  final Database _database;

  @override
  Future<Uri> putBlob({
    required String key,
    required Stream<List<int>> bytes,
  }) async {
    final List<int> data = await bytes.fold<List<int>>(
      <int>[],
      (List<int> previous, List<int> chunk) => previous..addAll(chunk),
    );
    _database.execute(
      'insert into blob_cache(key, bytes) values(?, ?) '
      'on conflict(key) do update set bytes = excluded.bytes',
      <Object?>[key, Uint8List.fromList(data)],
    );
    return Uri(
      scheme: 'sqlite-blob',
      host: 'local',
      path: '/${Uri.encodeComponent(key)}',
    );
  }

  @override
  Future<Stream<List<int>>?> readBlob(String key) async {
    final ResultSet rows = _database.select(
      'select bytes from blob_cache where key = ?',
      <Object?>[key],
    );
    if (rows.isEmpty) return null;
    final Object bytes = rows.first['bytes'] as Object;
    return Stream<List<int>>.value(List<int>.from(bytes as Iterable<int>));
  }

  @override
  Future<void> evictBlob(String key) async {
    _database.execute('delete from blob_cache where key = ?', <Object?>[key]);
  }
}

final class SqliteMediaCacheStore implements MediaCacheStore {
  SqliteMediaCacheStore(this._database);

  final Database _database;

  @override
  Future<List<BufferedRange>> bufferedRanges(String mediaId) async {
    final ResultSet rows = _database.select(
      'select start_byte, end_byte from media_cache_ranges '
      'where media_id = ? order by start_byte asc, end_byte asc',
      <Object?>[mediaId],
    );
    return <BufferedRange>[
      for (final Row row in rows)
        BufferedRange(
          startByte: row['start_byte'] as int,
          endByte: row['end_byte'] as int,
        ),
    ];
  }

  @override
  Future<void> recordBufferedRange({
    required String mediaId,
    required int startByte,
    required int endByte,
  }) async {
    _database.execute(
      'insert into media_cache_ranges(media_id, start_byte, end_byte) '
      'values(?, ?, ?)',
      <Object?>[mediaId, startByte, endByte],
    );
  }
}

final class SqliteMediaLibraryStore implements MediaLibraryStore {
  SqliteMediaLibraryStore(this._database);

  final Database _database;

  @override
  Future<int> count() async {
    final ResultSet rows =
        _database.select('select count(*) as c from media_library');
    return rows.first['c'] as int;
  }

  @override
  Future<StoredMediaLibraryItemRecord?> findByFingerprint(
    StoredMediaFileFingerprint fingerprint,
  ) async {
    final ResultSet rows = _database.select(
      'select * from media_library '
      'where fingerprint_algorithm = ? and fingerprint_value = ? '
      'limit 1',
      <Object?>[fingerprint.algorithm, fingerprint.value],
    );
    return rows.isEmpty ? null : _mediaLibraryRecord(rows.first);
  }

  @override
  Future<StoredMediaLibraryItemRecord?> findById(String id) async {
    return _findOne('select * from media_library where id = ?', <Object?>[id]);
  }

  @override
  Future<StoredMediaLibraryItemRecord?> findByLocalMediaId(
    String localMediaId,
  ) async {
    return _findOne(
      'select * from media_library where local_media_id = ?',
      <Object?>[localMediaId],
    );
  }

  @override
  Future<StoredMediaLibraryItemRecord?> findByUri(Uri uri) async {
    return _findOne(
      'select * from media_library where uri = ?',
      <Object?>[uri.toString()],
    );
  }

  @override
  Future<List<StoredMediaLibraryItemRecord>> list({
    int offset = 0,
    int limit = defaultListPageLimit,
  }) async {
    final ResultSet rows = _database.select(
      'select * from media_library order by added_at_ms desc, id asc '
      'limit ? offset ?',
      <Object?>[limit, offset],
    );
    return <StoredMediaLibraryItemRecord>[
      for (final Row row in rows) _mediaLibraryRecord(row),
    ];
  }

  @override
  Future<bool> remove(String id) async {
    final int before = await count();
    _database.execute('delete from media_library where id = ?', <Object?>[id]);
    return await count() < before;
  }

  @override
  Future<StoredMediaLibraryItemRecord> store(
    StoredMediaLibraryItemRecord record,
  ) async {
    _upsert(record);
    return record;
  }

  @override
  Future<StoredMediaLibraryItemRecord> update(
    StoredMediaLibraryItemRecord record,
  ) async {
    _upsert(record);
    return record;
  }

  Future<StoredMediaLibraryItemRecord?> _findOne(
    String sql,
    List<Object?> parameters,
  ) async {
    final ResultSet rows = _database.select(sql, parameters);
    return rows.isEmpty ? null : _mediaLibraryRecord(rows.first);
  }

  void _upsert(StoredMediaLibraryItemRecord record) {
    _database.execute(
      'insert into media_library('
      'id, local_media_id, uri, basename, added_at_ms, '
      'fingerprint_algorithm, fingerprint_value, duration_us'
      ') values(?, ?, ?, ?, ?, ?, ?, ?) '
      'on conflict(id) do update set '
      'local_media_id = excluded.local_media_id, '
      'uri = excluded.uri, '
      'basename = excluded.basename, '
      'added_at_ms = excluded.added_at_ms, '
      'fingerprint_algorithm = excluded.fingerprint_algorithm, '
      'fingerprint_value = excluded.fingerprint_value, '
      'duration_us = excluded.duration_us',
      <Object?>[
        record.id,
        record.localMediaId,
        record.uri.toString(),
        record.basename,
        _dateTimeToMillis(record.addedAt),
        record.fingerprint?.algorithm,
        record.fingerprint?.value,
        record.duration?.inMicroseconds,
      ],
    );
  }
}

final class SqlitePlaybackHistoryRepository
    implements PlaybackHistoryRepository {
  SqlitePlaybackHistoryRepository(this._database);

  final Database _database;

  @override
  Future<List<StoredPlaybackHistoryRecord>> continueWatching({
    int limit = defaultRecentListLimit,
  }) async {
    final ResultSet rows = _database.select(
      'select * from playback_history order by updated_at_ms desc, id asc limit ?',
      <Object?>[limit],
    );
    return <StoredPlaybackHistoryRecord>[
      for (final Row row in rows) _playbackHistoryRecord(row),
    ];
  }

  @override
  Future<StoredPlaybackHistoryRecord?> latestFor(String localMediaId) async {
    final ResultSet rows = _database.select(
      'select * from playback_history where local_media_id = ? '
      'order by updated_at_ms desc, id asc limit 1',
      <Object?>[localMediaId],
    );
    return rows.isEmpty ? null : _playbackHistoryRecord(rows.first);
  }

  @override
  Future<void> record(StoredPlaybackHistoryRecord record) async {
    _database.execute(
      'insert into playback_history('
      'id, local_media_id, position_us, duration_us, updated_at_ms'
      ') values(?, ?, ?, ?, ?) '
      'on conflict(id) do update set '
      'local_media_id = excluded.local_media_id, '
      'position_us = excluded.position_us, '
      'duration_us = excluded.duration_us, '
      'updated_at_ms = excluded.updated_at_ms',
      <Object?>[
        record.id,
        record.localMediaId,
        record.position.inMicroseconds,
        record.duration.inMicroseconds,
        _dateTimeToMillis(record.updatedAt),
      ],
    );
  }
}

final class SqliteProviderBindingRepository
    implements ProviderBindingRepository {
  SqliteProviderBindingRepository(this._database);

  final Database _database;

  @override
  Future<StoredProviderBindingRecord?> bindingFor(String localMediaId) async {
    final List<StoredProviderBindingRecord> bindings =
        await bindingsFor(localMediaId);
    StoredProviderBindingRecord? strongest;
    for (final StoredProviderBindingRecord binding in bindings) {
      if (strongest == null || _outranks(binding, strongest)) {
        strongest = binding;
      }
    }
    return strongest;
  }

  @override
  Future<StoredProviderBindingRecord?> bindingForProvider({
    required String localMediaId,
    required String providerId,
  }) async {
    final ResultSet rows = _database.select(
      'select * from provider_bindings '
      'where local_media_id = ? and provider_id = ? limit 1',
      <Object?>[localMediaId, providerId],
    );
    return rows.isEmpty ? null : _providerBindingRecord(rows.first);
  }

  @override
  Future<List<StoredProviderBindingRecord>> bindingsFor(
    String localMediaId,
  ) async {
    final ResultSet rows = _database.select(
      'select * from provider_bindings where local_media_id = ? '
      'order by created_at_ms asc, id asc',
      <Object?>[localMediaId],
    );
    return <StoredProviderBindingRecord>[
      for (final Row row in rows) _providerBindingRecord(row),
    ];
  }

  @override
  Future<StoredProviderBindingRecord> saveAutomaticIfAllowed(
    StoredProviderBindingRecord candidate,
  ) async {
    final StoredProviderBindingRecord? existing = await bindingForProvider(
      localMediaId: candidate.localMediaId,
      providerId: candidate.providerId,
    );
    if (existing != null && _outranks(existing, candidate)) {
      return existing;
    }
    _upsert(candidate);
    return candidate;
  }

  @override
  Future<StoredProviderBindingRecord> saveUserConfirmed(
    StoredProviderBindingRecord binding,
  ) async {
    _upsert(binding);
    return binding;
  }

  void _upsert(StoredProviderBindingRecord binding) {
    _database.execute(
      'insert into provider_bindings('
      'id, local_media_id, provider_id, provider_subject_id, '
      'authority, confidence, created_at_ms'
      ') values(?, ?, ?, ?, ?, ?, ?) '
      'on conflict(local_media_id, provider_id) do update set '
      'id = excluded.id, '
      'provider_subject_id = excluded.provider_subject_id, '
      'authority = excluded.authority, '
      'confidence = excluded.confidence, '
      'created_at_ms = excluded.created_at_ms',
      <Object?>[
        binding.id,
        binding.localMediaId,
        binding.providerId,
        binding.providerSubjectId,
        binding.authority,
        binding.confidence,
        _dateTimeToMillis(binding.createdAt),
      ],
    );
  }

  static bool _outranks(
    StoredProviderBindingRecord candidate,
    StoredProviderBindingRecord existing,
  ) {
    if (_isUserConfirmed(candidate) != _isUserConfirmed(existing)) {
      return _isUserConfirmed(candidate);
    }
    return candidate.confidence > existing.confidence;
  }

  static bool _isUserConfirmed(StoredProviderBindingRecord binding) {
    return binding.authority == 'user-confirmed';
  }
}

final class SqliteSubtitleCacheStore implements SubtitleCacheStore {
  SqliteSubtitleCacheStore(this._database);

  final Database _database;

  @override
  Future<StoredSubtitleContentCacheRecord?> content({
    required String providerId,
    required String candidateReference,
    required DateTime now,
  }) async {
    final ResultSet rows = _database.select(
      'select * from subtitle_contents '
      'where provider_id = ? and candidate_reference = ?',
      <Object?>[providerId, candidateReference],
    );
    if (rows.isEmpty) return null;
    final StoredSubtitleContentCacheRecord record =
        _subtitleContentRecord(rows.first);
    if (!_expiresAfter(record.expiresAt, now)) {
      await evictContent(
        providerId: providerId,
        candidateReference: candidateReference,
      );
      return null;
    }
    return record;
  }

  @override
  Future<void> evictContent({
    required String providerId,
    required String candidateReference,
  }) async {
    _database.execute(
      'delete from subtitle_contents '
      'where provider_id = ? and candidate_reference = ?',
      <Object?>[providerId, candidateReference],
    );
  }

  @override
  Future<void> evictSearchResults({
    required String providerId,
    required String queryKey,
  }) async {
    _database.execute(
      'delete from subtitle_searches where provider_id = ? and query_key = ?',
      <Object?>[providerId, queryKey],
    );
  }

  @override
  Future<StoredSubtitleSearchCacheRecord?> searchResults({
    required String providerId,
    required String queryKey,
    required DateTime now,
  }) async {
    final ResultSet rows = _database.select(
      'select * from subtitle_searches where provider_id = ? and query_key = ?',
      <Object?>[providerId, queryKey],
    );
    if (rows.isEmpty) return null;
    final Row search = rows.first;
    final DateTime expiresAt =
        _dateTimeFromMillis(search['expires_at_ms'] as int);
    if (!_expiresAfter(expiresAt, now)) {
      await evictSearchResults(providerId: providerId, queryKey: queryKey);
      return null;
    }
    final ResultSet candidateRows = _database.select(
      'select * from subtitle_search_candidates '
      'where provider_id = ? and query_key = ? order by position asc',
      <Object?>[providerId, queryKey],
    );
    return StoredSubtitleSearchCacheRecord(
      providerId: providerId,
      queryKey: queryKey,
      candidates: <StoredSubtitleSearchCandidateRecord>[
        for (final Row row in candidateRows) _subtitleCandidateRecord(row),
      ],
      cachedAt: _dateTimeFromMillis(search['cached_at_ms'] as int),
      expiresAt: expiresAt,
    );
  }

  @override
  Future<void> storeContent(StoredSubtitleContentCacheRecord record) async {
    _database.execute(
      'insert into subtitle_contents('
      'provider_id, candidate_reference, content, encoding_hint, cached_uri, '
      'cached_at_ms, expires_at_ms'
      ') values(?, ?, ?, ?, ?, ?, ?) '
      'on conflict(provider_id, candidate_reference) do update set '
      'content = excluded.content, '
      'encoding_hint = excluded.encoding_hint, '
      'cached_uri = excluded.cached_uri, '
      'cached_at_ms = excluded.cached_at_ms, '
      'expires_at_ms = excluded.expires_at_ms',
      <Object?>[
        record.providerId,
        record.candidateReference,
        record.content,
        record.encodingHint,
        record.cachedUri?.toString(),
        _dateTimeToMillis(record.cachedAt),
        _dateTimeToMillis(record.expiresAt),
      ],
    );
  }

  @override
  Future<void> storeSearchResults(
    StoredSubtitleSearchCacheRecord record,
  ) async {
    _database.execute('begin immediate');
    try {
      _database.execute(
        'insert into subtitle_searches('
        'provider_id, query_key, cached_at_ms, expires_at_ms'
        ') values(?, ?, ?, ?) '
        'on conflict(provider_id, query_key) do update set '
        'cached_at_ms = excluded.cached_at_ms, '
        'expires_at_ms = excluded.expires_at_ms',
        <Object?>[
          record.providerId,
          record.queryKey,
          _dateTimeToMillis(record.cachedAt),
          _dateTimeToMillis(record.expiresAt),
        ],
      );
      _database.execute(
        'delete from subtitle_search_candidates '
        'where provider_id = ? and query_key = ?',
        <Object?>[record.providerId, record.queryKey],
      );
      for (int i = 0; i < record.candidates.length; i += 1) {
        final StoredSubtitleSearchCandidateRecord candidate =
            record.candidates[i];
        _database.execute(
          'insert into subtitle_search_candidates('
          'provider_id, query_key, position, id, title, format, reference, '
          'confidence, language_code, source_uri'
          ') values(?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          <Object?>[
            record.providerId,
            record.queryKey,
            i,
            candidate.id,
            candidate.title,
            candidate.format,
            candidate.reference,
            candidate.confidence,
            candidate.languageCode,
            candidate.sourceUri?.toString(),
          ],
        );
      }
      _database.execute('commit');
    } catch (_) {
      _database.execute('rollback');
      rethrow;
    }
  }
}

final class _SqliteMigrationExecutor implements MigrationExecutor {
  const _SqliteMigrationExecutor(this._database);

  final Database _database;

  @override
  Future<void> execute(String statement) async {
    _database.execute(statement);
  }
}

StoredMediaLibraryItemRecord _mediaLibraryRecord(Row row) {
  final Object? fingerprintAlgorithm = row['fingerprint_algorithm'];
  final Object? fingerprintValue = row['fingerprint_value'];
  return StoredMediaLibraryItemRecord(
    id: row['id'] as String,
    localMediaId: row['local_media_id'] as String,
    uri: Uri.parse(row['uri'] as String),
    basename: row['basename'] as String,
    addedAt: _dateTimeFromMillis(row['added_at_ms'] as int),
    fingerprint: fingerprintAlgorithm == null || fingerprintValue == null
        ? null
        : StoredMediaFileFingerprint(
            algorithm: fingerprintAlgorithm as String,
            value: fingerprintValue as String,
          ),
    duration: _durationFromMicros(row['duration_us']),
  );
}

StoredPlaybackHistoryRecord _playbackHistoryRecord(Row row) {
  return StoredPlaybackHistoryRecord(
    id: row['id'] as String,
    localMediaId: row['local_media_id'] as String,
    position: Duration(microseconds: row['position_us'] as int),
    duration: Duration(microseconds: row['duration_us'] as int),
    updatedAt: _dateTimeFromMillis(row['updated_at_ms'] as int),
  );
}

StoredProviderBindingRecord _providerBindingRecord(Row row) {
  return StoredProviderBindingRecord(
    id: row['id'] as String,
    localMediaId: row['local_media_id'] as String,
    providerId: row['provider_id'] as String,
    providerSubjectId: row['provider_subject_id'] as String?,
    authority: row['authority'] as String,
    confidence: (row['confidence'] as num).toDouble(),
    createdAt: _dateTimeFromMillis(row['created_at_ms'] as int),
  );
}

StoredSubtitleSearchCandidateRecord _subtitleCandidateRecord(Row row) {
  final Object? sourceUri = row['source_uri'];
  return StoredSubtitleSearchCandidateRecord(
    id: row['id'] as String,
    providerId: row['provider_id'] as String,
    title: row['title'] as String,
    format: row['format'] as String,
    reference: row['reference'] as String,
    confidence: (row['confidence'] as num).toDouble(),
    languageCode: row['language_code'] as String?,
    sourceUri: sourceUri == null ? null : Uri.parse(sourceUri as String),
  );
}

StoredSubtitleContentCacheRecord _subtitleContentRecord(Row row) {
  final Object? cachedUri = row['cached_uri'];
  return StoredSubtitleContentCacheRecord(
    providerId: row['provider_id'] as String,
    candidateReference: row['candidate_reference'] as String,
    content: row['content'] as String,
    encodingHint: row['encoding_hint'] as String?,
    cachedUri: cachedUri == null ? null : Uri.parse(cachedUri as String),
    cachedAt: _dateTimeFromMillis(row['cached_at_ms'] as int),
    expiresAt: _dateTimeFromMillis(row['expires_at_ms'] as int),
  );
}

int _dateTimeToMillis(DateTime value) => value.toUtc().millisecondsSinceEpoch;

DateTime _dateTimeFromMillis(int value) {
  return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
}

Duration? _durationFromMicros(Object? value) {
  return value == null ? null : Duration(microseconds: value as int);
}

bool _expiresAfter(DateTime expiresAt, DateTime now) => expiresAt.isAfter(now);

void _initializeCoreSchema(Database database) {
  database.execute('pragma foreign_keys = on');
  database.execute(
    'create table if not exists schema_version('
    'id integer primary key check(id = 1), '
    'version integer not null'
    ')',
  );
  database.execute(
    'insert or ignore into schema_version(id, version) values(1, 0)',
  );
  database.execute(
    'create table if not exists settings('
    'key text primary key, '
    'value text not null'
    ')',
  );
  database.execute(
    'create table if not exists blob_cache('
    'key text primary key, '
    'bytes blob not null'
    ')',
  );
  database.execute(
    'create table if not exists media_cache_ranges('
    'id integer primary key autoincrement, '
    'media_id text not null, '
    'start_byte integer not null, '
    'end_byte integer not null'
    ')',
  );
  database.execute(
    'create index if not exists idx_media_cache_ranges_media '
    'on media_cache_ranges(media_id, start_byte)',
  );
  database.execute(
    'create table if not exists media_library('
    'id text primary key, '
    'local_media_id text not null unique, '
    'uri text not null unique, '
    'basename text not null, '
    'added_at_ms integer not null, '
    'fingerprint_algorithm text, '
    'fingerprint_value text, '
    'duration_us integer'
    ')',
  );
  database.execute(
    'create index if not exists idx_media_library_fingerprint '
    'on media_library(fingerprint_algorithm, fingerprint_value)',
  );
  database.execute(
    'create table if not exists playback_history('
    'id text primary key, '
    'local_media_id text not null, '
    'position_us integer not null, '
    'duration_us integer not null, '
    'updated_at_ms integer not null'
    ')',
  );
  database.execute(
    'create index if not exists idx_playback_history_media_updated '
    'on playback_history(local_media_id, updated_at_ms desc)',
  );
  database.execute(
    'create table if not exists provider_bindings('
    'id text not null, '
    'local_media_id text not null, '
    'provider_id text not null, '
    'provider_subject_id text, '
    'authority text not null, '
    'confidence real not null, '
    'created_at_ms integer not null, '
    'primary key(local_media_id, provider_id)'
    ')',
  );
  database.execute(
    'create table if not exists subtitle_searches('
    'provider_id text not null, '
    'query_key text not null, '
    'cached_at_ms integer not null, '
    'expires_at_ms integer not null, '
    'primary key(provider_id, query_key)'
    ')',
  );
  database.execute(
    'create table if not exists subtitle_search_candidates('
    'provider_id text not null, '
    'query_key text not null, '
    'position integer not null, '
    'id text not null, '
    'title text not null, '
    'format text not null, '
    'reference text not null, '
    'confidence real not null, '
    'language_code text, '
    'source_uri text, '
    'primary key(provider_id, query_key, position), '
    'foreign key(provider_id, query_key) '
    'references subtitle_searches(provider_id, query_key) on delete cascade'
    ')',
  );
  database.execute(
    'create table if not exists subtitle_contents('
    'provider_id text not null, '
    'candidate_reference text not null, '
    'content text not null, '
    'encoding_hint text, '
    'cached_uri text, '
    'cached_at_ms integer not null, '
    'expires_at_ms integer not null, '
    'primary key(provider_id, candidate_reference)'
    ')',
  );
  database.execute(
    'update schema_version set version = max(version, ?) where id = 1',
    <Object?>[sqliteStorageSchemaVersion],
  );
}
