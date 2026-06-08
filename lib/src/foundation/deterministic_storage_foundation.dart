import 'storage/storage_contracts.dart';

// ---------------------------------------------------------------------------
// Missing deterministic store implementations (Task 2.2)
// ---------------------------------------------------------------------------

/// Deterministic in-memory [MetadataStore] for Phase 0 bootstrap.
final class DeterministicMetadataStore implements MetadataStore {
  SchemaVersion _version = const SchemaVersion(0);

  @override
  SchemaVersion get schemaVersion => _version;

  @override
  Future<void> migrateToLatest(Iterable<SchemaMigration> migrations) async {
    for (final SchemaMigration migration in migrations) {
      _version = migration.to;
    }
  }
}

/// Deterministic in-memory [BlobCacheStore] for Phase 0 bootstrap.
final class DeterministicBlobCacheStore implements BlobCacheStore {
  final Map<String, List<int>> _blobs = <String, List<int>>{};

  @override
  Future<Uri> putBlob({
    required String key,
    required Stream<List<int>> bytes,
  }) async {
    final List<int> data = await bytes.fold<List<int>>(
      <int>[],
      (List<int> prev, List<int> chunk) => prev..addAll(chunk),
    );
    _blobs[key] = data;
    return Uri.parse('blob://local/');
  }

  @override
  Future<Stream<List<int>>?> readBlob(String key) async {
    final List<int>? data = _blobs[key];
    if (data == null) return null;
    return Stream<List<int>>.value(data);
  }

  @override
  Future<void> evictBlob(String key) async {
    _blobs.remove(key);
  }
}

/// Deterministic in-memory [MediaCacheStore] for Phase 0 bootstrap.
final class DeterministicMediaCacheStore implements MediaCacheStore {
  final Map<String, List<BufferedRange>> _ranges =
      <String, List<BufferedRange>>{};

  @override
  Future<void> recordBufferedRange({
    required String mediaId,
    required int startByte,
    required int endByte,
  }) async {
    _ranges.putIfAbsent(mediaId, () => <BufferedRange>[]).add(
          BufferedRange(startByte: startByte, endByte: endByte),
        );
  }

  @override
  Future<List<BufferedRange>> bufferedRanges(String mediaId) async {
    return _ranges[mediaId] ?? <BufferedRange>[];
  }
}

/// Deterministic in-memory [SettingsStore] for Phase 0 bootstrap.
final class DeterministicSettingsStore implements SettingsStore {
  final Map<String, String> _settings = <String, String>{};

  @override
  Future<String?> readString(String key) async => _settings[key];

  @override
  Future<void> writeString({
    required String key,
    required String value,
  }) async {
    _settings[key] = value;
  }
}

/// Deterministic in-memory [MediaLibraryStore] for Phase 0 bootstrap.
final class DeterministicMediaLibraryStore implements MediaLibraryStore {
  final Map<String, StoredMediaLibraryItemRecord> _itemsById =
      <String, StoredMediaLibraryItemRecord>{};

  @override
  Future<StoredMediaLibraryItemRecord> store(
      StoredMediaLibraryItemRecord record) async {
    _itemsById[record.id] = record;
    return record;
  }

  @override
  Future<StoredMediaLibraryItemRecord?> findById(String id) async =>
      _itemsById[id];

  @override
  Future<StoredMediaLibraryItemRecord?> findByLocalMediaId(
      String localMediaId) async {
    for (final StoredMediaLibraryItemRecord item in _itemsById.values) {
      if (item.localMediaId == localMediaId) return item;
    }
    return null;
  }

  @override
  Future<StoredMediaLibraryItemRecord?> findByUri(Uri uri) async {
    for (final StoredMediaLibraryItemRecord item in _itemsById.values) {
      if (item.uri == uri) return item;
    }
    return null;
  }

  @override
  Future<StoredMediaLibraryItemRecord?> findByFingerprint(
      StoredMediaFileFingerprint fingerprint) async {
    for (final StoredMediaLibraryItemRecord item in _itemsById.values) {
      if (item.fingerprint != null &&
          item.fingerprint!.algorithm == fingerprint.algorithm &&
          item.fingerprint!.value == fingerprint.value) {
        return item;
      }
    }
    return null;
  }

  @override
  Future<List<StoredMediaLibraryItemRecord>> list(
      {int offset = 0, int limit = 50}) async {
    final List<StoredMediaLibraryItemRecord> all = _itemsById.values.toList();
    return all.skip(offset).take(limit).toList();
  }

  @override
  Future<StoredMediaLibraryItemRecord> update(
      StoredMediaLibraryItemRecord record) async {
    _itemsById[record.id] = record;
    return record;
  }

  @override
  Future<bool> remove(String id) async => _itemsById.remove(id) != null;

  @override
  Future<int> count() async => _itemsById.length;
}

/// Deterministic in-memory [PlaybackHistoryRepository] for Phase 0 bootstrap.
final class DeterministicPlaybackHistoryRepository
    implements PlaybackHistoryRepository {
  final Map<String, StoredPlaybackHistoryRecord> _latestByMediaId =
      <String, StoredPlaybackHistoryRecord>{};
  final List<StoredPlaybackHistoryRecord> _allRecords =
      <StoredPlaybackHistoryRecord>[];

  @override
  Future<void> record(StoredPlaybackHistoryRecord record) async {
    _latestByMediaId[record.localMediaId] = record;
    _allRecords.add(record);
  }

  @override
  Future<StoredPlaybackHistoryRecord?> latestFor(
      String localMediaId) async {
    return _latestByMediaId[localMediaId];
  }

  @override
  Future<List<StoredPlaybackHistoryRecord>> continueWatching(
      {int limit = 20}) async {
    final List<StoredPlaybackHistoryRecord> sorted = _allRecords.toList()
      ..sort((StoredPlaybackHistoryRecord a,
              StoredPlaybackHistoryRecord b) =>
          b.updatedAt.compareTo(a.updatedAt));
    return sorted.take(limit).toList();
  }
}

/// Deterministic in-memory [ProviderBindingRepository] for Phase 0 bootstrap.
final class DeterministicProviderBindingRepository
    implements ProviderBindingRepository {
  final Map<String, List<StoredProviderBindingRecord>> _bindingsByMediaId =
      <String, List<StoredProviderBindingRecord>>{};

  @override
  Future<StoredProviderBindingRecord?> bindingFor(
      String localMediaId) async {
    final List<StoredProviderBindingRecord>? bindings =
        _bindingsByMediaId[localMediaId];
    if (bindings == null || bindings.isEmpty) return null;
    return bindings.last;
  }

  @override
  Future<StoredProviderBindingRecord?> bindingForProvider({
    required String localMediaId,
    required String providerId,
  }) async {
    final List<StoredProviderBindingRecord>? bindings =
        _bindingsByMediaId[localMediaId];
    if (bindings == null) return null;
    for (final StoredProviderBindingRecord binding in bindings) {
      if (binding.providerId == providerId) return binding;
    }
    return null;
  }

  @override
  Future<List<StoredProviderBindingRecord>> bindingsFor(
      String localMediaId) async {
    return _bindingsByMediaId[localMediaId] ?? <StoredProviderBindingRecord>[];
  }

  @override
  Future<StoredProviderBindingRecord> saveUserConfirmed(
      StoredProviderBindingRecord binding) async {
    _bindingsByMediaId
        .putIfAbsent(binding.localMediaId,
            () => <StoredProviderBindingRecord>[])
        .add(binding);
    return binding;
  }

  @override
  Future<StoredProviderBindingRecord> saveAutomaticIfAllowed(
      StoredProviderBindingRecord candidate) async {
    return saveUserConfirmed(candidate);
  }
}

// ---------------------------------------------------------------------------
// StorageFoundation composition (Task 2.1)
// ---------------------------------------------------------------------------

/// Deterministic [StorageFoundation] composition for Phase 0 bootstrap.
///
/// Wires all existing local store contracts through a single bootstrap surface
/// without requiring concrete database, blob-cache, filesystem, platform, or
/// migration adapters.  Suitable for tests and early runtime wiring.
///
/// This implementation remains local-first and adapter-free:
/// - No SQLite driver
/// - No remote storage
/// - No cloud sync
/// - No platform filesystem plugin
/// - No telemetry persistence
/// - No mandatory startup migration
final class DeterministicStorageFoundation implements StorageFoundation {
  DeterministicStorageFoundation({
    MetadataStore? metadata,
    BlobCacheStore? blobCache,
    MediaCacheStore? mediaCache,
    SettingsStore? settings,
    MediaLibraryStore? mediaLibrary,
    PlaybackHistoryRepository? playbackHistory,
    ProviderBindingRepository? providerBinding,
    SubtitleCacheStore? subtitleCache,
    RssFeedStore? rssFeed,
    RssAutoDownloadPolicyStore? rssAutoDownloadPolicy,
    OnlineRuleRuntimeStore? onlineRuleRuntime,
    WebViewSessionBackfillStore? webViewSessionBackfill,
    NetworkPolicyStore? networkPolicy,
    DiagnosticsStore? diagnostics,
    SeasonalCatalogStore? seasonalCatalog,
    BangumiMatchQueueStore? bangumiMatchQueue,
    BtTaskStore? btTask,
    VirtualMediaStreamStore? virtualMediaStream,
    PiecePrioritySchedulerStore? piecePriorityScheduler,
    TimelineOverlayStore? timelineOverlay,
    EnhancementProfileStore? videoEnhancement,
    AVSyncGuardStore? avSyncGuard,
    AdvancedCaptionStore? advancedCaptions,
    FallbackAdapterStore? fallbackAdapter,
  })  : _metadata = metadata ?? DeterministicMetadataStore(),
        _blobCache = blobCache ?? DeterministicBlobCacheStore(),
        _mediaCache = mediaCache ?? DeterministicMediaCacheStore(),
        _settings = settings ?? DeterministicSettingsStore(),
        _mediaLibrary = mediaLibrary ?? DeterministicMediaLibraryStore(),
        _playbackHistory =
            playbackHistory ?? DeterministicPlaybackHistoryRepository(),
        _providerBinding =
            providerBinding ?? DeterministicProviderBindingRepository(),
        _subtitleCache = subtitleCache ?? DeterministicSubtitleCacheStore(),
        _rssFeed = rssFeed ?? DeterministicRssFeedStore(),
        _rssAutoDownloadPolicy =
            rssAutoDownloadPolicy ?? DeterministicRssAutoDownloadPolicyStore(),
        _onlineRuleRuntime =
            onlineRuleRuntime ?? DeterministicOnlineRuleRuntimeStore(),
        _webViewSessionBackfill =
            webViewSessionBackfill ?? DeterministicWebViewSessionBackfillStore(),
        _networkPolicy = networkPolicy ?? DeterministicNetworkPolicyStore(),
        _diagnostics = diagnostics ?? DeterministicDiagnosticsStore(),
        _seasonalCatalog = seasonalCatalog ?? DeterministicSeasonalCatalogStore(),
        _bangumiMatchQueue =
            bangumiMatchQueue ?? DeterministicBangumiMatchQueueStore(),
        _btTask = btTask ?? DeterministicBtTaskStore(),
        _virtualMediaStream =
            virtualMediaStream ?? DeterministicVirtualMediaStreamStore(),
        _piecePriorityScheduler =
            piecePriorityScheduler ?? DeterministicPiecePrioritySchedulerStore(),
        _timelineOverlay = timelineOverlay ?? DeterministicTimelineOverlayStore(),
        _videoEnhancement =
            videoEnhancement ?? DeterministicEnhancementProfileStore(),
        _avSyncGuard = avSyncGuard ?? DeterministicAVSyncGuardStore(),
        _advancedCaptions =
            advancedCaptions ?? DeterministicAdvancedCaptionStore(),
        _fallbackAdapter =
            fallbackAdapter ?? DeterministicFallbackAdapterStore();

  final MetadataStore _metadata;
  final BlobCacheStore _blobCache;
  final MediaCacheStore _mediaCache;
  final SettingsStore _settings;
  final MediaLibraryStore _mediaLibrary;
  final PlaybackHistoryRepository _playbackHistory;
  final ProviderBindingRepository _providerBinding;
  final SubtitleCacheStore _subtitleCache;
  final RssFeedStore _rssFeed;
  final RssAutoDownloadPolicyStore _rssAutoDownloadPolicy;
  final OnlineRuleRuntimeStore _onlineRuleRuntime;
  final WebViewSessionBackfillStore _webViewSessionBackfill;
  final NetworkPolicyStore _networkPolicy;
  final DiagnosticsStore _diagnostics;
  final SeasonalCatalogStore _seasonalCatalog;
  final BangumiMatchQueueStore _bangumiMatchQueue;
  final BtTaskStore _btTask;
  final VirtualMediaStreamStore _virtualMediaStream;
  final PiecePrioritySchedulerStore _piecePriorityScheduler;
  final TimelineOverlayStore _timelineOverlay;
  final EnhancementProfileStore _videoEnhancement;
  final AVSyncGuardStore _avSyncGuard;
  final AdvancedCaptionStore _advancedCaptions;
  final FallbackAdapterStore _fallbackAdapter;

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
  RssFeedStore get rssFeed => _rssFeed;

  @override
  RssAutoDownloadPolicyStore get rssAutoDownloadPolicy =>
      _rssAutoDownloadPolicy;

  @override
  OnlineRuleRuntimeStore get onlineRuleRuntime => _onlineRuleRuntime;

  @override
  WebViewSessionBackfillStore get webViewSessionBackfill =>
      _webViewSessionBackfill;

  @override
  NetworkPolicyStore get networkPolicy => _networkPolicy;

  @override
  DiagnosticsStore get diagnostics => _diagnostics;

  @override
  SeasonalCatalogStore get seasonalCatalog => _seasonalCatalog;

  @override
  BangumiMatchQueueStore get bangumiMatchQueue => _bangumiMatchQueue;

  @override
  BtTaskStore get btTask => _btTask;

  @override
  VirtualMediaStreamStore get virtualMediaStream => _virtualMediaStream;

  @override
  PiecePrioritySchedulerStore get piecePriorityScheduler =>
      _piecePriorityScheduler;

  @override
  TimelineOverlayStore get timelineOverlay => _timelineOverlay;

  @override
  EnhancementProfileStore get videoEnhancement => _videoEnhancement;

  @override
  AVSyncGuardStore get avSyncGuard => _avSyncGuard;

  @override
  AdvancedCaptionStore get advancedCaptions => _advancedCaptions;

  @override
  FallbackAdapterStore get fallbackAdapter => _fallbackAdapter;
}


