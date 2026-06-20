import 'package:elaina/elaina.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('foundation runtime composes storage gateway and invalidation bus',
      () async {
    final DeterministicStorageFoundation storage =
        DeterministicStorageFoundation();
    final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
    final FoundationRuntime runtime = FoundationRuntime(
      storage: storage,
      invalidationBus: bus,
    );

    expect(runtime.storage, same(storage));
    expect(runtime.gateway, isA<DeterministicProviderGateway>());
    expect(runtime.invalidationBus, same(bus));
    expect(runtime.isDisposed, isFalse);

    await runtime.dispose();
    expect(runtime.isDisposed, isTrue);
  });

  test('foundation runtime rejects access after disposal', () async {
    final DeterministicProviderGateway gateway = DeterministicProviderGateway(
      storage: DeterministicStorageFoundation(),
    );
    final FoundationRuntime runtime = FoundationRuntime(
      storage: DeterministicStorageFoundation(),
      invalidationBus: StreamCacheInvalidationBus(),
      gateway: gateway,
    );
    await runtime.dispose();

    expect(() => runtime.storage, throwsStateError);
    expect(() => runtime.gateway, throwsStateError);
    expect(() => runtime.invalidationBus, throwsStateError);
    expect(
      () => gateway.registerProvider(
        const ProviderRegistration(
          providerId: ProviderId('closed-provider'),
          ratePolicy:
              ProviderRatePolicy(maxRequests: 1, window: Duration(minutes: 1)),
          retryPolicy: ProviderRetryPolicy(
              maxAttempts: 1, initialBackoff: Duration(milliseconds: 1)),
        ),
      ),
      throwsStateError,
    );
  });

  test('layer manifest contains all 8 layers', () {
    final List<LayerBoundary> manifest = FoundationRuntime.layerManifest;

    expect(manifest.length, 8);
    expect(
      manifest.map((LayerBoundary b) => b.id).toSet(),
      equals(LayerId.values.toSet()),
    );
  });

  test('layer boundary checker validates manifest consistency', () {
    final List<String> errors = LayerBoundaryChecker.validateManifest();
    expect(errors, isEmpty);
  });

  test('layer boundary checker rejects forbidden terms', () {
    final List<String> found = LayerBoundaryChecker.findForbiddenTerms(
        'import package:flutter/material.dart');
    expect(found, contains('package:flutter'));
  });

  test('layer boundary checker confirms required terms', () {
    final List<String> missing = LayerBoundaryChecker.findMissingRequiredTerms(
      'FoundationRuntime StorageFoundation ProviderGateway CacheInvalidationBus LayerBoundary elainaLayerManifest',
    );
    expect(missing, isEmpty);
  });

  test('storage foundation exposes all store contracts', () async {
    final DeterministicStorageFoundation storage =
        DeterministicStorageFoundation();

    expect(storage.metadata, isA<DeterministicMetadataStore>());
    expect(storage.blobCache, isA<DeterministicBlobCacheStore>());
    expect(storage.mediaCache, isA<DeterministicMediaCacheStore>());
    expect(storage.settings, isA<DeterministicSettingsStore>());
    expect(storage.mediaLibrary, isA<DeterministicMediaLibraryStore>());
    expect(
        storage.playbackHistory, isA<DeterministicPlaybackHistoryRepository>());
    expect(
        storage.providerBinding, isA<DeterministicProviderBindingRepository>());
    expect(storage.subtitleCache, isA<DeterministicSubtitleCacheStore>());
    expect(storage.rssFeed, isA<DeterministicRssFeedStore>());
    expect(storage.rssAutoDownloadPolicy,
        isA<DeterministicRssAutoDownloadPolicyStore>());
    expect(
        storage.onlineRuleRuntime, isA<DeterministicOnlineRuleRuntimeStore>());
    expect(storage.webViewSessionBackfill,
        isA<DeterministicWebViewSessionBackfillStore>());
    expect(storage.networkPolicy, isA<DeterministicNetworkPolicyStore>());
    expect(storage.diagnostics, isA<DeterministicDiagnosticsStore>());
    expect(storage.seasonalCatalog, isA<DeterministicSeasonalCatalogStore>());
    expect(
        storage.bangumiMatchQueue, isA<DeterministicBangumiMatchQueueStore>());
    expect(storage.btTask, isA<DeterministicBtTaskStore>());
    expect(storage.virtualMediaStream,
        isA<DeterministicVirtualMediaStreamStore>());
    expect(storage.piecePriorityScheduler,
        isA<DeterministicPiecePrioritySchedulerStore>());
    expect(storage.timelineOverlay, isA<DeterministicTimelineOverlayStore>());
    expect(
        storage.videoEnhancement, isA<DeterministicEnhancementProfileStore>());
    expect(storage.avSyncGuard, isA<DeterministicAVSyncGuardStore>());
    expect(storage.advancedCaptions, isA<DeterministicAdvancedCaptionStore>());
    expect(storage.fallbackAdapter, isA<DeterministicFallbackAdapterStore>());
  });

  test('provider gateway registers and executes requests', () async {
    final DeterministicStorageFoundation storage =
        DeterministicStorageFoundation();
    final DeterministicProviderGateway gateway =
        DeterministicProviderGateway(storage: storage);

    await gateway.registerProvider(
      const ProviderRegistration(
        providerId: ProviderId('test-provider'),
        ratePolicy:
            ProviderRatePolicy(maxRequests: 10, window: Duration(minutes: 1)),
        retryPolicy: ProviderRetryPolicy(
            maxAttempts: 3, initialBackoff: Duration(seconds: 1)),
      ),
    );

    final ProviderGatewayResponse<String> response =
        await gateway.execute<String>(
      ProviderGatewayRequest<String>(
        key: ProviderRequestKey(
          providerId: const ProviderId('test-provider'),
          cacheKey: 'test-key',
        ),
        load: () => Future<String>.value('test-value'),
      ),
    );

    expect(response.value, 'test-value');
    expect(response.source, ProviderGatewayResponseSource.network);
  });

  test('provider gateway returns typed failure for unregistered provider',
      () async {
    final DeterministicProviderGateway gateway =
        DeterministicProviderGateway(storage: DeterministicStorageFoundation());

    expect(
      () => gateway.execute<String>(
        ProviderGatewayRequest<String>(
          key: ProviderRequestKey(
            providerId: const ProviderId('unknown'),
            cacheKey: 'key',
          ),
          load: () => Future<String>.value('value'),
        ),
      ),
      throwsA(isA<ProviderFailure>()),
    );
  });

  test('provider gateway deduplicates matching request keys', () async {
    final DeterministicProviderGateway gateway =
        DeterministicProviderGateway(storage: DeterministicStorageFoundation());
    int loadCount = 0;

    await gateway.registerProvider(
      const ProviderRegistration(
        providerId: ProviderId('dedup-provider'),
        ratePolicy:
            ProviderRatePolicy(maxRequests: 10, window: Duration(minutes: 1)),
        retryPolicy: ProviderRetryPolicy(
            maxAttempts: 3, initialBackoff: Duration(seconds: 1)),
      ),
    );

    final ProviderGatewayRequest<int> request = ProviderGatewayRequest<int>(
      key: ProviderRequestKey(
        providerId: const ProviderId('dedup-provider'),
        cacheKey: 'dedup-key',
      ),
      load: () {
        loadCount++;
        return Future<int>.value(42);
      },
      deduplicationWindow: const Duration(minutes: 5),
    );

    final ProviderGatewayResponse<int> first = await gateway.execute(request);
    final ProviderGatewayResponse<int> second = await gateway.execute(request);

    expect(first.value, 42);
    expect(second.value, 42);
    expect(loadCount, 1);
  });

  test('provider gateway evicts dedup entries after the window expires',
      () async {
    DateTime now = DateTime.utc(2026, 6, 18, 12);
    final DeterministicProviderGateway gateway = DeterministicProviderGateway(
      storage: DeterministicStorageFoundation(),
      clock: () => now,
    );
    int loadCount = 0;

    await gateway.registerProvider(
      const ProviderRegistration(
        providerId: ProviderId('dedup-provider'),
        ratePolicy:
            ProviderRatePolicy(maxRequests: 10, window: Duration(minutes: 1)),
        retryPolicy: ProviderRetryPolicy(
            maxAttempts: 3, initialBackoff: Duration(seconds: 1)),
      ),
    );

    ProviderGatewayRequest<int> request() => ProviderGatewayRequest<int>(
          key: ProviderRequestKey(
            providerId: const ProviderId('dedup-provider'),
            cacheKey: 'dedup-key',
          ),
          load: () {
            loadCount++;
            return Future<int>.value(42);
          },
          deduplicationWindow: const Duration(seconds: 30),
        );

    await gateway.execute(request());
    await gateway.execute(request()); // within window -> cached
    expect(loadCount, 1);

    now = now.add(const Duration(seconds: 31)); // window expired
    await gateway.execute(request());
    expect(loadCount, 2);
  });

  test('provider gateway does not dedup when window is zero', () async {
    final DeterministicProviderGateway gateway =
        DeterministicProviderGateway(storage: DeterministicStorageFoundation());
    int loadCount = 0;
    await gateway.registerProvider(
      const ProviderRegistration(
        providerId: ProviderId('no-dedup'),
        ratePolicy:
            ProviderRatePolicy(maxRequests: 10, window: Duration(minutes: 1)),
        retryPolicy: ProviderRetryPolicy(
            maxAttempts: 3, initialBackoff: Duration(seconds: 1)),
      ),
    );
    ProviderGatewayRequest<int> request() => ProviderGatewayRequest<int>(
          key: ProviderRequestKey(
            providerId: const ProviderId('no-dedup'),
            cacheKey: 'k',
          ),
          load: () {
            loadCount++;
            return Future<int>.value(7);
          },
        );
    await gateway.execute(request());
    await gateway.execute(request());
    expect(loadCount, 2);
  });

  test('invalidation bus delivers events and rejects after close', () async {
    final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
    final Future<List<CacheInvalidationEvent>> events =
        bus.events.take(2).toList();

    bus.publish(DanmakuPosted(
      occurredAt: DateTime.utc(2026, 6, 8),
      subjectId: 'subject-1',
      episodeId: 'episode-1',
    ));
    bus.publish(BindingChanged(
      occurredAt: DateTime.utc(2026, 6, 8),
      localMediaId: 'media-1',
    ));

    final List<CacheInvalidationEvent> delivered = await events;
    await bus.close();

    expect(delivered.whereType<DanmakuPosted>().length, 1);
    expect(delivered.whereType<BindingChanged>().length, 1);
    expect(
      () => bus.publish(DanmakuPosted(
        occurredAt: DateTime.utc(2026, 6, 8),
        subjectId: 's',
        episodeId: 'e',
      )),
      throwsStateError,
    );
  });

  test('deterministic metadata store tracks schema version', () async {
    final DeterministicMetadataStore store = DeterministicMetadataStore();

    expect(store.schemaVersion.value, 0);

    await store.migrateToLatest(<SchemaMigration>[
      _TestMigration(from: 0, to: 1),
      _TestMigration(from: 1, to: 3),
    ]);

    expect(store.schemaVersion.value, 3);
  });

  test('deterministic blob cache stores and evicts blobs', () async {
    final DeterministicBlobCacheStore store = DeterministicBlobCacheStore();

    await store.putBlob(
      key: 'test-blob',
      bytes: Stream<List<int>>.value(<int>[1, 2, 3]),
    );

    final Stream<List<int>>? stream = await store.readBlob('test-blob');
    expect(stream, isNotNull);

    final List<int> data = await stream!
        .fold<List<int>>(<int>[], (prev, chunk) => prev..addAll(chunk));
    expect(data, <int>[1, 2, 3]);

    await store.evictBlob('test-blob');
    expect(await store.readBlob('test-blob'), isNull);
  });

  test('deterministic settings store reads and writes', () async {
    final DeterministicSettingsStore store = DeterministicSettingsStore();

    expect(await store.readString('key'), isNull);

    await store.writeString(key: 'key', value: 'value');
    expect(await store.readString('key'), 'value');
  });

  test('deterministic media library store CRUD operations', () async {
    final DeterministicMediaLibraryStore store =
        DeterministicMediaLibraryStore();

    final StoredMediaLibraryItemRecord record = StoredMediaLibraryItemRecord(
      id: 'item-1',
      localMediaId: 'media-1',
      uri: Uri.parse('file:///test.mkv'),
      basename: 'test.mkv',
      addedAt: DateTime.utc(2026, 6, 8),
    );

    await store.store(record);
    expect((await store.findById('item-1'))?.basename, 'test.mkv');
    expect((await store.findByLocalMediaId('media-1'))?.id, 'item-1');
    expect(
        (await store.findByUri(Uri.parse('file:///test.mkv')))?.id, 'item-1');
    expect(await store.count(), 1);

    await store.remove('item-1');
    expect(await store.count(), 0);
  });

  test('deterministic playback history records and continues watching',
      () async {
    final DeterministicPlaybackHistoryRepository store =
        DeterministicPlaybackHistoryRepository();

    await store.record(StoredPlaybackHistoryRecord(
      id: 'hist-1',
      localMediaId: 'media-1',
      position: Duration(minutes: 10),
      duration: Duration(minutes: 24),
      updatedAt: DateTime.utc(2026, 6, 8, 12),
    ));

    final StoredPlaybackHistoryRecord? latest =
        await store.latestFor('media-1');
    expect(latest?.position, const Duration(minutes: 10));

    final List<StoredPlaybackHistoryRecord> watching =
        await store.continueWatching();
    expect(watching.single.id, 'hist-1');
  });

  test('deterministic provider binding repository', () async {
    final DeterministicProviderBindingRepository store =
        DeterministicProviderBindingRepository();

    final StoredProviderBindingRecord binding = StoredProviderBindingRecord(
      id: 'binding-1',
      localMediaId: 'media-1',
      providerId: 'bangumi',
      authority: 'user-confirmed',
      confidence: 1.0,
      createdAt: DateTime.utc(2026, 6, 8),
    );

    await store.saveUserConfirmed(binding);
    expect((await store.bindingFor('media-1'))?.providerId, 'bangumi');
    expect(
      (await store.bindingForProvider(
              localMediaId: 'media-1', providerId: 'bangumi'))
          ?.id,
      'binding-1',
    );
  });

  test('deterministic media cache stores buffered ranges', () async {
    final DeterministicMediaCacheStore store = DeterministicMediaCacheStore();

    await store.recordBufferedRange(
        mediaId: 'media-1', startByte: 0, endByte: 1024);
    await store.recordBufferedRange(
        mediaId: 'media-1', startByte: 1024, endByte: 2048);

    final List<BufferedRange> ranges = await store.bufferedRanges('media-1');
    expect(ranges.length, 2);
    expect(ranges.first.startByte, 0);
    expect(ranges.last.endByte, 2048);
  });
}

final class _TestMigration implements SchemaMigration {
  _TestMigration({required int from, required int to})
      : from = SchemaVersion(from),
        to = SchemaVersion(to);

  @override
  final SchemaVersion from;

  @override
  final SchemaVersion to;

  @override
  Future<void> migrate(MigrationExecutor executor) async {}
}
