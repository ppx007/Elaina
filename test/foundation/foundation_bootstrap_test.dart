import "package:elaina/elaina.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  test("FoundationBootstrap composes storage gateway and invalidation bus",
      () async {
    final FoundationBootstrap bootstrap = FoundationBootstrap();

    // Storage foundation is accessible with all 24 stores.
    expect(bootstrap.storage, isA<StorageFoundation>());
    expect(bootstrap.storage.metadata, isA<MetadataStore>());
    expect(bootstrap.storage.blobCache, isA<BlobCacheStore>());
    expect(bootstrap.storage.mediaCache, isA<MediaCacheStore>());
    expect(bootstrap.storage.settings, isA<SettingsStore>());
    expect(bootstrap.storage.mediaLibrary, isA<MediaLibraryStore>());
    expect(bootstrap.storage.playbackHistory, isA<PlaybackHistoryRepository>());
    expect(bootstrap.storage.providerBinding, isA<ProviderBindingRepository>());
    expect(bootstrap.storage.subtitleCache, isA<SubtitleCacheStore>());
    expect(bootstrap.storage.rssFeed, isA<RssFeedStore>());
    expect(bootstrap.storage.rssAutoDownloadPolicy,
        isA<RssAutoDownloadPolicyStore>());
    expect(bootstrap.storage.onlineRuleRuntime, isA<OnlineRuleRuntimeStore>());
    expect(bootstrap.storage.webViewSessionBackfill,
        isA<WebViewSessionBackfillStore>());
    expect(bootstrap.storage.networkPolicy, isA<NetworkPolicyStore>());
    expect(bootstrap.storage.diagnostics, isA<DiagnosticsStore>());
    expect(bootstrap.storage.seasonalCatalog, isA<SeasonalCatalogStore>());
    expect(bootstrap.storage.bangumiMatchQueue, isA<BangumiMatchQueueStore>());
    expect(bootstrap.storage.btTask, isA<BtTaskStore>());
    expect(
        bootstrap.storage.virtualMediaStream, isA<VirtualMediaStreamStore>());
    expect(bootstrap.storage.piecePriorityScheduler,
        isA<PiecePrioritySchedulerStore>());
    expect(bootstrap.storage.timelineOverlay, isA<TimelineOverlayStore>());
    expect(bootstrap.storage.videoEnhancement, isA<EnhancementProfileStore>());
    expect(bootstrap.storage.avSyncGuard, isA<AVSyncGuardStore>());
    expect(bootstrap.storage.advancedCaptions, isA<AdvancedCaptionStore>());
    expect(bootstrap.storage.fallbackAdapter, isA<FallbackAdapterStore>());

    // Cache invalidation bus is accessible and lifecycle-managed.
    expect(bootstrap.invalidationBus, isA<CacheInvalidationBus>());
    expect(bootstrap.isDisposed, isFalse);

    // Provider gateway is accessible.
    expect(bootstrap.gateway, isA<ProviderGateway>());

    await bootstrap.dispose();
    expect(bootstrap.isDisposed, isTrue);
  });

  test("FoundationBootstrap disposal rejects further invalidation publishes",
      () async {
    final FoundationBootstrap bootstrap = FoundationBootstrap();
    final StreamCacheInvalidationBus bus =
        bootstrap.invalidationBus as StreamCacheInvalidationBus;

    await bootstrap.dispose();

    expect(
      () => bus.publish(DanmakuPosted(
        occurredAt: DateTime.utc(2026, 6, 8, 12),
        subjectId: "test",
        episodeId: "test",
      )),
      throwsStateError,
    );
  });

  test("FoundationBootstrap disposal rejects storage and gateway access",
      () async {
    final FoundationBootstrap bootstrap = FoundationBootstrap();
    await bootstrap.dispose();

    expect(() => bootstrap.storage, throwsStateError);
    expect(() => bootstrap.gateway, throwsStateError);
    expect(() => bootstrap.invalidationBus, throwsStateError);
  });

  test("DeterministicStorageFoundation provides all store accessors", () async {
    final DeterministicStorageFoundation storage =
        DeterministicStorageFoundation();

    // Metadata store: deterministic version and migration.
    expect(storage.metadata.schemaVersion.value, 0);

    // Settings store: write and read.
    await storage.settings.writeString(key: "theme", value: "dark");
    expect(await storage.settings.readString("theme"), "dark");
    expect(await storage.settings.readString("missing"), isNull);

    // Blob cache store: put, read, evict.
    final Uri blobUri = await storage.blobCache.putBlob(
      key: "test-blob",
      bytes: Stream<List<int>>.fromIterable(<List<int>>[
        <int>[1, 2, 3],
      ]),
    );
    expect(blobUri.toString(), isNotEmpty);
    final Stream<List<int>>? readStream =
        await storage.blobCache.readBlob("test-blob");
    expect(readStream, isNotNull);
    await storage.blobCache.evictBlob("test-blob");
    expect(await storage.blobCache.readBlob("test-blob"), isNull);

    // Media cache store: record and query.
    await storage.mediaCache.recordBufferedRange(
      mediaId: "media-1",
      startByte: 0,
      endByte: 1023,
    );
    final List<BufferedRange> ranges =
        await storage.mediaCache.bufferedRanges("media-1");
    expect(ranges.single.startByte, 0);
    expect(ranges.single.endByte, 1023);

    // Media library store: store and find.
    await storage.mediaLibrary.store(StoredMediaLibraryItemRecord(
      id: "lib-1",
      localMediaId: "media-1",
      uri: Uri.file("D:/media/test.mkv"),
      basename: "test.mkv",
      addedAt: DateTime.utc(2026, 6, 8, 12),
    ));
    expect(
        (await storage.mediaLibrary.findById("lib-1"))?.basename, "test.mkv");
    expect((await storage.mediaLibrary.findByLocalMediaId("media-1"))?.id,
        "lib-1");
    expect(await storage.mediaLibrary.count(), 1);

    // Playback history repository.
    await storage.playbackHistory.record(StoredPlaybackHistoryRecord(
      id: "history-1",
      localMediaId: "media-1",
      position: const Duration(minutes: 5),
      duration: const Duration(minutes: 10),
      updatedAt: DateTime.utc(2026, 6, 8, 12),
    ));
    expect(
      (await storage.playbackHistory.latestFor("media-1"))?.position,
      const Duration(minutes: 5),
    );

    // Provider binding repository.
    await storage.providerBinding.saveUserConfirmed(StoredProviderBindingRecord(
      id: "binding-1",
      localMediaId: "media-1",
      providerId: "bangumi",
      authority: "userConfirmed",
      confidence: 1.0,
      createdAt: DateTime.utc(2026, 6, 8, 12),
      providerSubjectId: "subject-1",
    ));
    expect(
      (await storage.providerBinding.bindingFor("media-1"))?.providerId,
      "bangumi",
    );
  });

  test(
      "DeterministicProviderGateway preserves registrations request keys and typed failures",
      () async {
    final DeterministicStorageFoundation storage =
        DeterministicStorageFoundation();
    final DeterministicProviderGateway gateway =
        DeterministicProviderGateway(storage: storage);

    expect(gateway.storage, same(storage));

    // Register a provider.
    await gateway.registerProvider(ProviderRegistration(
      providerId: const ProviderId("test-provider"),
      ratePolicy: const ProviderRatePolicy(
          maxRequests: 10, window: Duration(minutes: 1)),
      retryPolicy: const ProviderRetryPolicy(
          maxAttempts: 3, initialBackoff: Duration(seconds: 1)),
    ));

    // Execute a request with supplied loader.
    final ProviderGatewayResponse<String> response =
        await gateway.execute<String>(ProviderGatewayRequest<String>(
      key: ProviderRequestKey(
        providerId: const ProviderId("test-provider"),
        cacheKey: "test-provider::search",
      ),
      load: () => Future<String>.value("test-result"),
      cachePolicy: ProviderCachePolicy.networkFirst,
      deduplicationWindow: const Duration(minutes: 1),
    ));
    expect(response.value, "test-result");
    expect(response.source, ProviderGatewayResponseSource.network);

    // De-duplication: same key with dedup window returns cached outcome.
    final ProviderGatewayResponse<String> deduped =
        await gateway.execute<String>(ProviderGatewayRequest<String>(
      key: ProviderRequestKey(
        providerId: const ProviderId("test-provider"),
        cacheKey: "test-provider::search",
      ),
      load: () => Future<String>.value("different-result"),
      deduplicationWindow: const Duration(minutes: 1),
    ));
    expect(deduped.value, "test-result");

    // Unregistered provider returns terminal failure.
    try {
      await gateway.execute<String>(ProviderGatewayRequest<String>(
        key: ProviderRequestKey(
          providerId: const ProviderId("unknown-provider"),
          cacheKey: "unknown::key",
        ),
        load: () => Future<String>.value("never"),
      ));
      fail("Expected ProviderFailure for unregistered provider.");
    } on ProviderFailure catch (e) {
      expect(e.kind, ProviderFailureKind.terminal);
    }
  });

  test("CacheInvalidationBus publishes and rejects after close", () async {
    final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
    final DateTime observedAt = DateTime.utc(2026, 6, 8, 12);

    final Future<List<CacheInvalidationEvent>> events =
        bus.events.take(2).toList();

    bus.publish(BindingChanged(
      occurredAt: observedAt,
      localMediaId: "media-1",
      providerId: "bangumi",
    ));
    bus.publish(HistoryRecorded(
      occurredAt: observedAt,
      localMediaId: "media-1",
    ));

    final List<CacheInvalidationEvent> delivered = await events;
    await bus.close();

    expect(delivered.whereType<BindingChanged>().length, 1);
    expect(delivered.whereType<HistoryRecorded>().length, 1);

    expect(
      () => bus.publish(DanmakuPosted(
        occurredAt: observedAt,
        subjectId: "test",
        episodeId: "test",
      )),
      throwsStateError,
    );
  });

  test("CacheInvalidationBus remains payload-only", () async {
    final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
    final DateTime observedAt = DateTime.utc(2026, 6, 8, 12);

    final Future<List<CacheInvalidationEvent>> events =
        bus.events.take(1).toList();

    bus.publish(MediaLibraryItemChanged(
      occurredAt: observedAt,
      mediaLibraryItemId: "lib-1",
      localMediaId: "media-1",
      changeKind: MediaLibraryChangeKind.created,
    ));

    final List<CacheInvalidationEvent> delivered = await events;
    await bus.close();

    expect(delivered.single, isA<MediaLibraryItemChanged>());
    final MediaLibraryItemChanged event =
        delivered.single as MediaLibraryItemChanged;
    expect(event.mediaLibraryItemId, "lib-1");
    expect(event.changeKind, MediaLibraryChangeKind.created);
  });

  test("Layer manifest exposes 8-layer boundary metadata", () {
    expect(FoundationBootstrap.layerManifest.length, 8);

    final LayerId uiId = FoundationBootstrap.layerManifest
        .firstWhere((LayerBoundary b) => b.id == LayerId.ui)
        .id;
    expect(uiId, LayerId.ui);

    expect(
      isLayerDependencyAllowed(from: LayerId.ui, to: LayerId.domain),
      isTrue,
    );
    expect(
      isLayerDependencyAllowed(from: LayerId.ui, to: LayerId.playback),
      isFalse,
    );
    expect(
      isLayerDependencyAllowed(from: LayerId.gateway, to: LayerId.storage),
      isTrue,
    );
    expect(
      isLayerDependencyAllowed(from: LayerId.storage, to: LayerId.ui),
      isFalse,
    );
  });

  test("Foundation bootstrap forbidden dependencies list is non-empty", () {
    expect(FoundationBootstrap.forbiddenDependencies.isNotEmpty, isTrue);
    expect(
        FoundationBootstrap.forbiddenDependencies.contains("package:flutter"),
        isTrue);
    expect(FoundationBootstrap.forbiddenDependencies.contains("mpv"), isTrue);
    expect(FoundationBootstrap.forbiddenDependencies.contains("dart:mirrors"),
        isTrue);
    expect(FoundationBootstrap.forbiddenDependencies.contains("eval("), isTrue);
  });

  test("Foundation bootstrap required terms are declared", () {
    expect(FoundationBootstrap.requiredTerms.isNotEmpty, isTrue);
    expect(FoundationBootstrap.requiredTerms.contains("FoundationRuntime"),
        isTrue);
    expect(FoundationBootstrap.requiredTerms.contains("StorageFoundation"),
        isTrue);
    expect(
        FoundationBootstrap.requiredTerms.contains("ProviderGateway"), isTrue);
    expect(FoundationBootstrap.requiredTerms.contains("CacheInvalidationBus"),
        isTrue);
  });

  test("LayerBoundaryChecker validates forbidden and required terms", () {
    expect(
      LayerBoundaryChecker.findForbiddenTerms(
          "import package:flutter/material.dart"),
      contains("package:flutter"),
    );
    expect(
      LayerBoundaryChecker.findForbiddenTerms("clean code here"),
      isEmpty,
    );
    expect(
      LayerBoundaryChecker.findMissingRequiredTerms(
          "FoundationRuntime StorageFoundation ProviderGateway CacheInvalidationBus "
          "LayerBoundary elainaLayerManifest"),
      isEmpty,
    );
    expect(
      LayerBoundaryChecker.findMissingRequiredTerms("missing everything"),
      isNotEmpty,
    );
  });

  test("LayerBoundaryChecker manifest validation passes", () {
    final List<String> errors = LayerBoundaryChecker.validateManifest();
    expect(errors, isEmpty);
  });

  test("FoundationBootstrap.withDependencies accepts explicit stores",
      () async {
    final DeterministicStorageFoundation storage =
        DeterministicStorageFoundation();
    final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
    final DeterministicProviderGateway gateway =
        DeterministicProviderGateway(storage: storage);

    final FoundationBootstrap bootstrap = FoundationBootstrap.withDependencies(
      storage: storage,
      invalidationBus: bus,
      gateway: gateway,
    );

    expect(bootstrap.storage, same(storage));
    expect(bootstrap.invalidationBus, same(bus));
    expect(bootstrap.gateway, same(gateway));
    expect(bootstrap.isDisposed, isFalse);

    await bootstrap.dispose();
    expect(bootstrap.isDisposed, isTrue);
  });
}
