import 'package:elaina/elaina.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('runtime registers lists removes and snapshots immutable source state',
      () async {
    final RssEngineBootstrap bootstrap = _bootstrap(
      fetcher: _FakeFeedFetcher(
          responses: const <AcgProviderResult<FeedFetchResponse>>[]),
      parser: _FakeFeedParser(items: const <FeedItem>[]),
      scheduler: _FiniteFeedScheduler(),
    );
    final _RuntimeObserver observer = _RuntimeObserver();
    bootstrap.runtime.addObserver(observer);

    final RssEngineActionResult<FeedSource> registered =
        await bootstrap.registerSource(_source());
    final RssEngineActionResult<List<FeedSource>> listed =
        await bootstrap.listSources();
    final List<FeedSource> snapshotSources =
        bootstrap.runtime.currentSnapshot.sources;
    final RssEngineActionResult<bool> removed =
        await bootstrap.removeSource(const FeedSourceId('anime-feed'));
    final RssEngineActionResult<FeedSource> missing =
        await bootstrap.runtime.sourceById(const FeedSourceId('anime-feed'));

    expect(registered.isSuccess, isTrue);
    expect(snapshotSources.single.id.value, 'anime-feed');
    expect(() => snapshotSources.clear(), throwsUnsupportedError);
    expect(listed.value!.single.id.value, 'anime-feed');
    expect(removed.isSuccess, isTrue);
    expect(missing.kind, RssEngineActionResultKind.unavailable);
    expect(
        observer.snapshots
            .map((RssEngineRuntimeSnapshot snapshot) => snapshot.status),
        contains(RssEngineRuntimeStatus.registering));
    await bootstrap.dispose();
  });

  test('runtime projects due sources from registered feed sources only',
      () async {
    final RssEngineBootstrap bootstrap = _bootstrap(
      fetcher: _FakeFeedFetcher(
          responses: const <AcgProviderResult<FeedFetchResponse>>[]),
      parser: _FakeFeedParser(items: const <FeedItem>[]),
      scheduler: _FiniteFeedScheduler(extraDecision: _otherSource()),
    );

    await bootstrap.registerSource(_source());
    final RssEngineActionResult<List<FeedSource>> due =
        await bootstrap.dueSources();

    expect(due.isSuccess, isTrue);
    expect(due.value!.map((FeedSource source) => source.id.value),
        <String>['anime-feed']);
    expect(bootstrap.runtime.currentSnapshot.dueSources.single.id.value,
        'anime-feed');
    await bootstrap.dispose();
  });

  test('runtime snapshots persisted accepted items when registry is listed',
      () async {
    final DeterministicRssFeedStore store = DeterministicRssFeedStore();
    await store.storeSource(_storedSource());
    await store.storeItems(<StoredFeedItemRecord>[
      _storedItem(acceptedAt: DateTime.utc(2026, 6, 11, 12)),
    ]);
    final RssEngineBootstrap bootstrap = _bootstrap(
      store: store,
      fetcher: _FakeFeedFetcher(
          responses: const <AcgProviderResult<FeedFetchResponse>>[]),
      parser: _FakeFeedParser(items: const <FeedItem>[]),
      scheduler: _FiniteFeedScheduler(),
    );

    final RssEngineActionResult<List<FeedSource>> listed =
        await bootstrap.listSources();

    expect(listed.isSuccess, isTrue);
    expect(bootstrap.runtime.currentSnapshot.acceptedItems.single.title,
        'Episode 1');
    await bootstrap.dispose();
  });

  test('runtime stores validates and previews feed-scoped auto-download rules',
      () async {
    final DeterministicRssFeedStore store = DeterministicRssFeedStore();
    final DeterministicRssAutoDownloadPolicyStore policyStore =
        DeterministicRssAutoDownloadPolicyStore();
    await store.storeSource(_storedSource());
    await store.storeItems(<StoredFeedItemRecord>[
      _storedItem(acceptedAt: DateTime.utc(2026, 6, 11, 12)),
    ]);
    final RssEngineRuntime runtime = RssEngineRuntime(
      engine: DeterministicRssEngine(
        store: store,
        fetcher: _FakeFeedFetcher(
            responses: const <AcgProviderResult<FeedFetchResponse>>[]),
        parser: _FakeFeedParser(items: const <FeedItem>[]),
        deduplicator: DeterministicFeedDeduplicator(),
      ),
      store: store,
      scheduler: _FiniteFeedScheduler(),
      policyStore: policyStore,
      clock: () => DateTime.utc(2026, 6, 11, 12),
    );

    await runtime.listSources();
    final RssEngineActionResult<RssAutoDownloadRuleProjection> saved =
        await runtime.saveAutoDownloadRule(
      const RssAutoDownloadRuleDraft(
        sourceId: 'anime-feed',
        label: 'Episode rule',
        titleContains: 'Episode',
      ),
    );
    final RssEngineActionResult<RssAutoDownloadRulePreview> preview =
        await runtime.previewAutoDownloadRule(saved.value!.toDraft());
    final RssEngineActionResult<RssAutoDownloadRuleProjection> invalid =
        await runtime.saveAutoDownloadRule(
      const RssAutoDownloadRuleDraft(
        sourceId: 'anime-feed',
        label: 'Broken regex',
        titleRegex: '[',
      ),
    );

    expect(saved.isSuccess, isTrue);
    expect(saved.value!.sourceId, 'anime-feed');
    expect(preview.value!.matchedCount, 0);
    expect(preview.value!.rejectedCount, 1);
    expect(invalid.kind, RssEngineActionResultKind.failed);
    expect(invalid.failure!.message, contains('标题正则无效'));
    await runtime.dispose();
  });

  test('runtime evaluates enabled rules after refresh and enqueues magnet',
      () async {
    final DeterministicRssFeedStore store = DeterministicRssFeedStore();
    final DeterministicRssAutoDownloadPolicyStore policyStore =
        DeterministicRssAutoDownloadPolicyStore();
    final _RecordingRssDownloadTaskEnqueuer enqueuer =
        _RecordingRssDownloadTaskEnqueuer();
    final FeedItem magnetItem = _item(
      link: Uri.parse('magnet:?xt=urn:btih:episode01'),
    );
    final RssEngineRuntime runtime = RssEngineRuntime(
      engine: DeterministicRssEngine(
        store: store,
        fetcher: _FakeFeedFetcher(
          responses: <AcgProviderResult<FeedFetchResponse>>[
            FeedFetchResponse(
              sourceId: const FeedSourceId('anime-feed'),
              body: '<rss />',
            ).success,
          ],
        ),
        parser: _FakeFeedParser(items: <FeedItem>[magnetItem]),
        deduplicator: DeterministicFeedDeduplicator(),
        clock: () => DateTime.utc(2026, 6, 11, 12),
      ),
      store: store,
      scheduler: _FiniteFeedScheduler(),
      policyStore: policyStore,
      downloadTaskEnqueuer: enqueuer,
      clock: () => DateTime.utc(2026, 6, 11, 12),
    );

    await runtime.registerSource(_source());
    await runtime.setAutoDownloadEnabled('anime-feed', true);
    await runtime.saveAutoDownloadRule(
      const RssAutoDownloadRuleDraft(
        sourceId: 'anime-feed',
        label: 'Episode rule',
        titleContains: 'Episode',
      ),
    );
    final RssEngineActionResult<RssEngineRefreshSnapshot> refreshed =
        await runtime.refreshSource(const FeedSourceId('anime-feed'));

    expect(refreshed.isSuccess, isTrue);
    expect(enqueuer.candidates.single.item.id.value, 'feed-item-1');
    final List<StoredRssAutoDownloadEnqueueOutcomeRecord> outcomes =
        <StoredRssAutoDownloadEnqueueOutcomeRecord>[
      (await policyStore.latestEnqueueOutcome('feed-item-1'))!,
    ];
    expect(outcomes.single.state, StoredRssAutoDownloadEnqueueState.accepted);
    expect(outcomes.single.taskId, 'download-feed-item-1');
    await runtime.dispose();
  });

  test('download enqueuer resolves remote torrent URL before creating task',
      () async {
    final _RecordingDownloadRuntime downloadRuntime =
        _RecordingDownloadRuntime();
    final _FakeTorrentResolver resolver = _FakeTorrentResolver(
      fileUri: Uri.file('D:/cache/episode.torrent'),
    );
    final DownloadRuntimeRssTaskEnqueuer enqueuer =
        DownloadRuntimeRssTaskEnqueuer(
      downloadRuntime: downloadRuntime,
      torrentResolver: resolver,
    );
    final FeedItem torrentItem = _item(
      link: Uri.parse('https://example.test/episode.torrent'),
    );

    final RssAutoDownloadEnqueueResult result = await enqueuer.enqueue(
      RssDownloadCandidate(
        policyId: const RssAutoDownloadPolicyId(defaultRssAutoDownloadPolicyId),
        ruleId: const RssAutoDownloadRuleId('rule-1'),
        item: torrentItem,
        source: TorrentRssDownloadSource(torrentItem.link!),
      ),
    );

    expect(result.isSuccess, isTrue);
    expect(resolver.resolved.single.toString(),
        'https://example.test/episode.torrent');
    expect(downloadRuntime.createdSources.single,
        Uri.file('D:/cache/episode.torrent').toString());
  });

  test(
      'runtime refresh preserves parser warnings cursor dedupe storage and updates',
      () async {
    final DateTime firstRefresh = DateTime.utc(2026, 6, 11, 12);
    final DeterministicRssFeedStore store = DeterministicRssFeedStore();
    final _FakeFeedFetcher fetcher = _FakeFeedFetcher(
      responses: <AcgProviderResult<FeedFetchResponse>>[
        FeedFetchResponse(
          sourceId: const FeedSourceId('anime-feed'),
          body: '<rss />',
          etag: 'etag-v1',
          lastModified: firstRefresh,
        ).success,
        FeedFetchResponse(
          sourceId: const FeedSourceId('anime-feed'),
          body: '<rss />',
          etag: 'etag-v2',
          lastModified: firstRefresh.add(const Duration(minutes: 10)),
        ).success,
      ],
    );
    final RssEngineBootstrap bootstrap = _bootstrap(
      store: store,
      fetcher: fetcher,
      parser: _FakeFeedParser(
          items: <FeedItem>[_item()],
          warnings: const <String>['parser warning']),
      scheduler: _FiniteFeedScheduler(),
      clock: () => firstRefresh,
    );

    await bootstrap.registerSource(_source());
    final Future<List<FeedItem>> updates =
        bootstrap.runtime.updates.take(1).toList();
    final RssEngineActionResult<RssEngineRefreshSnapshot> first =
        await bootstrap.refreshSource(const FeedSourceId('anime-feed'));
    final RssEngineActionResult<RssEngineRefreshSnapshot> second =
        await bootstrap.refreshSource(const FeedSourceId('anime-feed'));
    final List<FeedItem> emitted = await updates;

    expect(first.isSuccess, isTrue);
    expect(first.value!.warnings.single, 'parser warning');
    expect(first.value!.acceptedItems.single.id.value, 'feed-item-1');
    expect(second.value!.acceptedItems, isEmpty);
    expect(emitted.single.id.value, 'feed-item-1');
    expect(
        (await bootstrap.runtime
                .cursorSnapshot(const FeedSourceId('anime-feed')))
            .value!
            .etag,
        'etag-v2');
    expect(
        (await bootstrap.runtime
                .dedupeSnapshot(const FeedSourceId('anime-feed')))
            .value!
            .records
            .single
            .dedupeKey,
        'item-1');
    expect(
        (await bootstrap.runtime
                .acceptedItemsForSource(const FeedSourceId('anime-feed')))
            .value!
            .single
            .title,
        'Episode 1');
    expect(fetcher.requests[1].etag, 'etag-v1');
    expect(
        bootstrap
            .runtime.currentSnapshot.latestRefreshes['anime-feed']?.isSuccess,
        isTrue);
    await bootstrap.dispose();
  });

  test('runtime records not-modified refresh without parsing items', () async {
    final DateTime refreshedAt = DateTime.utc(2026, 6, 11, 13);
    final _FakeFeedParser parser = _FakeFeedParser(items: const <FeedItem>[]);
    final RssEngineBootstrap bootstrap = _bootstrap(
      fetcher: _FakeFeedFetcher(
        responses: <AcgProviderResult<FeedFetchResponse>>[
          FeedFetchResponse(
            sourceId: const FeedSourceId('anime-feed'),
            body: '',
            etag: 'etag-v1',
            lastModified: refreshedAt,
            notModified: true,
          ).success,
        ],
      ),
      parser: parser,
      scheduler: _FiniteFeedScheduler(),
      clock: () => refreshedAt,
    );

    await bootstrap.registerSource(_source());
    final RssEngineActionResult<RssEngineRefreshSnapshot> refreshed =
        await bootstrap.refreshSource(const FeedSourceId('anime-feed'));

    expect(refreshed.isSuccess, isTrue);
    expect(refreshed.value!.acceptedItems, isEmpty);
    expect(parser.requests, isEmpty);
    expect(
      (await bootstrap.runtime.cursorSnapshot(const FeedSourceId('anime-feed')))
          .value!
          .etag,
      'etag-v1',
    );
    await bootstrap.dispose();
  });

  test(
      'runtime normalizes missing source provider parser and disposed outcomes',
      () async {
    final RssEngineBootstrap bootstrap = _bootstrap(
      fetcher: _FakeFeedFetcher(
        responses: const <AcgProviderResult<FeedFetchResponse>>[
          AcgProviderFailure<FeedFetchResponse>(
              kind: AcgProviderFailureKind.retryable,
              message: 'gateway failure'),
        ],
      ),
      parser: _FakeFeedParser(items: const <FeedItem>[]),
      scheduler: _FiniteFeedScheduler(),
    );
    final RssEngineBootstrap mismatch = _bootstrap(
      fetcher: _FakeFeedFetcher(
          responses: const <AcgProviderResult<FeedFetchResponse>>[]),
      parser:
          _FakeFeedParser(items: const <FeedItem>[], format: FeedFormat.atom),
      scheduler: _FiniteFeedScheduler(),
    );

    final RssEngineActionResult<RssEngineRefreshSnapshot> missing =
        await bootstrap.refreshSource(const FeedSourceId('missing'));
    await bootstrap.registerSource(_source());
    final RssEngineActionResult<RssEngineRefreshSnapshot> providerFailure =
        await bootstrap.refreshSource(const FeedSourceId('anime-feed'));
    await mismatch.registerSource(_source());
    final RssEngineActionResult<RssEngineRefreshSnapshot> parserFailure =
        await mismatch.refreshSource(const FeedSourceId('anime-feed'));
    await bootstrap.dispose();
    final RssEngineActionResult<List<FeedSource>> disposed =
        await bootstrap.listSources();

    expect(missing.kind, RssEngineActionResultKind.unavailable);
    expect(providerFailure.kind, RssEngineActionResultKind.failed);
    expect(providerFailure.failure?.kind,
        RssEngineRuntimeFailureKind.providerFailure);
    expect(parserFailure.kind, RssEngineActionResultKind.failed);
    expect(
        parserFailure.failure?.kind, RssEngineRuntimeFailureKind.parserFailure);
    expect(disposed.kind, RssEngineActionResultKind.disposed);
    await mismatch.dispose();
  });

  test('runtime suppresses persisted dedupe keys after restart-like conditions',
      () async {
    final DateTime refreshedAt = DateTime.utc(2026, 6, 11, 14);
    final DeterministicRssFeedStore store = DeterministicRssFeedStore();
    await store.storeSource(_storedSource());
    await store.recordDedupeKey(StoredFeedDedupeKeyRecord(
        sourceId: 'anime-feed', dedupeKey: 'item-1', acceptedAt: refreshedAt));
    final RssEngineBootstrap bootstrap = _bootstrap(
      store: store,
      fetcher: _FakeFeedFetcher(
        responses: <AcgProviderResult<FeedFetchResponse>>[
          FeedFetchResponse(
                  sourceId: const FeedSourceId('anime-feed'), body: '<rss />')
              .success,
        ],
      ),
      parser: _FakeFeedParser(items: <FeedItem>[_item()]),
      scheduler: _FiniteFeedScheduler(),
      clock: () => refreshedAt,
    );

    final RssEngineActionResult<RssEngineRefreshSnapshot> refreshed =
        await bootstrap.refreshSource(const FeedSourceId('anime-feed'));

    expect(refreshed.isSuccess, isTrue);
    expect(refreshed.value!.acceptedItems, isEmpty);
    expect((await store.itemsForSource('anime-feed')), isEmpty);
    expect(
        (await bootstrap.runtime
                .dedupeSnapshot(const FeedSourceId('anime-feed')))
            .value!
            .records
            .single
            .dedupeKey,
        'item-1');
    await bootstrap.dispose();
  });
}

extension on FeedFetchResponse {
  AcgProviderSuccess<FeedFetchResponse> get success =>
      AcgProviderSuccess<FeedFetchResponse>(this);
}

RssEngineBootstrap _bootstrap({
  DeterministicRssFeedStore? store,
  required FeedFetcher fetcher,
  required FeedParser parser,
  required FeedScheduler scheduler,
  DateTime Function()? clock,
}) {
  return RssEngineBootstrap(
    store: store ?? DeterministicRssFeedStore(),
    fetcher: fetcher,
    parser: parser,
    scheduler: scheduler,
    clock: clock ?? () => DateTime.utc(2026, 6, 11, 12),
  );
}

FeedSource _source() {
  return FeedSource(
    id: const FeedSourceId('anime-feed'),
    displayName: 'Anime Feed',
    uri: Uri.parse('https://example.test/rss.xml'),
    format: FeedFormat.rss,
    refreshInterval: const Duration(hours: 1),
  );
}

FeedSource _otherSource() {
  return FeedSource(
    id: const FeedSourceId('other-feed'),
    displayName: 'Other Feed',
    uri: Uri.parse('https://example.test/other.xml'),
    format: FeedFormat.rss,
    refreshInterval: const Duration(hours: 1),
  );
}

StoredFeedSourceRecord _storedSource() {
  final FeedSource source = _source();
  return StoredFeedSourceRecord(
    id: source.id.value,
    displayName: source.displayName,
    uri: source.uri,
    format: source.format.name,
    refreshInterval: source.refreshInterval,
    defaultHeaders: source.defaultHeaders,
  );
}

StoredFeedItemRecord _storedItem({required DateTime acceptedAt}) {
  final FeedItem item = _item();
  return StoredFeedItemRecord(
    id: item.id.value,
    sourceId: item.sourceId.value,
    dedupeKey: item.dedupeKey.value,
    title: item.title,
    link: item.link,
    publishedAt: item.publishedAt,
    summary: item.summary,
    categories: item.categories,
    acceptedAt: acceptedAt,
  );
}

FeedItem _item({Uri? link}) {
  return FeedItem(
    id: const FeedItemId('feed-item-1'),
    sourceId: const FeedSourceId('anime-feed'),
    dedupeKey: const FeedDedupeKey('item-1'),
    title: 'Episode 1',
    link: link ?? Uri.parse('https://example.test/episode-1'),
    publishedAt: DateTime.utc(2026, 6, 11, 11),
    summary: 'A new episode.',
    categories: const <String>['anime'],
  );
}

final class _RuntimeObserver implements RssEngineRuntimeObserver {
  final List<RssEngineRuntimeSnapshot> snapshots = <RssEngineRuntimeSnapshot>[];

  @override
  void onRssEngineRuntimeSnapshot(RssEngineRuntimeSnapshot snapshot) {
    snapshots.add(snapshot);
  }
}

final class _FiniteFeedScheduler implements FeedScheduler {
  _FiniteFeedScheduler({this.extraDecision});

  final FeedSource? extraDecision;

  @override
  Stream<FeedScheduleDecision> dueSources(Iterable<FeedSource> sources) async* {
    for (final FeedSource source in sources) {
      yield FeedScheduleDecision(
          source: source, dueAt: DateTime.utc(2026, 6, 11, 12));
    }
    final FeedSource? extra = extraDecision;
    if (extra != null)
      yield FeedScheduleDecision(
          source: extra, dueAt: DateTime.utc(2026, 6, 11, 12));
  }
}

final class _FakeFeedParser implements FeedParser {
  _FakeFeedParser(
      {required this.items,
      this.warnings = const <String>[],
      this.format = FeedFormat.rss});

  final List<FeedItem> items;
  final List<String> warnings;
  final List<FeedParseRequest> requests = <FeedParseRequest>[];

  @override
  final FeedFormat format;

  @override
  Future<FeedParseResult> parse(FeedParseRequest request) {
    requests.add(request);
    return Future<FeedParseResult>.value(FeedParseResult(
        sourceId: request.source.id, items: items, warnings: warnings));
  }
}

final class _FakeFeedFetcher implements FeedFetcher {
  _FakeFeedFetcher({required this.responses});

  final List<AcgProviderResult<FeedFetchResponse>> responses;
  final List<FeedFetchRequest> requests = <FeedFetchRequest>[];
  int _index = 0;

  @override
  String get displayName => 'Fake Feed Fetcher';

  @override
  ProviderGateway get gateway => _UnsupportedProviderGateway();

  @override
  String get id => 'fake-feed-fetcher';

  @override
  ProviderKind get kind => ProviderKind.rss;

  @override
  ProviderRegistration get registration => rssProviderRegistration(
      sourceId: const FeedSourceId('fake-feed-fetcher'));

  @override
  Future<ProviderGatewayResponse<T>> executeGatewayRequest<T>({
    required String cacheKey,
    required Future<T> Function() load,
    ProviderCachePolicy cachePolicy = ProviderCachePolicy.networkOnly,
  }) async {
    return ProviderGatewayResponse<T>(
        value: await load(), source: ProviderGatewayResponseSource.network);
  }

  @override
  Future<AcgProviderResult<FeedFetchResponse>> fetchFeed(
      FeedFetchRequest request) {
    requests.add(request);
    final AcgProviderResult<FeedFetchResponse> response =
        responses[_index < responses.length ? _index : responses.length - 1];
    _index += 1;
    return Future<AcgProviderResult<FeedFetchResponse>>.value(response);
  }

  @override
  ProviderRequestKey requestKey(String cacheKey) {
    return ProviderRequestKey(
        providerId: const ProviderId('fake-feed-fetcher'), cacheKey: cacheKey);
  }
}

final class _RecordingRssDownloadTaskEnqueuer
    implements RssDownloadTaskEnqueuer {
  final List<RssDownloadCandidate> candidates = <RssDownloadCandidate>[];

  @override
  Future<RssAutoDownloadEnqueueResult> enqueue(
      RssDownloadCandidate candidate) async {
    candidates.add(candidate);
    return RssAutoDownloadEnqueueResult(
      candidate: candidate,
      state: StoredRssAutoDownloadEnqueueState.accepted,
      message: 'accepted',
      taskId: 'download-${candidate.item.id.value}',
    );
  }
}

final class _FakeTorrentResolver implements RssTorrentUrlResolver {
  _FakeTorrentResolver({required this.fileUri});

  final Uri fileUri;
  final List<Uri> resolved = <Uri>[];

  @override
  Future<RssTorrentUrlResolution> resolve(Uri torrentUri) async {
    resolved.add(torrentUri);
    return RssTorrentUrlResolution.success(fileUri);
  }
}

final class _RecordingDownloadRuntime implements DownloadRuntime {
  final List<String> createdSources = <String>[];

  @override
  DownloadRuntimeSnapshot get currentSnapshot => DownloadRuntimeSnapshot(
        status: DownloadRuntimeStatus.ready,
        tasks: const <DownloadProjection>[],
        capabilities: const DownloadCapabilityProjection(
          taskManagementAvailable: true,
          metadataFetchingAvailable: true,
          backgroundDownloadAvailable: true,
          virtualStreamAvailable: true,
        ),
      );

  @override
  void addObserver(DownloadRuntimeObserver observer) {}

  @override
  Future<DownloadCreateResult> createTaskFromUri(
    String sourceUri, {
    DownloadCreateMode mode = DownloadCreateMode.quick,
  }) async {
    createdSources.add(sourceUri);
    return DownloadCreateResult.success(
      DownloadProjection(
        taskId: const DownloadTaskId('task-1'),
        sourceUri: sourceUri,
        state: DownloadLifecycleState.queued,
        name: 'Episode',
        progress: 0,
        downloadRateBytesPerSecond: 0,
        connectedPeers: 0,
        totalSizeBytes: 0,
      ),
    );
  }

  @override
  void dispose() {}

  @override
  Future<void> listTasks() async {}

  @override
  Future<DownloadCommandResult> pause(DownloadTaskId taskId) async =>
      const DownloadCommandResult.success();

  @override
  Future<DownloadCommandResult> pauseAll() async =>
      const DownloadCommandResult.success();

  @override
  Future<DownloadCommandResult> remove(DownloadTaskId taskId) async =>
      const DownloadCommandResult.success();

  @override
  void removeObserver(DownloadRuntimeObserver observer) {}

  @override
  Future<DownloadCommandResult> resume(DownloadTaskId taskId) async =>
      const DownloadCommandResult.success();

  @override
  Future<DownloadCommandResult> resumeAll() async =>
      const DownloadCommandResult.success();

  @override
  Future<DownloadCommandResult> selectFiles(
    DownloadTaskId taskId,
    Iterable<DownloadFileIndex> files,
  ) async =>
      const DownloadCommandResult.success();
}

final class _UnsupportedProviderGateway implements ProviderGateway {
  @override
  StorageFoundation get storage =>
      throw StateError('Storage is not used by this test gateway.');

  @override
  Future<ProviderGatewayResponse<T>> execute<T>(
      ProviderGatewayRequest<T> request) async {
    return ProviderGatewayResponse<T>(
        value: await request.load(),
        source: ProviderGatewayResponseSource.network);
  }

  @override
  Future<void> registerProvider(ProviderRegistration registration) =>
      Future<void>.value();
}
