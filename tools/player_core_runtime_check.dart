import 'dart:async';

import '../lib/celesteria.dart';

Future<void> main() async {
  await _verifyUnsupportedMpvFacade();
  await _verifyBoundMpvFacadeDelegation();
  await _verifySourceCapabilityGating();
  await _verifyPlaybackSourceHandoff();
  await _verifyLocalMediaScannerContract();
  await _verifyMediaLibraryPersistenceContract();
  await _verifySubtitleProviderCacheContract();
  await _verifyRssEngineContract();
  await _verifyRssAutoDownloadPolicyContract();
  await _verifyOnlineRuleRuntimeContract();
  await _verifyWebViewSessionBackfillContract();
  await _verifyNetworkPolicyContract();
  await _verifyDiagnosticsCenterContract();
  await _verifySeasonalIndexerContract();
  await _verifyBtTaskCoreContract();
  await _verifyVirtualMediaStreamContract();
  await _verifyPiecePrioritySchedulerContract();
  await _verifyTimelineOverlayContract();
  await _verifyVideoEnhancementPipelineContract();
  await _verifyAVSyncGuardContract();
  await _verifyAdvancedCaptionRenderingContract();
  await _verifyFallbackAdapterContract();
  await _verifyFoundationBootstrapContract();
  _verifySurfaceStateFromCapabilities();
  _verifyPlaybackPageSurfaceContract();
  await _verifyPlaybackPageIntentContract();
  _verifyPlaybackStateContract();
  _verifyUndeclaredCapabilitiesRemainUnsupported();
  await _verifyTrackRuntimeChecks();
  await _verifyPlayerCoreRuntimeContract();
  await _verifyFoundationRuntimeContract();
}

Future<void> _verifyUnsupportedMpvFacade() async {
  const MpvPlayerAdapterFacade adapter = MpvPlayerAdapterFacade.unsupported();

  _expect(!adapter.capabilities.supports(PlaybackCapability.localFilePlayback),
      'Unsupported MPV facade must not support local playback.');
  _expectFailureKind(await adapter.load(_localSource()),
      PlaybackFailureKind.adapterUnavailable);
  _expectFailureKind(
      await adapter.play(), PlaybackFailureKind.adapterUnavailable);
  _expectFailureKind(
      await adapter.pause(), PlaybackFailureKind.adapterUnavailable);
  _expectFailureKind(await adapter.seek(const Duration(seconds: 10)),
      PlaybackFailureKind.adapterUnavailable);
  _expectFailureKind(
      await adapter.stop(), PlaybackFailureKind.adapterUnavailable);
  _expectFailureKind(
      await adapter.dispose(), PlaybackFailureKind.adapterUnavailable);

  final TrackDiscoveryResult discovery = await adapter.discoverTracks();
  _expect(discovery.tracks.isEmpty,
      'Unsupported MPV facade must not report concrete tracks.');
  _expect(
      !discovery.capabilityMatrix
          .supports(PlaybackCapability.audioTrackDiscovery),
      'Unsupported track discovery must return unsupported capabilities.');

  final TrackSwitchResult switchResult =
      await adapter.switchTrack(const MediaTrackId('audio-main'));
  _expect(!switchResult.isSuccess,
      'Unsupported MPV facade must reject track switching.');
}

Future<void> _verifyBoundMpvFacadeDelegation() async {
  final _InMemoryMpvBinding binding = _InMemoryMpvBinding(
    tracks: _tracks,
  );
  final PlaybackController controller = PlaybackController(
    adapterResolver:
        _StaticAdapterResolver(MpvPlayerAdapterFacade.bound(binding: binding)),
  );

  _expectSuccess(await controller.open(_localSource()));
  _expectSuccess(await controller.play());
  _expectSuccess(await controller.pause());
  _expectSuccess(await controller.seek(const Duration(seconds: 24)));
  _expectSuccess(await controller.stop());

  _expect(binding.loadedSource is LocalFilePlaybackSource,
      'Bound facade must delegate load to the binding.');
  _expect(binding.operations.contains(PlaybackOperation.play),
      'Bound facade must delegate play to the binding.');
  _expect(binding.operations.contains(PlaybackOperation.pause),
      'Bound facade must delegate pause to the binding.');
  _expect(binding.operations.contains(PlaybackOperation.seek),
      'Bound facade must delegate seek to the binding.');
  _expect(binding.operations.contains(PlaybackOperation.stop),
      'Bound facade must delegate stop to the binding.');

  final _InMemoryMpvBinding localOnlyBinding =
      _InMemoryMpvBinding(tracks: _tracks);
  final MpvPlayerAdapterFacade localOnlyFacade = MpvPlayerAdapterFacade.bound(
    binding: localOnlyBinding,
    capabilities: PlaybackCapabilityMatrix(
      capabilities: <PlaybackCapability, CapabilityStatus>{
        PlaybackCapability.localFilePlayback: CapabilityStatus.supported(),
      },
    ),
  );
  final PlaybackCommandResult gatedResult = await localOnlyFacade.load(
    HlsPlaybackSource(uri: Uri.parse('https://example.test/playlist.m3u8')),
  );
  _expectFailureKind(gatedResult, PlaybackFailureKind.unsupported);
  _expect(localOnlyBinding.loadedSource == null,
      'MPV facade must gate unsupported sources before binding delegation.');
}

Future<void> _verifySourceCapabilityGating() async {
  final _ConfigurablePlayerAdapter adapter = _ConfigurablePlayerAdapter(
    capabilities: PlaybackCapabilityMatrix(
      capabilities: <PlaybackCapability, CapabilityStatus>{
        PlaybackCapability.localFilePlayback: CapabilityStatus.supported(),
        PlaybackCapability.playPause: CapabilityStatus.supported(),
      },
    ),
  );
  final PlaybackController controller =
      PlaybackController(adapterResolver: _StaticAdapterResolver(adapter));

  _expectSuccess(await controller.open(_localSource()));
  _expect(adapter.loadCount == 1, 'Supported source load must delegate once.');

  final PlaybackCommandResult result = await controller.open(
      HlsPlaybackSource(uri: Uri.parse('https://example.test/playlist.m3u8')));
  _expectFailureKind(result, PlaybackFailureKind.unsupported);
  _expect(adapter.loadCount == 1,
      'Unsupported source load must not delegate to adapter.');
}

Future<void> _verifyPlaybackSourceHandoff() async {
  const LocalPlaybackSourceHandoff handoff = LocalPlaybackSourceHandoff();
  final LocalMediaIdentity identity = LocalMediaIdentity(
    id: const LocalMediaId('runtime-local-media'),
    uri: Uri.file('D:/media/handoff.mkv'),
    basename: 'handoff.mkv',
  );

  final PlaybackSourceHandoffResult prepared = handoff.prepare(
    PlaybackSourceHandoffInput.localMediaIdentity(identity),
  );
  _expect(
      prepared.isSuccess, 'Local file handoff must prepare a playback source.');
  _expect(prepared.source is LocalFilePlaybackSource,
      'Local file handoff must reuse LocalFilePlaybackSource.');

  final PlaybackSourceHandoffResult unsupported = handoff.prepare(
    PlaybackSourceHandoffInput.localMediaIdentity(
      LocalMediaIdentity(
        id: const LocalMediaId('remote-local-media'),
        uri: Uri.parse('https://example.test/media.mkv'),
        basename: 'media.mkv',
      ),
    ),
  );
  _expect(!unsupported.isSuccess,
      'Unsupported source handoff must return a failure result.');
  _expect(
    unsupported.failure?.kind ==
        PlaybackSourceHandoffFailureKind.unsupportedScheme,
    'Unsupported source handoff must report unsupportedScheme.',
  );

  final PlaybackSourceHandoffResult missingSource = handoff.prepare(
    PlaybackSourceHandoffInput.localMediaIdentity(
      LocalMediaIdentity(
        id: const LocalMediaId('missing-source-local-media'),
        uri: Uri.parse(''),
        basename: 'missing-source.mkv',
      ),
    ),
  );
  _expect(!missingSource.isSuccess,
      'Missing source handoff must return a failure result.');
  _expect(
    missingSource.failure?.kind ==
        PlaybackSourceHandoffFailureKind.missingSourceData,
    'Missing source handoff must report missingSourceData.',
  );

  final MockPlaybackController controller = MockPlaybackController(
    matrix: PlaybackCapabilityMatrix(
      capabilities: <PlaybackCapability, CapabilityStatus>{
        PlaybackCapability.localFilePlayback: CapabilityStatus.supported(),
      },
    ),
  );
  _expectSuccess(await controller.open(prepared.source!));
  _expect(controller.currentState.sourceUri == identity.uri,
      'Controller must open the prepared handoff source.');
}

Future<void> _verifyLocalMediaScannerContract() async {
  const MediaScanId scanId = MediaScanId('runtime-local-scan');
  final MediaScanCandidate candidate = MediaScanCandidate(
    identity: LocalMediaIdentity(
      id: const LocalMediaId('runtime-scanned-media'),
      uri: Uri.file('D:/media/scanned.mkv'),
      basename: 'scanned.mkv',
    ),
    sizeBytes: 84,
  );
  final DeterministicMediaLibraryScanner scanner =
      DeterministicMediaLibraryScanner(
    scanId: scanId,
    candidates: <MediaScanCandidate>[candidate],
  );

  final MediaScanResult result = await scanner.scan(
    MediaScanScope(
      roots: <Uri>[Uri.file('D:/media/')],
      extensions: const <String>{'.MKV'},
    ),
  );
  _expect(result.candidates.single == candidate,
      'Local scanner must preserve Domain media candidates.');
  _expect(result.failures.isEmpty,
      'Supported local scanner scope must not report failures.');

  final List<MediaScanEvent> events = await scanner.watch(scanId).toList();
  _expect(events.whereType<MediaScanCandidateDiscovered>().length == 1,
      'Local scanner must publish discovery events.');
  _expect(events.whereType<MediaScanCompleted>().length == 1,
      'Local scanner must publish completion events.');

  final PlaybackSourceHandoffResult handoff =
      const LocalPlaybackSourceHandoff().prepare(
    PlaybackSourceHandoffInput.mediaScanCandidate(result.candidates.single),
  );
  _expect(handoff.source is LocalFilePlaybackSource,
      'Scanner-produced candidates must remain handoff-safe.');

  final MediaScanScopeNormalizationResult unsupported = normalizeMediaScanScope(
    MediaScanScope(
      roots: <Uri>[Uri.parse('https://example.test/media/')],
      extensions: const <String>{'mkv'},
    ),
  );
  _expect(!unsupported.isSuccess,
      'Unsupported scanner roots must normalize to failures.');
  _expect(
    unsupported.failures.single.kind == MediaScanFailureKind.unsupportedScheme,
    'Unsupported scanner roots must report unsupportedScheme.',
  );

  const MediaScanId cancelledScanId = MediaScanId('runtime-cancelled-scan');
  final DeterministicMediaLibraryScanner cancelledScanner =
      DeterministicMediaLibraryScanner(scanId: cancelledScanId);
  await cancelledScanner.cancel(cancelledScanId);
  final MediaScanResult cancelledResult = await cancelledScanner.scan(
    MediaScanScope(
      roots: <Uri>[Uri.file('D:/media/')],
      extensions: const <String>{'mkv'},
    ),
  );
  _expect(
      cancelledResult.failures.single.kind == MediaScanFailureKind.cancelled,
      'Cancelled scans must report typed cancellation.');
}

Future<void> _verifyMediaLibraryPersistenceContract() async {
  final DeterministicMediaLibraryCatalogRepository repository =
      DeterministicMediaLibraryCatalogRepository();
  final MediaScanCandidate candidate = MediaScanCandidate(
    identity: LocalMediaIdentity(
      id: const LocalMediaId('runtime-import-media'),
      uri: Uri.file('D:/media/imported.mkv'),
      basename: 'imported.mkv',
      fingerprint: const MediaFileFingerprint(
          algorithm: 'sha256', value: 'runtime-fingerprint'),
    ),
    sizeBytes: 128,
    duration: const Duration(minutes: 24),
  );
  final DeterministicMediaBatchImportContract importer =
      DeterministicMediaBatchImportContract(repository: repository);

  final MediaImportResult imported =
      await importer.importBatch(<MediaScanCandidate>[candidate]);
  final MediaImportResult duplicated =
      await importer.importBatch(<MediaScanCandidate>[candidate]);
  _expect(imported.importedCount == 1,
      'Media library import must create catalog items.');
  _expect(duplicated.skippedDuplicateCount == 1,
      'Media library import must skip duplicate candidates.');
  _expect(await repository.count() == 1,
      'Media library repository must retain one imported item.');
  _expect((await repository.findByUri(candidate.identity.uri)) != null,
      'Media library repository must find items by URI.');

  final DeterministicPlaybackHistoryStore history =
      DeterministicPlaybackHistoryStore();
  await history.record(
    PlaybackHistoryEntry(
      id: const PlaybackHistoryEntryId('runtime-history'),
      mediaId: candidate.identity.id,
      position: const Duration(minutes: 8),
      duration: const Duration(minutes: 16),
      updatedAt: DateTime.utc(2026, 6, 4, 12),
    ),
  );
  _expect((await history.latestFor(candidate.identity.id)) != null,
      'Playback history must return latest entries.');
  _expect((await history.continueWatching()).single.progress == 0.5,
      'Playback history must derive continue-watching progress.');

  final DeterministicProviderBindingStore bindings =
      DeterministicProviderBindingStore();
  final ProviderBinding userConfirmed = ProviderBinding(
    id: const ProviderBindingId('runtime-binding'),
    localMediaId: candidate.identity.id,
    providerId: 'bangumi',
    subjectId: const ProviderSubjectId('subject-runtime'),
    authority: ProviderBindingAuthority.userConfirmed,
    confidence: 0.2,
    createdAt: DateTime.utc(2026, 6, 4, 12),
  );
  final ProviderBinding automatic = ProviderBinding(
    id: const ProviderBindingId('runtime-automatic-binding'),
    localMediaId: candidate.identity.id,
    providerId: 'bangumi',
    subjectId: const ProviderSubjectId('subject-runtime-auto'),
    authority: ProviderBindingAuthority.automatic,
    confidence: 1,
    createdAt: DateTime.utc(2026, 6, 4, 12),
  );
  await bindings.saveUserConfirmed(userConfirmed);
  _expect(await bindings.saveAutomaticIfAllowed(automatic) == userConfirmed,
      'User-confirmed bindings must outrank automatic matches.');
  _expect((await bindings.bindingFor(candidate.identity.id)) == userConfirmed,
      'Binding store must expose strongest binding.');

  final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
  final Future<List<CacheInvalidationEvent>> events =
      bus.events.take(2).toList();
  bus.publish(
    LibraryItemAdded(
      occurredAt: DateTime.utc(2026, 6, 4, 12),
      mediaLibraryItemId: imported.imported.single.id.value,
      localMediaId: candidate.identity.id.value,
    ),
  );
  bus.publish(HistoryRecorded(
      occurredAt: DateTime.utc(2026, 6, 4, 12),
      localMediaId: candidate.identity.id.value));
  final List<CacheInvalidationEvent> delivered = await events;
  await bus.close();
  _expect(
      delivered.whereType<LibraryItemAdded>().single.changeKind ==
          MediaLibraryChangeKind.created,
      'Library add event must preserve change kind.');
  _expect(
      delivered.whereType<HistoryRecorded>().single.localMediaId ==
          candidate.identity.id.value,
      'History event must preserve local media id.');
}

Future<void> _verifySubtitleProviderCacheContract() async {
  final DeterministicSubtitleCacheStore cache =
      DeterministicSubtitleCacheStore();
  final SubtitleProviderCandidate candidate = SubtitleProviderCandidate(
    id: 'runtime-subtitle-candidate',
    providerId: const SubtitleProviderId('runtime-subtitles'),
    title: 'Runtime Subtitle',
    format: ProviderSubtitleFormat.srt,
    reference: 'runtime-ref',
    confidence: 0.92,
    languageCode: 'ja',
    sourceUri: Uri.parse('https://subtitle.example.test/runtime.srt'),
  );
  final _RuntimeSubtitleProvider provider =
      _RuntimeSubtitleProvider(candidate: candidate);
  final DeterministicSubtitleDiscoveryContract discovery =
      DeterministicSubtitleDiscoveryContract(
    provider: provider,
    cache: cache,
    localScanner: _RuntimeLocalSubtitleScanner(),
    clock: () => DateTime.utc(2026, 6, 4, 12),
  );

  final SubtitleDiscoveryResult firstDiscovery = await discovery.discover(
    SubtitleDiscoveryRequest(
      media: LocalMediaReference(
          uri: Uri.file('D:/media/runtime.mkv'), basename: 'runtime.mkv'),
      providerQuery: SubtitleSearchQuery(
        title: 'Runtime',
        languageCode: 'ja',
        localMediaUri: Uri.file('D:/media/runtime.mkv'),
      ),
    ),
  );
  final SubtitleDiscoveryResult cachedDiscovery = await discovery.discover(
    SubtitleDiscoveryRequest(
      media: LocalMediaReference(
          uri: Uri.file('D:/media/runtime.mkv'), basename: 'runtime.mkv'),
      providerQuery: SubtitleSearchQuery(
        title: 'Runtime',
        languageCode: 'ja',
        localMediaUri: Uri.file('D:/media/runtime.mkv'),
      ),
    ),
  );
  _expect(
      firstDiscovery.localCandidates.single.candidate.source.languageCode ==
          'ja',
      'Subtitle discovery must include local scanner candidates.');
  _expect(firstDiscovery.providerCandidates.single.fromCache == false,
      'First subtitle provider discovery must use provider results.');
  _expect(cachedDiscovery.providerCandidates.single.fromCache,
      'Repeated subtitle provider discovery must use cached results.');
  _expect(provider.searchCount == 1,
      'Subtitle provider search must not repeat while search cache is fresh.');

  final SubtitleProviderHandoffResult firstHandoff =
      await discovery.prepareProviderSubtitle(candidate);
  final SubtitleProviderHandoffResult cachedHandoff =
      await discovery.prepareProviderSubtitle(candidate);
  final ExternalSubtitleSource source =
      firstHandoff.parseRequest!.source as ExternalSubtitleSource;
  _expect(firstHandoff.isSuccess,
      'Subtitle provider handoff must prepare parser input.');
  _expect(firstHandoff.parseRequest?.encodingHint == 'utf-8',
      'Subtitle provider handoff must preserve encoding hints.');
  _expect(source.uri == Uri.parse('file:///D:/cache/runtime.srt'),
      'Subtitle provider handoff must preserve cached/source URI metadata.');
  _expect(cachedHandoff.fromCache,
      'Repeated subtitle retrieval must use cached content.');
  _expect(provider.retrieveCount == 1,
      'Subtitle provider retrieval must not repeat while content cache is fresh.');
}

Future<void> _verifyRssEngineContract() async {
  final DeterministicRssFeedStore store = DeterministicRssFeedStore();
  final FeedSource source = FeedSource(
    id: const FeedSourceId('runtime-rss'),
    displayName: 'Runtime RSS',
    uri: Uri.parse('https://feed.example.test/rss.xml'),
    format: FeedFormat.rss,
    refreshInterval: const Duration(hours: 1),
  );
  final FeedItem item = FeedItem(
    id: const FeedItemId('runtime-feed-item'),
    sourceId: source.id,
    dedupeKey: const FeedDedupeKey('runtime-dedupe'),
    title: 'Runtime Feed Item',
    link: Uri.parse('https://feed.example.test/items/1'),
    publishedAt: DateTime.utc(2026, 6, 4, 11),
  );
  final _RuntimeFeedFetcher fetcher = _RuntimeFeedFetcher(
    responses: <AcgProviderResult<FeedFetchResponse>>[
      AcgProviderSuccess<FeedFetchResponse>(
        FeedFetchResponse(
            sourceId: source.id,
            body: '<rss />',
            etag: 'etag-v1',
            lastModified: DateTime.utc(2026, 6, 4, 12)),
      ),
      AcgProviderSuccess<FeedFetchResponse>(
        FeedFetchResponse(
            sourceId: source.id,
            body: '<rss />',
            etag: 'etag-v2',
            lastModified: DateTime.utc(2026, 6, 4, 13)),
      ),
    ],
  );
  final _RuntimeFeedParser parser = _RuntimeFeedParser(items: <FeedItem>[item]);
  final DeterministicRssEngine engine = DeterministicRssEngine(
    store: store,
    fetcher: fetcher,
    parser: parser,
    deduplicator: DeterministicFeedDeduplicator(),
    clock: () => DateTime.utc(2026, 6, 4, 12),
  );

  await engine.registerSource(source);
  final Future<List<FeedItem>> updates = engine.updates.take(1).toList();
  final RssRefreshOutcome first =
      await engine.refreshSource(RssRefreshRequest(sourceId: source.id));
  final RssRefreshOutcome second =
      await engine.refreshSource(RssRefreshRequest(sourceId: source.id));
  final List<FeedItem> delivered = await updates;
  await engine.close();

  _expect(first.isSuccess, 'First RSS refresh must succeed.');
  _expect(first.newItems.single == item,
      'RSS refresh must return newly accepted items.');
  _expect(second.newItems.isEmpty,
      'Second RSS refresh must dedupe already accepted items.');
  _expect(delivered.single == item,
      'RSS engine must emit newly accepted feed items.');
  _expect((await store.cursorFor(source.id.value))?.etag == 'etag-v2',
      'RSS engine must persist latest fetch cursor metadata.');
  _expect(fetcher.requests.first.etag == null,
      'First RSS fetch must not invent an ETag.');
  _expect(fetcher.requests[1].etag == 'etag-v1',
      'Second RSS fetch must replay stored ETag metadata.');
  _expect(
      (await store.itemsForSource(source.id.value)).single.dedupeKey ==
          item.dedupeKey.value,
      'RSS engine must persist accepted feed items.');
}

Future<void> _verifyRssAutoDownloadPolicyContract() async {
  final DateTime observedAt = DateTime.utc(2026, 6, 7, 12);
  final DeterministicRssAutoDownloadPolicyStore store =
      DeterministicRssAutoDownloadPolicyStore();
  await store.storePolicy(StoredRssAutoDownloadPolicyRecord(
    id: 'runtime-rss-policy',
    label: 'Runtime RSS Policy',
    enabled: true,
    createdAt: observedAt,
    updatedAt: observedAt,
  ));
  await store.storeFeedActivation(StoredRssAutoDownloadFeedActivationRecord(
    policyId: 'runtime-rss-policy',
    sourceId: 'runtime-rss',
    enabled: true,
    updatedAt: observedAt,
  ));
  await store.recordEnqueueOutcome(StoredRssAutoDownloadEnqueueOutcomeRecord(
    id: 'runtime-rss-enqueue',
    candidateId: 'runtime-rss-candidate',
    policyId: 'runtime-rss-policy',
    state: StoredRssAutoDownloadEnqueueState.pending,
    message: 'Runtime handoff pending.',
    recordedAt: observedAt,
  ));
  _expect((await store.policyById('runtime-rss-policy'))?.enabled == true,
      'RSS auto-download storage must persist policy enabled state.');
  _expect(
      (await store.feedActivation(
                  policyId: 'runtime-rss-policy', sourceId: 'runtime-rss'))
              ?.enabled ==
          true,
      'RSS auto-download storage must persist feed-scoped activation.');
  _expect(
      (await store.latestEnqueueOutcome('runtime-rss-candidate'))?.state ==
          StoredRssAutoDownloadEnqueueState.pending,
      'RSS auto-download storage must persist enqueue handoff state.');

  final FeedItem item = FeedItem(
    id: const FeedItemId('runtime-rss-item'),
    sourceId: const FeedSourceId('runtime-rss'),
    dedupeKey: const FeedDedupeKey('runtime-rss-item'),
    title: 'Runtime Episode 1',
    categories: const <String>['anime'],
    enclosure: FeedEnclosure(
      uri: Uri.parse('https://feed.example.test/runtime.torrent'),
      mimeType: 'application/x-bittorrent',
      lengthBytes: 2048,
    ),
  );
  final RssAutoDownloadPolicy policy = RssAutoDownloadPolicy(
    id: const RssAutoDownloadPolicyId('runtime-rss-policy'),
    label: 'Runtime RSS Policy',
    rules: <RssAutoDownloadRule>[
      RssAutoDownloadRule(
        id: const RssAutoDownloadRuleId('runtime-rss-rule'),
        label: 'Runtime include',
        priority: 1,
        include: RssMatcherExpression(
          logic: RssMatcherLogic.all,
          predicates: const <RssMatcherPredicate>[
            RssMatcherPredicate(
              field: RssMatcherField.title,
              operator: RssMatcherOperator.contains,
              value: 'Episode',
            ),
          ],
        ),
        scopedSources: const <FeedSourceId>[FeedSourceId('runtime-rss')],
      ),
    ],
  );
  final _RuntimeRssAutomationHistoryStore history =
      _RuntimeRssAutomationHistoryStore();
  final DeterministicRssAutoDownloadPolicyEvaluator evaluator =
      DeterministicRssAutoDownloadPolicyEvaluator(clock: () => observedAt);
  final List<RssAutomationDecision> first = await evaluator.evaluate(
    policy: policy,
    items: <FeedItem>[item],
    history: history,
  );
  final List<RssAutomationDecision> second = await evaluator.evaluate(
    policy: policy,
    items: <FeedItem>[item],
    history: history,
  );
  final RssAutomationAccepted accepted = first.single as RssAutomationAccepted;
  final RssAutomationHandoffOutcome handoff =
      rssAutomationHandoffFromCandidate(accepted.candidate);
  _expect(handoff.handoff?.feedItemId.value == 'runtime-rss-item',
      'RSS auto-download must expose engine-neutral BT handoff read models.');
  _expect(second.single is RssAutomationDeduplicated,
      'RSS auto-download must dedupe accepted candidates through history.');

  final List<RssAutomationDecision> disabled =
      await const DeterministicRssAutoDownloadPolicyEvaluator(
              automationEnabled: false)
          .evaluate(
    policy: policy,
    items: <FeedItem>[item],
    history: _RuntimeRssAutomationHistoryStore(),
  );
  _expect(disabled.single is RssAutomationDisabled,
      'Disabled RSS automation must report typed disabled outcomes.');

  final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
  final Future<List<CacheInvalidationEvent>> events =
      bus.events.take(2).toList();
  bus.publish(RssAutoDownloadCandidateAccepted(
    occurredAt: observedAt,
    policyId: 'runtime-rss-policy',
    ruleId: 'runtime-rss-rule',
    candidateDedupeKey: accepted.candidate.dedupeKey,
    feedItemId: item.id.value,
    sourceId: item.sourceId.value,
  ));
  bus.publish(RssAutoDownloadEnqueueOutcomeRecorded(
    occurredAt: observedAt,
    policyId: 'runtime-rss-policy',
    candidateId: 'runtime-rss-candidate',
    state: StoredRssAutoDownloadEnqueueState.pending.name,
  ));
  final List<CacheInvalidationEvent> delivered = await events;
  await bus.close();
  _expect(delivered.whereType<RssAutoDownloadCandidateAccepted>().length == 1,
      'RSS auto-download candidate acceptance must publish invalidation.');
  _expect(
      delivered.whereType<RssAutoDownloadEnqueueOutcomeRecorded>().length == 1,
      'RSS auto-download enqueue outcomes must publish invalidation.');
}

final class _RuntimeRssAutomationHistoryStore
    implements RssAutomationHistoryStore {
  final Set<String> _acceptedKeys = <String>{};

  @override
  Future<bool> hasAccepted(FeedDedupeKey itemKey) {
    return Future<bool>.value(_acceptedKeys.contains(itemKey.value));
  }

  @override
  Future<void> record(RssAutomationHistoryEntry entry) {
    if (entry.decision is RssAutomationAccepted) {
      _acceptedKeys.add(entry.itemKey.value);
    }
    return Future<void>.value();
  }
}

Future<void> _verifyOnlineRuleRuntimeContract() async {
  final DateTime observedAt = DateTime.utc(2026, 6, 8, 12);
  final DeterministicOnlineRuleRuntimeStore store =
      DeterministicOnlineRuleRuntimeStore();
  await store.storeManifest(StoredOnlineRuleManifestRecord(
    sourceId: 'runtime-online-source',
    displayName: 'Runtime Online Source',
    version: '1.0.0',
    updateUri: Uri.parse('https://rules.example.test/runtime.json'),
    checksum: 'sha256:runtime',
    updateInterval: const Duration(hours: 12),
    validationState: StoredOnlineRuleValidationState.valid,
    createdAt: observedAt,
    updatedAt: observedAt,
  ));
  await store.storeRuleSets(
    sourceId: 'runtime-online-source',
    ruleSets: <StoredOnlineRuleSetRecord>[
      StoredOnlineRuleSetRecord(
        id: 'runtime-search',
        sourceId: 'runtime-online-source',
        target: StoredOnlineRuleTarget.search,
        operations: const <StoredOnlineExtractionOperationRecord>[
          StoredOnlineExtractionOperationRecord(
            id: 'runtime-title',
            kind: StoredOnlineExtractionKind.regex,
            expression: 'title="([^"]+)"',
            outputKey: 'title',
            required: true,
          ),
        ],
      ),
    ],
  );
  await store.recordPageRetrievalOutcome(
    StoredOnlineRulePageRetrievalOutcomeRecord(
      id: 'runtime-retrieval',
      sourceId: 'runtime-online-source',
      pageUri: Uri.parse('https://source.example.test/search'),
      state: StoredOnlineRuleRetrievalState.retrieved,
      providerCacheKey: 'runtime-online-source::search',
      recordedAt: observedAt,
    ),
  );
  await store.storeCapability(StoredOnlineRuleSourceCapabilityRecord(
    sourceId: 'runtime-online-source',
    state: StoredOnlineRuleCapabilityState.supported,
    updatedAt: observedAt,
  ));
  _expect(
      (await store.manifestBySource('runtime-online-source'))?.version ==
          '1.0.0',
      'Online rule storage must persist manifest versions.');
  _expect(
      (await store.ruleSetsForSource('runtime-online-source')).single.target ==
          StoredOnlineRuleTarget.search,
      'Online rule storage must persist target rule sets.');
  _expect(
      (await store.latestRetrievalOutcome('runtime-online-source'))?.state ==
          StoredOnlineRuleRetrievalState.retrieved,
      'Online rule storage must persist page retrieval outcomes.');

  const DeterministicOnlineRuleRuntime runtime =
      DeterministicOnlineRuleRuntime();
  final OnlineRuleManifest manifest = OnlineRuleManifest(
    sourceId: const OnlineRuleSourceId('runtime-online-source'),
    displayName: 'Runtime Online Source',
    version: const OnlineRuleManifestVersion('1.0.0'),
    updateUri: Uri.parse('https://rules.example.test/runtime.json'),
    checksum: 'sha256:runtime',
    updateInterval: const Duration(hours: 12),
    ruleSets: <OnlineRuleSet>[
      OnlineRuleSet(
        target: OnlineRuleTarget.search,
        operations: const <OnlineExtractionOperation>[
          OnlineExtractionOperation(
            id: 'runtime-title',
            kind: OnlineExtractionKind.regex,
            expression: 'title="([^"]+)"',
            outputKey: 'title',
            required: true,
          ),
          OnlineExtractionOperation(
            id: 'runtime-detail',
            kind: OnlineExtractionKind.cssSelector,
            expression: '.detail',
            outputKey: 'detailUri',
            required: true,
          ),
        ],
      ),
    ],
  );
  final OnlineRuleEvaluationOutcome evaluated = await runtime.evaluateTyped(
    OnlineRuleEvaluationRequest(
      manifest: manifest,
      target: OnlineRuleTarget.search,
      pageUri: Uri.parse('https://source.example.test/search'),
      document:
          'title="Runtime Result" detailUri="https://source.example.test/detail"',
    ),
  );
  _expect(evaluated.isSuccess,
      'Online rule runtime must evaluate supplied documents.');
  final OnlineRuleSearchOutput output =
      runtime.normalize(evaluated.result!) as OnlineRuleSearchOutput;
  _expect(output.results.single.title == 'Runtime Result',
      'Online rule runtime must normalize search result records.');

  final OnlineRuleValidationResult unsupported =
      await runtime.validateManifest(OnlineRuleManifest(
    sourceId: const OnlineRuleSourceId('runtime-bad-online-source'),
    displayName: 'Runtime Bad Online Source',
    version: const OnlineRuleManifestVersion('1.0.0'),
    updateUri: Uri.parse('https://rules.example.test/bad.json'),
    checksum: 'sha256:bad',
    updateInterval: const Duration(hours: 1),
    ruleSets: <OnlineRuleSet>[
      OnlineRuleSet(
        target: OnlineRuleTarget.search,
        operations: const <OnlineExtractionOperation>[
          OnlineExtractionOperation(
            id: 'runtime-wasm',
            kind: OnlineExtractionKind.regex,
            expression: 'wasm:extract',
            outputKey: 'title',
            required: true,
          ),
        ],
      ),
    ],
  ));
  _expect(
      unsupported.issues.single.unsupportedKind ==
          UnsupportedOnlineOperationKind.wasm,
      'Online rule runtime must reject executable WASM operations.');

  final OnlineRuleGatewayRequestDescriptor descriptor =
      OnlineRuleGatewayRequestDescriptor(
    sourceId: const OnlineRuleSourceId('runtime-online-source'),
    providerId: const ProviderId('runtime-online-source'),
    cacheKey: 'runtime-online-source::page',
    pageUri: Uri.parse('https://source.example.test/page'),
    cachePolicy: ProviderCachePolicy.networkFirst,
    ratePolicy:
        const ProviderRatePolicy(maxRequests: 6, window: Duration(minutes: 1)),
    retryPolicy: const ProviderRetryPolicy(
        maxAttempts: 2, initialBackoff: Duration(seconds: 1)),
  );
  _expect(descriptor.requestKey.providerId.value == 'runtime-online-source',
      'Online rule gateway descriptors must preserve provider identity.');

  final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
  final Future<List<CacheInvalidationEvent>> events =
      bus.events.take(2).toList();
  bus.publish(OnlineRuleManifestChanged(
      occurredAt: observedAt,
      sourceId: 'runtime-online-source',
      changeKind: OnlineRuleManifestChangeKind.updated,
      version: '1.0.0'));
  bus.publish(OnlineRuleTargetEvaluated(
      occurredAt: observedAt,
      sourceId: 'runtime-online-source',
      target: OnlineRuleTarget.search.name,
      state: 'succeeded'));
  final List<CacheInvalidationEvent> delivered = await events;
  await bus.close();
  _expect(delivered.whereType<OnlineRuleManifestChanged>().length == 1,
      'Online rule manifest changes must publish invalidation.');
  _expect(delivered.whereType<OnlineRuleTargetEvaluated>().length == 1,
      'Online rule target evaluation must publish invalidation.');
}

Future<void> _verifyWebViewSessionBackfillContract() async {
  final DateTime observedAt = DateTime.utc(2026, 6, 9, 12);
  final DeterministicWebViewSessionBackfillStore store =
      DeterministicWebViewSessionBackfillStore();
  await store.storeChallengeRequest(StoredManualChallengeRequestRecord(
    id: 'runtime-webview-challenge',
    providerScope: 'runtime-provider',
    origin: Uri.parse('https://provider.example.test'),
    challengeUri: Uri.parse('https://provider.example.test/challenge'),
    kind: StoredManualChallengeKind.captcha,
    state: StoredManualChallengeState.required,
    requestedAt: observedAt,
  ));
  await store.updateChallengeState(
    id: 'runtime-webview-challenge',
    state: StoredManualChallengeState.captured,
  );
  await store.storeArtifacts(<StoredWebViewSessionArtifactRecord>[
    StoredWebViewSessionArtifactRecord(
      id: 'runtime-webview-cookie',
      challengeRequestId: 'runtime-webview-challenge',
      providerScope: 'runtime-provider',
      origin: Uri.parse('https://provider.example.test'),
      kind: StoredWebViewSessionArtifactKind.cookie,
      name: 'session',
      valueReference: 'runtime-cookie-ref',
      domain: 'provider.example.test',
      path: '/',
      capturedAt: observedAt,
      expiresAt: observedAt.add(const Duration(hours: 1)),
      state: StoredWebViewSessionArtifactState.approved,
    ),
  ]);
  await store.recordBackfillAttempt(StoredWebViewSessionBackfillAttemptRecord(
    id: 'runtime-webview-attempt',
    challengeRequestId: 'runtime-webview-challenge',
    providerScope: 'runtime-provider',
    requestUri: Uri.parse('https://provider.example.test/resource'),
    state: StoredWebViewSessionBackfillState.succeeded,
    providerCacheKey: 'runtime-provider::resource',
    attemptedAt: observedAt,
  ));
  await store.storeCapability(StoredWebViewSessionCapabilityRecord(
    providerScope: 'runtime-provider',
    capability: WebViewSessionCapability.isolatedWebView.name,
    state: StoredWebViewSessionCapabilityState.supported,
    updatedAt: observedAt,
  ));
  _expect(
      (await store.challengeRequestById('runtime-webview-challenge'))?.state ==
          StoredManualChallengeState.captured,
      'WebView backfill storage must persist manual challenge lifecycle state.');
  _expect(
      (await store.activeArtifactsForProvider(
                  providerScope: 'runtime-provider', now: observedAt))
              .single
              .valueReference ==
          'runtime-cookie-ref',
      'WebView backfill storage must return active same-provider artifacts.');
  _expect(
      (await store.latestBackfillAttempt('runtime-webview-challenge'))?.state ==
          StoredWebViewSessionBackfillState.succeeded,
      'WebView backfill storage must persist retry outcomes.');

  const WebViewSessionBackfillDescriptorFactory factory =
      WebViewSessionBackfillDescriptorFactory();
  final SessionArtifactBundle artifacts = SessionArtifactBundle(
    providerScope: 'runtime-provider',
    origin: Uri.parse('https://provider.example.test'),
    capturedAt: observedAt,
    cookies: <SessionCookieArtifact>[
      SessionCookieArtifact(
        id: const WebViewSessionArtifactId('runtime-cookie'),
        providerScope: 'runtime-provider',
        origin: Uri.parse('https://provider.example.test'),
        name: 'session',
        valueReference: 'runtime-cookie-ref',
        domain: 'provider.example.test',
        path: '/',
        capturedAt: observedAt,
        expiresAt: observedAt.add(const Duration(hours: 1)),
      ),
    ],
  );
  final WebViewSessionBackfillRetryOutcome ready = factory.retryDescriptor(
    attemptId: const WebViewSessionBackfillAttemptId('runtime-webview-attempt'),
    providerId: const ProviderId('runtime-provider'),
    providerScope: 'runtime-provider',
    requestUri: Uri.parse('https://provider.example.test/resource'),
    cacheKey: 'runtime-provider::resource',
    artifacts: artifacts,
    now: observedAt,
    ratePolicy:
        const ProviderRatePolicy(maxRequests: 2, window: Duration(minutes: 1)),
    retryPolicy: const ProviderRetryPolicy(
        maxAttempts: 2, initialBackoff: Duration(seconds: 1)),
  );
  _expect(ready.isSuccess,
      'WebView backfill must produce retry descriptors for active same-origin artifacts.');
  _expect(ready.descriptor?.requestKey.cacheKey == 'runtime-provider::resource',
      'WebView backfill retry descriptors must preserve ProviderGateway keys.');

  final WebViewSessionBackfillRetryOutcome rejected = factory.retryDescriptor(
    attemptId:
        const WebViewSessionBackfillAttemptId('runtime-rejected-attempt'),
    providerId: const ProviderId('runtime-provider'),
    providerScope: 'runtime-provider',
    requestUri: Uri.parse('https://other.example.test/resource'),
    cacheKey: 'runtime-provider::other',
    artifacts: artifacts,
    now: observedAt,
    ratePolicy:
        const ProviderRatePolicy(maxRequests: 2, window: Duration(minutes: 1)),
    retryPolicy: const ProviderRetryPolicy(
        maxAttempts: 2, initialBackoff: Duration(seconds: 1)),
  );
  _expect(
      rejected.failure?.failureKind ==
          WebViewSessionBackfillFailureKind.rejectedOrigin,
      'WebView backfill must reject cross-origin artifact reuse.');
  _expect(
      factory
              .validateManualOperation('auto captcha solve')
              .unsupportedOperationKind ==
          UnsupportedWebViewSessionOperationKind.automaticCaptchaSolving,
      'WebView backfill must reject automatic captcha solving contracts.');

  final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
  final Future<List<CacheInvalidationEvent>> events =
      bus.events.take(2).toList();
  bus.publish(WebViewSessionChallengeChanged(
    occurredAt: observedAt,
    challengeRequestId: 'runtime-webview-challenge',
    providerScope: 'runtime-provider',
    origin: Uri.parse('https://provider.example.test'),
    changeKind: WebViewSessionChallengeChangeKind.required,
  ));
  bus.publish(WebViewSessionCapabilityChanged(
    occurredAt: observedAt,
    providerScope: 'runtime-provider',
    capability: WebViewSessionCapability.isolatedWebView.name,
    supported: true,
  ));
  final List<CacheInvalidationEvent> delivered = await events;
  await bus.close();
  _expect(delivered.whereType<WebViewSessionChallengeChanged>().length == 1,
      'WebView challenge lifecycle changes must publish invalidation.');
  _expect(delivered.whereType<WebViewSessionCapabilityChanged>().length == 1,
      'WebView capability changes must publish invalidation.');
}

Future<void> _verifyNetworkPolicyContract() async {
  final DateTime observedAt = DateTime.utc(2026, 6, 10, 12);
  final DeterministicNetworkPolicyStore store =
      DeterministicNetworkPolicyStore();
  await store.storeProfile(StoredNetworkPolicyProfileRecord(
    id: 'runtime-network-policy',
    providerScope: 'runtime-provider',
    label: 'Runtime Network Policy',
    fallbackBehavior: StoredNetworkPolicyFallbackBehavior.systemDns,
    createdAt: observedAt,
    updatedAt: observedAt,
  ));
  await store.storeRules(
    policyId: 'runtime-network-policy',
    rules: <StoredNetworkPolicyRuleRecord>[
      StoredNetworkPolicyRuleRecord(
        id: 'runtime-network-rule',
        policyId: 'runtime-network-policy',
        order: 1,
        matcherKind: StoredNetworkPolicyMatcherKind.domainSuffix,
        pattern: 'example.test',
        action: StoredNetworkPolicyAction.doh,
        resolverEndpoint: Uri.parse('https://resolver.example.test/dns-query'),
        auditLabel: 'runtime-doh',
      ),
    ],
  );
  await store.assignProvider(StoredNetworkPolicyProviderAssignmentRecord(
    id: 'runtime-network-assignment',
    providerScope: 'runtime-provider',
    policyId: 'runtime-network-policy',
    assignedAt: observedAt,
  ));
  await store.recordEvaluation(StoredNetworkPolicyEvaluationSnapshotRecord(
    id: 'runtime-network-evaluation',
    providerScope: 'runtime-provider',
    requestUri: Uri.parse('https://media.example.test/video'),
    policyId: 'runtime-network-policy',
    ruleId: 'runtime-network-rule',
    decisionKind: StoredNetworkPolicyDecisionKind.allowed,
    action: StoredNetworkPolicyAction.doh,
    recordedAt: observedAt,
  ));
  await store.storeCapability(StoredNetworkPolicyCapabilityRecord(
    providerScope: 'runtime-provider',
    capability: NetworkPolicyCapability.dohIntent.name,
    state: StoredNetworkPolicyCapabilityState.supported,
    updatedAt: observedAt,
  ));
  _expect(
      (await store.profileById('runtime-network-policy'))?.providerScope ==
          'runtime-provider',
      'Network policy storage must persist provider-scoped profiles.');
  _expect(
      (await store.rulesForPolicy('runtime-network-policy')).single.action ==
          StoredNetworkPolicyAction.doh,
      'Network policy storage must persist ordered resolver intent rules.');
  _expect(
      (await store.assignmentForProvider('runtime-provider'))?.policyId ==
          'runtime-network-policy',
      'Network policy storage must persist provider assignments.');
  _expect(
      (await store.evaluationsForProvider('runtime-provider')).single.action ==
          StoredNetworkPolicyAction.doh,
      'Network policy storage must persist evaluation snapshots.');

  final NetworkPolicy policy = NetworkPolicy(
    id: const NetworkPolicyId('runtime-network-policy'),
    providerScope: 'runtime-provider',
    rules: <NetworkPolicyRule>[
      NetworkPolicyRule(
        id: const NetworkPolicyRuleId('runtime-doh-rule'),
        order: 1,
        matcher: const NetworkPolicyMatcher(
          kind: NetworkPolicyMatcherKind.domainSuffix,
          pattern: 'example.test',
        ),
        action: NetworkPolicyAction.doh,
        resolverIntent: NetworkResolverIntent.doh(
          endpoint: Uri.parse('https://resolver.example.test/dns-query'),
        ),
        auditLabel: 'runtime-doh',
      ),
    ],
  );
  final DeterministicNetworkPolicyEvaluator evaluator =
      DeterministicNetworkPolicyEvaluator();
  final NetworkPolicyDecision allowed = await evaluator.evaluate(
    policy: policy,
    request: NetworkPolicyRequest(
      providerScope: 'runtime-provider',
      uri: Uri.parse('https://media.example.test/video'),
      cacheKey: 'runtime-provider::video',
    ),
  );
  final NetworkPolicyDecision blocked = await evaluator.evaluate(
    policy: policy,
    request: NetworkPolicyRequest(
      providerScope: 'runtime-provider',
      uri: Uri.parse('http://127.0.0.1/admin'),
    ),
  );
  _expect(
      allowed is NetworkPolicyAllowed &&
          allowed.action == NetworkPolicyAction.doh,
      'Network policy evaluator must return declarative resolver intent decisions.');
  _expect(
      blocked is NetworkPolicyBlocked &&
          blocked.kind == NetworkPolicyFailureKind.loopbackAddress,
      'Network policy evaluator must normalize SSRF loopback failures.');

  final ProviderNetworkPolicyHandoffDescriptor handoff =
      ProviderNetworkPolicyHandoffDescriptor(
    providerId: const ProviderId('runtime-provider'),
    providerScope: 'runtime-provider',
    cacheKey: 'runtime-provider::video',
    requestUri: Uri.parse('https://media.example.test/video'),
    cachePolicy: ProviderCachePolicy.networkFirst,
    ratePolicy:
        const ProviderRatePolicy(maxRequests: 2, window: Duration(minutes: 1)),
    retryPolicy: const ProviderRetryPolicy(
        maxAttempts: 2, initialBackoff: Duration(seconds: 1)),
    requiredCapabilities: const <NetworkPolicyCapability>{
      NetworkPolicyCapability.dohIntent
    },
  );
  _expect(handoff.requestKey.providerId.value == 'runtime-provider',
      'Network policy handoff must preserve provider identity.');
  _expect(handoff.networkPolicyRequest.cacheKey == 'runtime-provider::video',
      'Network policy handoff must preserve provider cache keys.');

  final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
  final Future<List<CacheInvalidationEvent>> events =
      bus.events.take(2).toList();
  bus.publish(NetworkPolicyEvaluationOutcomeRecorded(
    occurredAt: observedAt,
    evaluationId: 'runtime-network-evaluation',
    providerScope: 'runtime-provider',
    requestUri: Uri.parse('https://media.example.test/video'),
    decisionKind: 'allowed',
  ));
  bus.publish(NetworkPolicyCapabilityChanged(
    occurredAt: observedAt,
    providerScope: 'runtime-provider',
    capability: NetworkPolicyCapability.dohIntent.name,
    supported: true,
  ));
  final List<CacheInvalidationEvent> delivered = await events;
  await bus.close();
  _expect(
      delivered.whereType<NetworkPolicyEvaluationOutcomeRecorded>().length == 1,
      'Network policy evaluations must publish invalidation events.');
  _expect(delivered.whereType<NetworkPolicyCapabilityChanged>().length == 1,
      'Network policy capability changes must publish invalidation events.');
}

Future<void> _verifyDiagnosticsCenterContract() async {
  final DateTime observedAt = DateTime.utc(2026, 6, 11, 12);
  final DeterministicDiagnosticsStore store = DeterministicDiagnosticsStore();
  await store.storeSchema(StoredDiagnosticsSchemaRecord(
    eventType: 'provider.failure',
    category: DiagnosticsCategory.provider,
    version: 1,
    defaultSeverity: DiagnosticsSeverity.error,
    registeredAt: observedAt,
    requiredPayloadKeys: const <String>['message'],
    capabilityArea: DiagnosticsCapability.providerGatewayCorrelation,
  ));
  await store.recordEvent(StoredDiagnosticsEventRecord(
    id: 'runtime-diagnostics-event',
    eventType: 'provider.failure',
    schemaVersion: 1,
    category: DiagnosticsCategory.provider,
    severity: DiagnosticsSeverity.error,
    occurredAt: observedAt,
    sourceModule: 'provider-gateway',
    correlationId: 'runtime-correlation',
    redacted: true,
    payload: const <String, Object?>{'message': 'Provider failed.'},
    capabilityArea: DiagnosticsCapability.providerGatewayCorrelation,
  ));
  await store.storeCapability(StoredDiagnosticsCapabilityRecord(
    capability: DiagnosticsCapability.snapshotQuery,
    state: StoredDiagnosticsCapabilityState.supported,
    updatedAt: observedAt,
  ));
  _expect((await store.schemaByEventType('provider.failure'))?.version == 1,
      'Diagnostics storage must persist event schemas.');
  _expect(
      (await store.queryEvents(correlationId: 'runtime-correlation'))
          .single
          .redacted,
      'Diagnostics storage must persist redacted event records.');
  _expect(
      (await store.capability(DiagnosticsCapability.snapshotQuery))?.state ==
          StoredDiagnosticsCapabilityState.supported,
      'Diagnostics storage must persist capability state.');

  final DeterministicDiagnosticsEventRegistry registry =
      DeterministicDiagnosticsEventRegistry();
  await registry.register(DiagnosticsEventSchema(
    type: const DiagnosticsEventType('provider.failure'),
    category: DiagnosticsCategory.provider,
    version: 1,
    defaultSeverity: DiagnosticsSeverity.error,
    requiredPayloadKeys: const <String>['message', 'secret'],
    capabilityArea: DiagnosticsCapability.providerGatewayCorrelation,
  ));
  final DeterministicDiagnosticsCenter center = DeterministicDiagnosticsCenter(
    registry: registry,
    retentionPolicy: const DiagnosticsRetentionPolicy(
        maxEvents: 10, maxAge: Duration(days: 7)),
    redactionPolicy:
        DiagnosticsRedactionPolicy(sensitivePayloadKeys: const <String>['secret']),
    capabilityMatrix: DiagnosticsCapabilityMatrix(
      capabilities: <DiagnosticsCapability, DiagnosticsCapabilityStatus>{
        for (final DiagnosticsCapability capability in DiagnosticsCapability.values)
          capability: const DiagnosticsCapabilityStatus.supported(),
      },
    ),
  );
  final DiagnosticsOperationOutcome outcome = await center.record(
    DiagnosticsEvent(
      type: const DiagnosticsEventType('provider.failure'),
      schemaVersion: 1,
      category: DiagnosticsCategory.provider,
      severity: DiagnosticsSeverity.error,
      occurredAt: observedAt,
      sourceModule: 'provider-gateway',
      correlationId: const DiagnosticsCorrelationId('runtime-correlation'),
      payload: const <String, Object?>{
        'message': 'Provider failed.',
        'secret': 'runtime-secret',
      },
      capabilityArea: DiagnosticsCapability.providerGatewayCorrelation,
    ),
  );
  final DiagnosticsSnapshot snapshot = await center.snapshot(DiagnosticsQuery(
    category: DiagnosticsCategory.provider,
    correlationId: const DiagnosticsCorrelationId('runtime-correlation'),
    capabilityAreas: const <DiagnosticsCapability>[
      DiagnosticsCapability.providerGatewayCorrelation
    ],
  ));
  final DiagnosticsLocalExportDescriptor exportDescriptor =
      await center.describeLocalExport(
    snapshot: snapshot,
    format: 'jsonl',
    now: observedAt,
  );
  _expect(outcome.isSuccess, 'Diagnostics center must record registered events.');
  _expect(snapshot.events.single.payload['secret'] == '<redacted>',
      'Diagnostics center must redact sensitive payload keys.');
  _expect(exportDescriptor.redacted,
      'Diagnostics local export descriptors must declare redacted content.');

  final ProviderDiagnosticsCorrelationDescriptor descriptor =
      ProviderDiagnosticsCorrelationDescriptor(
    providerId: const ProviderId('runtime-provider'),
    requestKey: ProviderRequestKey(
      providerId: const ProviderId('runtime-provider'),
      cacheKey: 'runtime-provider::diagnostics',
    ),
    cachePolicy: ProviderCachePolicy.networkFirst,
    correlationId: 'runtime-correlation',
    failureKind: ProviderFailureKind.terminal,
    networkPolicyFailureKind: NetworkPolicyFailureKind.loopbackAddress.name,
    networkPolicyEvaluationId: 'runtime-network-evaluation',
  );
  _expect(descriptor.requestKey.cacheKey == 'runtime-provider::diagnostics',
      'Provider diagnostics correlation must preserve request keys.');

  final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
  final Future<List<CacheInvalidationEvent>> events = bus.events.take(2).toList();
  bus.publish(DiagnosticsEventRecorded(
    occurredAt: observedAt,
    eventId: 'runtime-diagnostics-event',
    eventType: 'provider.failure',
    sourceModule: 'provider-gateway',
    correlationId: 'runtime-correlation',
  ));
  bus.publish(DiagnosticsCapabilityChanged(
    occurredAt: observedAt,
    capability: DiagnosticsCapability.snapshotQuery.name,
    supported: true,
  ));
  final List<CacheInvalidationEvent> delivered = await events;
  await bus.close();
  _expect(delivered.whereType<DiagnosticsEventRecorded>().length == 1,
      'Diagnostics event recording must publish invalidation.');
  _expect(delivered.whereType<DiagnosticsCapabilityChanged>().length == 1,
      'Diagnostics capability changes must publish invalidation.');
}

Future<void> _verifySeasonalIndexerContract() async {
  final _RuntimeRssEngine rssEngine = _RuntimeRssEngine();
  final DeterministicSeasonalCatalogStore catalogStore =
      DeterministicSeasonalCatalogStore();
  final DeterministicBangumiMatchQueueStore queueStore =
      DeterministicBangumiMatchQueueStore();
  final StreamCacheInvalidationBus indexerBus = StreamCacheInvalidationBus();
  final DeterministicSeasonalIndexer indexer = DeterministicSeasonalIndexer(
    rssEngine: rssEngine,
    consumers: <SeasonalAnimeConsumer>[_RuntimeSeasonalConsumer()],
    catalogStore: catalogStore,
    matchQueueStore: queueStore,
    cacheInvalidationBus: indexerBus,
    clock: () => DateTime.utc(2026, 6, 4, 12),
  );

  final Future<List<CacheInvalidationEvent>> indexerEvents =
      indexerBus.events.take(2).toList();
  await indexer.startListening();
  rssEngine.emit(
    FeedItem(
      id: const FeedItemId('runtime-seasonal-item'),
      sourceId: const FeedSourceId('runtime-seasonal-rss'),
      dedupeKey: const FeedDedupeKey('runtime-seasonal-dedupe'),
      title: 'Runtime Seasonal Anime',
      link: Uri.parse('https://example.test/runtime-seasonal'),
      publishedAt: DateTime.utc(2026, 6, 4, 11),
    ),
  );
  final List<CacheInvalidationEvent> deliveredIndexerEvents =
      await indexerEvents;
  await indexer.stopListening();
  await indexer.close();
  await indexerBus.close();

  _expect(await catalogStore.count() == 1,
      'Seasonal indexer must persist normalized catalog entries.');
  _expect(await queueStore.pendingCount() == 1,
      'Seasonal indexer must enqueue Bangumi match work.');
  _expect(
      deliveredIndexerEvents.whereType<SeasonalCatalogUpdated>().length == 1,
      'Seasonal indexer must publish catalog invalidation events.');
  _expect(deliveredIndexerEvents.whereType<BangumiMatchEnqueued>().length == 1,
      'Seasonal indexer must publish match enqueue events.');

  final StreamCacheInvalidationBus workerBus = StreamCacheInvalidationBus();
  final DeterministicProviderBindingStore bindings =
      DeterministicProviderBindingStore();
  final DeterministicBangumiMatchWorker worker =
      DeterministicBangumiMatchWorker(
    queueStore: queueStore,
    bindingStore: bindings,
    bangumiProvider: _RuntimeBangumiProvider(),
    cacheInvalidationBus: workerBus,
    clock: () => DateTime.utc(2026, 6, 4, 12),
  );
  final Future<List<CacheInvalidationEvent>> workerEvents =
      workerBus.events.take(1).toList();
  final BangumiMatchWorkerResult result = await worker.processNext();
  final List<CacheInvalidationEvent> deliveredWorkerEvents = await workerEvents;
  await workerBus.close();

  _expect(result.isSuccess, 'Bangumi match worker must process queue items.');
  _expect(result.matchResult?.outcome == AutomaticBangumiMatchOutcome.applied,
      'Bangumi match worker must apply confident automatic matches.');
  _expect(deliveredWorkerEvents.whereType<BangumiMatchApplied>().length == 1,
      'Bangumi match worker must publish applied match events.');
  _expect(
      (await bindings.bindingFor(const LocalMediaId('runtime-seasonal-entry')))
              ?.subjectId
              ?.value ==
          'runtime-subject',
      'Bangumi match worker must persist automatic bindings.');
}

Future<void> _verifyBtTaskCoreContract() async {
  final _RuntimeDownloadEngineAdapter adapter = _RuntimeDownloadEngineAdapter();
  final DeterministicBtTaskStore store = DeterministicBtTaskStore();
  final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
  final DeterministicBtTaskCore core = DeterministicBtTaskCore(
    adapter: adapter,
    store: store,
    cacheInvalidationBus: bus,
    clock: () => DateTime.utc(2026, 6, 5, 12),
  );

  final Future<CacheInvalidationEvent> createdEvent = bus.events.first;
  final BtTaskCreateOutcome created = await core.createTask(
    const BtTaskCreateRequest(
      source: MagnetBtTaskSource(uri: 'magnet:?xt=urn:btih:runtime'),
    ),
  );
  _expect(created.isSuccess, 'BT task core must create adapter-backed tasks.');
  _expect((await createdEvent) is BtTaskCreated,
      'BT task creation must publish cache invalidation.');
  _expect((await store.findTaskById('runtime-bt-task')) != null,
      'BT task core must persist created tasks.');

  final Future<List<CacheInvalidationEvent>> metadataEvents =
      bus.events.take(2).toList();
  final BtTaskMetadataOutcome metadata =
      await core.ensureMetadata(const BtTaskId('runtime-bt-task'));
  final BtTaskCommandOutcome selected = await core.selectFiles(
      const BtTaskId('runtime-bt-task'), const <BtFileIndex>[BtFileIndex(1)]);
  final List<CacheInvalidationEvent> deliveredMetadataEvents =
      await metadataEvents;
  _expect(
      metadata.isSuccess, 'BT task core must fetch metadata through adapter.');
  _expect(selected.isSuccess, 'BT task core must route file selections.');
  _expect(
      (await store.metadataFor('runtime-bt-task'))?.infoHash == 'runtimehash',
      'BT task core must persist fetched metadata.');
  _expect(
      (await store.filesFor('runtime-bt-task'))[1].selectionState ==
          StoredBtFileSelectionState.selected,
      'BT task core must persist selected file state.');
  _expect(
      deliveredMetadataEvents.whereType<BtMetadataUpdated>().length == 1 &&
          deliveredMetadataEvents
                  .whereType<BtTaskFileSelectionChanged>()
                  .length ==
              1,
      'BT task core must publish metadata and file selection invalidations.');

  final Future<List<CacheInvalidationEvent>> lifecycleEvents =
      bus.events.take(3).toList();
  await core.pause(const BtTaskId('runtime-bt-task'));
  await core.resume(const BtTaskId('runtime-bt-task'));
  await core.remove(const BtTaskId('runtime-bt-task'));
  final List<CacheInvalidationEvent> deliveredLifecycleEvents =
      await lifecycleEvents;
  _expect(adapter.pausedTaskIds.single.value == 'runtime-bt-task',
      'BT task core must route pause to adapter.');
  _expect(adapter.resumedTaskIds.single.value == 'runtime-bt-task',
      'BT task core must route resume to adapter.');
  _expect(adapter.removedTaskIds.single.value == 'runtime-bt-task',
      'BT task core must route remove to adapter.');
  _expect(
      (await store.findTaskById('runtime-bt-task'))?.lifecycleState ==
          StoredBtTaskLifecycleState.removed,
      'BT task core must persist removal lifecycle state.');
  _expect(deliveredLifecycleEvents.whereType<BtTaskRemoved>().length == 1,
      'BT task core must publish removal invalidation.');

  final Future<BtTaskStatus> statusFuture =
      core.watchStatus(const BtTaskId('runtime-bt-task')).first;
  await Future<void>.delayed(Duration.zero);
  adapter.emitStatus(_runtimeBtStatus());
  await statusFuture;
  _expect(
      (await store.latestTransferSnapshot('runtime-bt-task'))?.progress == 0.5,
      'BT task core must persist adapter status snapshots.');

  final Future<List<CacheInvalidationEvent>> eventInvalidations =
      bus.events.take(2).toList();
  final Future<List<BtTaskEvent>> taskEvents =
      core.watchEvents(const BtTaskId('runtime-bt-task')).take(2).toList();
  await Future<void>.delayed(Duration.zero);
  adapter.emitEvent(BtMetadataReceived(
      taskId: const BtTaskId('runtime-bt-task'),
      metadata: _runtimeBtMetadata()));
  adapter.emitEvent(const BtTaskFailed(
      taskId: BtTaskId('runtime-bt-task'), message: 'Runtime failure.'));
  await taskEvents;
  final List<CacheInvalidationEvent> deliveredEventInvalidations =
      await eventInvalidations;
  await bus.close();

  _expect(
      (await store.latestEvent('runtime-bt-task'))?.eventKind ==
          StoredBtTaskEventKind.failed,
      'BT task core must persist latest adapter event.');
  _expect(
      deliveredEventInvalidations.whereType<BtMetadataUpdated>().length == 1 &&
          deliveredEventInvalidations
                  .whereType<BtTaskLifecycleChanged>()
                  .single
                  .newState ==
              BtTaskLifecycleState.failed.name,
      'BT task core must publish adapter event invalidations.');

  final _RuntimeDownloadEngineAdapter unsupportedAdapter =
      _RuntimeDownloadEngineAdapter(
    capabilities: BtCapabilityMatrix.unsupported(reason: 'BT disabled.'),
  );
  final BtTaskCreateOutcome unsupported = await DeterministicBtTaskCore(
    adapter: unsupportedAdapter,
    store: DeterministicBtTaskStore(),
  ).createTask(
    const BtTaskCreateRequest(
      source: MagnetBtTaskSource(uri: 'magnet:?xt=urn:btih:runtime'),
    ),
  );
  _expect(unsupported.failure?.kind == BtTaskFailureKind.capabilityUnsupported,
      'BT task core must preserve capability failures without adapter calls.');
  _expect(unsupportedAdapter.createdRequests.isEmpty,
      'Unsupported BT capabilities must not call adapter createTask.');
}

Future<void> _verifyVirtualMediaStreamContract() async {
  final DeterministicBtTaskStore taskStore = DeterministicBtTaskStore();
  final DeterministicVirtualMediaStreamStore streamStore =
      DeterministicVirtualMediaStreamStore();
  final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
  final DateTime observedAt = DateTime.utc(2026, 6, 5, 12);
  await taskStore.storeTask(
    StoredBtTaskRecord(
      id: 'runtime-stream-task',
      sourceKind: StoredBtTaskSourceKind.magnet,
      sourceUri: 'magnet:?xt=urn:btih:runtimestream',
      lifecycleState: StoredBtTaskLifecycleState.ready,
      createdAt: observedAt,
      updatedAt: observedAt,
    ),
  );
  await taskStore.storeMetadata(
    const StoredBtTaskMetadataRecord(
      taskId: 'runtime-stream-task',
      infoHash: 'runtimestream',
      name: 'Runtime Stream Pack',
      totalSizeBytes: 4096,
      pieceLengthBytes: 1024,
    ),
  );
  await taskStore.storeFiles(
    taskId: 'runtime-stream-task',
    files: const <StoredBtTaskFileRecord>[
      StoredBtTaskFileRecord(
        taskId: 'runtime-stream-task',
        index: 1,
        path: 'Runtime Episode.mkv',
        lengthBytes: 4096,
        offsetBytes: 0,
        selectionState: StoredBtFileSelectionState.streamingTarget,
        mediaMimeType: 'video/x-matroska',
      ),
    ],
  );
  final DeterministicVirtualMediaStreamRegistry registry =
      DeterministicVirtualMediaStreamRegistry(
    btTaskStore: taskStore,
    streamStore: streamStore,
    cacheInvalidationBus: bus,
    clock: () => observedAt,
  );

  final Future<List<CacheInvalidationEvent>> events =
      bus.events.take(3).toList();
  final VirtualMediaStreamCreateOutcome created = await registry.createForFile(
    taskId: const BtTaskId('runtime-stream-task'),
    fileIndex: const BtFileIndex(1),
  );
  _expect(created.isSuccess, 'Virtual stream registry must create streams.');
  _expect(created.descriptor?.mimeType == 'video/x-matroska',
      'Virtual stream descriptors must preserve content metadata.');
  _expect((await streamStore.findStreamById('runtime-stream-task::1')) != null,
      'Virtual stream registry must persist descriptors.');

  final VirtualMediaStream stream = (await registry
      .streamFor(const VirtualMediaStreamId('runtime-stream-task::1')))!;
  final VirtualRangeEnsureOutcome ensured = await stream.ensureRange(
    const VirtualByteRangeRequest(
      streamId: VirtualMediaStreamId('runtime-stream-task::1'),
      range: BtByteRange(start: 0, endInclusive: 1023),
    ),
  );
  _expect(ensured.isSuccess, 'Virtual stream must ensure available ranges.');
  _expect((await stream.bufferedRanges()).single.range.endByte == 1023,
      'Virtual stream must report persisted buffered ranges.');
  _expect(
      (await streamStore.latestEvent('runtime-stream-task::1'))?.eventKind ==
          StoredVirtualStreamEventKind.rangeBuffered,
      'Virtual stream must persist latest range events.');

  final PlaybackSourceHandoffResult handoff =
      const LocalPlaybackSourceHandoff().prepare(
    PlaybackSourceHandoffInput.virtualStreamSource(
      VirtualStreamPlaybackSource.fromDescriptor(created.descriptor!),
    ),
  );
  _expect(handoff.source is VirtualStreamPlaybackSource,
      'Playback handoff must prepare virtual stream playback sources.');
  _expect(
      (handoff.source as VirtualStreamPlaybackSource).streamId.value ==
          'runtime-stream-task::1',
      'Playback handoff must preserve virtual stream identity.');

  final VirtualStreamCommandOutcome closed = await stream.close();
  final List<CacheInvalidationEvent> delivered = await events;
  await bus.close();
  _expect(closed.isSuccess, 'Virtual stream closure must succeed.');
  _expect(delivered.whereType<VirtualStreamCreated>().length == 1,
      'Virtual stream creation must publish invalidation.');
  _expect(delivered.whereType<VirtualStreamRangeBuffered>().length == 1,
      'Virtual stream range buffering must publish invalidation.');
  _expect(delivered.whereType<VirtualStreamClosed>().length == 1,
      'Virtual stream closure must publish invalidation.');
}

Future<void> _verifyPiecePrioritySchedulerContract() async {
  final DeterministicBtTaskStore taskStore = DeterministicBtTaskStore();
  final DeterministicVirtualMediaStreamStore streamStore =
      DeterministicVirtualMediaStreamStore();
  final DeterministicPiecePrioritySchedulerStore schedulerStore =
      DeterministicPiecePrioritySchedulerStore();
  final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
  final DateTime observedAt = DateTime.utc(2026, 6, 5, 12);
  await taskStore.storeTask(
    StoredBtTaskRecord(
      id: 'runtime-priority-task',
      sourceKind: StoredBtTaskSourceKind.magnet,
      sourceUri: 'magnet:?xt=urn:btih:runtimepriority',
      lifecycleState: StoredBtTaskLifecycleState.ready,
      createdAt: observedAt,
      updatedAt: observedAt,
    ),
  );
  await taskStore.storeMetadata(
    const StoredBtTaskMetadataRecord(
      taskId: 'runtime-priority-task',
      infoHash: 'runtimepriority',
      name: 'Runtime Priority Pack',
      totalSizeBytes: 4096,
      pieceLengthBytes: 1024,
    ),
  );
  await taskStore.storeFiles(
    taskId: 'runtime-priority-task',
    files: const <StoredBtTaskFileRecord>[
      StoredBtTaskFileRecord(
        taskId: 'runtime-priority-task',
        index: 0,
        path: 'Runtime Priority.mkv',
        lengthBytes: 4096,
        offsetBytes: 0,
        selectionState: StoredBtFileSelectionState.streamingTarget,
      ),
    ],
  );
  await streamStore.storeStream(
    StoredVirtualMediaStreamRecord(
      id: 'runtime-priority-task::0',
      taskId: 'runtime-priority-task',
      fileIndex: 0,
      lengthBytes: 4096,
      lifecycleState: StoredVirtualMediaStreamLifecycleState.active,
      createdAt: observedAt,
      updatedAt: observedAt,
    ),
  );
  final DeterministicPiecePriorityScheduler scheduler =
      DeterministicPiecePriorityScheduler(
    btTaskStore: taskStore,
    streamStore: streamStore,
    schedulerStore: schedulerStore,
    cacheInvalidationBus: bus,
    clock: () => observedAt,
  );
  final PiecePriorityStrategyProfile profile = PiecePriorityStrategyProfile(
    id: 'runtime-balanced',
    displayName: 'Runtime Balanced',
    firstPiecePriority: DownloadPriority.critical,
    tailPiecePriority: DownloadPriority.high,
    playbackWindowPriority: DownloadPriority.high,
    seekTargetPriority: DownloadPriority.critical,
    staleWindowPriority: DownloadPriority.low,
    lookaheadBytes: 1024,
    seekLookaheadBytes: 1024,
    edgePieceCount: 1,
  );

  final Future<List<CacheInvalidationEvent>> planEvents =
      bus.events.take(2).toList();
  final PiecePriorityPlanOutcome planned = await scheduler.plan(
    PiecePriorityPlanRequest(
      taskId: const BtTaskId('runtime-priority-task'),
      streamId: const VirtualMediaStreamId('runtime-priority-task::0'),
      profile: profile,
      playbackWindow: const PlaybackWindow(
        streamId: VirtualMediaStreamId('runtime-priority-task::0'),
        currentByteOffset: 0,
        lookaheadBytes: 1024,
      ),
      seekTarget: const SeekTarget(
        streamId: VirtualMediaStreamId('runtime-priority-task::0'),
        targetByteOffset: 2048,
      ),
    ),
  );
  final List<CacheInvalidationEvent> deliveredPlanEvents = await planEvents;
  _expect(planned.isSuccess, 'Piece priority scheduler must generate plans.');
  _expect(planned.plan?.rules.isNotEmpty ?? false,
      'Piece priority plans must contain priority rules.');
  _expect((await schedulerStore.findProfileById('runtime-balanced')) != null,
      'Piece priority scheduler must persist profiles.');
  _expect(
      (await schedulerStore.rulesForPlan(planned.plan!.id.value)).isNotEmpty,
      'Piece priority scheduler must persist plan rules.');
  _expect(
      deliveredPlanEvents.whereType<PiecePriorityProfileChanged>().length == 1,
      'Profile changes must publish invalidation.');
  _expect(
      deliveredPlanEvents.whereType<PiecePriorityPlanGenerated>().length == 1,
      'Generated priority plans must publish invalidation.');

  final DeterministicPiecePriorityPlanApplicationRecorder recorder =
      DeterministicPiecePriorityPlanApplicationRecorder(
    schedulerStore: schedulerStore,
    cacheInvalidationBus: bus,
    clock: () => observedAt,
  );
  final Future<CacheInvalidationEvent> appliedEvent = bus.events.first;
  final PiecePriorityApplicationOutcome applied = await recorder.applyAndRecord(
    planId: planned.plan!.id,
    applier: _RuntimePiecePriorityPlanApplier(),
  );
  final CacheInvalidationEvent deliveredAppliedEvent = await appliedEvent;
  await bus.close();
  _expect(applied.isSuccess, 'Piece priority plan application must succeed.');
  _expect(
      (await schedulerStore.latestApplicationEvent(planned.plan!.id.value))
              ?.outcome ==
          StoredPiecePriorityApplicationOutcomeKind.accepted,
      'Piece priority application events must be persisted.');
  _expect(deliveredAppliedEvent is PiecePriorityPlanApplied,
      'Applied priority plans must publish invalidation.');

  final PiecePriorityPlanOutcome missingMetadata =
      await DeterministicPiecePriorityScheduler(
    btTaskStore: DeterministicBtTaskStore(),
    streamStore: streamStore,
    schedulerStore: DeterministicPiecePrioritySchedulerStore(),
  ).plan(
    PiecePriorityPlanRequest(
      taskId: const BtTaskId('missing-priority-task'),
      streamId: const VirtualMediaStreamId('runtime-priority-task::0'),
      profile: profile,
    ),
  );
  _expect(
      missingMetadata.failure?.kind ==
          PiecePriorityPlanFailureKind.metadataUnavailable,
      'Missing scheduler metadata must report typed failures.');
}

Future<void> _verifyTimelineOverlayContract() async {
  final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
  final DateTime observedAt = DateTime.utc(2026, 6, 6, 12);
  final DeterministicTimelineOverlayStore store =
      DeterministicTimelineOverlayStore();
  await store.storeProfile(StoredTimelineOverlayProfileRecord(
    id: 'runtime-overlay',
    displayName: 'Runtime Overlay',
    isDefault: true,
    createdAt: observedAt,
    updatedAt: observedAt,
  ));
  await store.setActiveProfile(StoredActiveTimelineOverlayProfileRecord(
    streamId: 'runtime-overlay-stream',
    profileId: 'runtime-overlay',
    selectedAt: observedAt,
  ));
  await store.storeLayers(
    profileId: 'runtime-overlay',
    layers: <StoredTimelineOverlayLayerRecord>[
      StoredTimelineOverlayLayerRecord(
        profileId: 'runtime-overlay',
        layerId: 'playback-progress',
        kind: StoredTimelineOverlayLayerKind.playbackProgress,
        visible: true,
        order: 0,
        updatedAt: observedAt,
      ),
      StoredTimelineOverlayLayerRecord(
        profileId: 'runtime-overlay',
        layerId: 'priority-windows',
        kind: StoredTimelineOverlayLayerKind.priorityWindow,
        visible: true,
        order: 1,
        updatedAt: observedAt,
      ),
    ],
  );

  final DeterministicTimelineOverlayComposer composer =
      DeterministicTimelineOverlayComposer(
    cacheInvalidationBus: bus,
    clock: () => observedAt,
  );
  final Future<CacheInvalidationEvent> refreshedEvent = bus.events.first;
  final TimelineOverlayCompositionOutcome composed = composer.compose(
    TimelineOverlayCompositionInput(
      stream: const VirtualMediaStreamDescriptor(
        id: VirtualMediaStreamId('runtime-overlay-stream'),
        taskId: BtTaskId('runtime-overlay-task'),
        fileIndex: BtFileIndex(0),
        lengthBytes: 4096,
      ),
      playback: TimelinePlaybackSnapshot(
        position: Duration(seconds: 15),
        duration: Duration(minutes: 1),
      ),
      bufferedRanges: const <StreamBufferedRange>[
        StreamBufferedRange(
          mediaId: 'runtime-overlay-stream',
          range: BufferedRange(startByte: 0, endByte: 1023),
        ),
      ],
      pieces: const <TimelinePieceSegment>[
        TimelinePieceSegment(
          pieceIndex: BtPieceIndex(0),
          state: TimelinePieceState.buffered,
          byteRange: TimelineByteRange(
            streamId: VirtualMediaStreamId('runtime-overlay-stream'),
            range: BtByteRange(start: 0, endInclusive: 1023),
          ),
        ),
      ],
      priorityWindows: const <TimelinePriorityWindow>[
        TimelinePriorityWindow(
          id: 'runtime-priority-window',
          pieceIndex: BtPieceIndex(0),
          byteRange: TimelineByteRange(
            streamId: VirtualMediaStreamId('runtime-overlay-stream'),
            range: BtByteRange(start: 0, endInclusive: 1023),
          ),
          priority: 'critical',
          reason: 'playbackWindow',
        ),
      ],
    ),
  );
  final CacheInvalidationEvent deliveredRefresh = await refreshedEvent;
  _expect(composed.isSuccess, 'Timeline overlay must compose snapshots.');
  _expect(composed.snapshot?.buffered.single.end == const Duration(seconds: 15),
      'Timeline overlay must project byte ranges onto playback time.');
  _expect(composed.snapshot?.priorityWindows.single.priority == 'critical',
      'Timeline overlay must expose priority windows as read models.');
  _expect(deliveredRefresh is TimelineOverlaySnapshotRefreshed,
      'Timeline overlay refresh must publish invalidation.');

  await store
      .recordSnapshotMetadata(StoredTimelineOverlaySnapshotMetadataRecord(
    streamId: 'runtime-overlay-stream',
    profileId: 'runtime-overlay',
    positionMillis: composed.snapshot!.position.inMilliseconds,
    durationMillis: composed.snapshot!.duration.inMilliseconds,
    layerCount: composed.snapshot!.layers.length,
    composedAt: observedAt,
  ));
  _expect((await store.layersForProfile('runtime-overlay')).first.order == 0,
      'Timeline overlay layers must persist in order.');
  _expect(
      (await store.latestSnapshotMetadata('runtime-overlay-stream'))
              ?.layerCount ==
          composed.snapshot!.layers.length,
      'Timeline overlay snapshot metadata must persist.');

  final Future<CacheInvalidationEvent> rejectedEvent = bus.events.first;
  final TimelineOverlayCompositionOutcome rejected = composer.compose(
    TimelineOverlayCompositionInput(
      stream: const VirtualMediaStreamDescriptor(
        id: VirtualMediaStreamId('runtime-overlay-stream'),
        taskId: BtTaskId('runtime-overlay-task'),
        fileIndex: BtFileIndex(0),
        lengthBytes: 4096,
      ),
      playback: TimelinePlaybackSnapshot(
          position: Duration.zero, duration: Duration.zero),
    ),
  );
  final CacheInvalidationEvent deliveredRejection = await rejectedEvent;
  await bus.close();
  _expect(
      rejected.failure?.kind ==
          TimelineOverlayCompositionFailureKind.durationUnavailable,
      'Timeline overlay must return typed composition failures.');
  _expect(deliveredRejection is TimelineOverlayCompositionRejected,
      'Timeline overlay rejection must publish invalidation.');
}

Future<void> _verifyVideoEnhancementPipelineContract() async {
  final DateTime observedAt = DateTime.utc(2026, 6, 6, 12);
  final DeterministicEnhancementProfileStore store =
      DeterministicEnhancementProfileStore();
  await store.storeProfile(StoredEnhancementProfileRecord(
    id: 'runtime-enhancement',
    label: 'Runtime Enhancement',
    scalerIntent: VideoScalerIntent.animeOptimized.name,
    hdrHandlingIntent: HdrHandlingIntent.toneMapToSdr.name,
    debandIntent: DebandIntent.medium.name,
    anime4kPresetIntent: Anime4kPresetIntent.restore.name,
    isBuiltIn: true,
    createdAt: observedAt,
    updatedAt: observedAt,
  ));
  await store.setActiveProfile(StoredActiveEnhancementProfileRecord(
    scopeId: 'runtime-adapter',
    profileId: 'runtime-enhancement',
    selectedAt: observedAt,
  ));
  _expect(
      (await store.findProfileById('runtime-enhancement'))?.isBuiltIn == true,
      'Enhancement profiles must persist built-in metadata.');
  _expect(
      (await store.activeProfile('runtime-adapter'))?.profileId ==
          'runtime-enhancement',
      'Active enhancement profiles must persist.');

  final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
  final DeterministicVideoEnhancementPipeline pipeline =
      DeterministicVideoEnhancementPipeline(
    profileStore: store,
    capabilities: PlaybackCapabilityMatrix(
      capabilities: <PlaybackCapability, CapabilityStatus>{
        PlaybackCapability.videoEnhancement: const CapabilityStatus.supported(),
        PlaybackCapability.hdrToneMapping: const CapabilityStatus.supported(),
        PlaybackCapability.debandFiltering: const CapabilityStatus.supported(),
        PlaybackCapability.anime4kPreset: const CapabilityStatus.supported(),
      },
    ),
    cacheInvalidationBus: bus,
    scopeId: 'runtime-adapter',
    clock: () => observedAt,
  );
  final VideoEnhancementProfile profile = _runtimeEnhancementProfile();
  final Future<CacheInvalidationEvent> evaluationEvent = bus.events.first;
  final EnhancementEvaluationOutcome evaluation =
      await pipeline.evaluate(profile);
  final CacheInvalidationEvent deliveredEvaluation = await evaluationEvent;
  _expect(evaluation.isSuccess && evaluation.report?.supported == true,
      'Supported enhancement profiles must evaluate successfully.');
  _expect(deliveredEvaluation is EnhancementCapabilityReevaluated,
      'Enhancement evaluation must publish invalidation.');

  final Future<List<CacheInvalidationEvent>> applyEvents =
      bus.events.take(2).toList();
  final EnhancementApplyOutcome applied = await pipeline.apply(profile);
  final List<CacheInvalidationEvent> deliveredApplyEvents = await applyEvents;
  _expect(applied.isSuccess, 'Supported enhancement profiles must apply.');
  _expect(
      (await store.latestPipelineState('runtime-adapter'))?.state ==
          StoredEnhancementPipelineStateKind.applied,
      'Enhancement apply must persist pipeline state.');
  _expect(
      deliveredApplyEvents.whereType<EnhancementProfileChanged>().length == 1,
      'Enhancement apply must publish profile invalidation.');
  _expect(
      deliveredApplyEvents
              .whereType<EnhancementPipelineStateChanged>()
              .length ==
          1,
      'Enhancement apply must publish state invalidation.');

  final EnhancementDegradationOutcome degradation =
      await pipeline.requestDegradation(EnhancementDegradationRequest(
    profile: profile,
    renderBudget: const RenderBudgetInput(
      frameBudget: Duration(milliseconds: 16),
      estimatedRenderCost: Duration(milliseconds: 24),
      droppedFrames: 1,
    ),
    candidateTargets: <VideoEnhancementProfile>[
      _runtimeLightEnhancementProfile()
    ],
  ));
  _expect(degradation.snapshot?.isOverBudget == true,
      'Enhancement degradation requests must expose budget pressure.');
  _expect(degradation.snapshot?.degradationTarget?.id.value == 'runtime-light',
      'Enhancement degradation must expose candidate targets.');

  final EnhancementEvaluationOutcome unsupported =
      await DeterministicVideoEnhancementPipeline(
    profileStore: DeterministicEnhancementProfileStore(),
    capabilities: PlaybackCapabilityMatrix(
      capabilities: <PlaybackCapability, CapabilityStatus>{
        PlaybackCapability.videoEnhancement: const CapabilityStatus.supported(),
        PlaybackCapability.hdrToneMapping:
            const CapabilityStatus.unsupported('Runtime HDR unsupported.'),
        PlaybackCapability.debandFiltering:
            const CapabilityStatus.unsupported('Runtime deband unsupported.'),
        PlaybackCapability.anime4kPreset:
            const CapabilityStatus.unsupported('Runtime Anime4K unsupported.'),
      },
    ),
  ).evaluate(profile);
  await bus.close();
  _expect(unsupported.report?.supported == false,
      'Unsupported enhancement components must be rejected deterministically.');
  _expect(unsupported.report?.unsupportedComponents.length == 3,
      'Enhancement rejection must include component reasons.');
}

Future<void> _verifyAVSyncGuardContract() async {
  final DateTime observedAt = DateTime.utc(2026, 6, 6, 12);
  final DeterministicAVSyncGuardStore store = DeterministicAVSyncGuardStore();
  await store.storePolicy(StoredAVSyncPolicyRecord(
    id: 'runtime-av-sync',
    targetDriftMillis: 40,
    warningDriftMillis: 80,
    degradationDriftMillis: 120,
    recoveryDriftMillis: 60,
    sampleWindowSize: 3,
    degradationOrder: <String>[
      AVSyncDegradationAction.reduceEnhancementIntensity.name,
      AVSyncDegradationAction.disableAdvancedCaptions.name,
      AVSyncDegradationAction.disableEnhancementProfile.name,
    ],
    updatedAt: observedAt,
  ));
  _expect((await store.activePolicy('runtime-av-sync'))?.sampleWindowSize == 3,
      'AV sync policy must persist sample window configuration.');

  final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
  final DeterministicAVSyncGuard guard = DeterministicAVSyncGuard(
    policy: AVSyncPolicy(),
    guardStore: store,
    capabilities: _runtimeAVSyncCapabilities(),
    cacheInvalidationBus: bus,
    scopeId: 'runtime-av-sync',
    clock: () => observedAt,
  );
  final Future<List<CacheInvalidationEvent>> sampleEvents =
      bus.events.take(4).toList();
  await guard.ingestSample(_runtimeAVSyncSample(130));
  await guard.ingestSample(_runtimeAVSyncSample(130));
  final AVSyncEvaluationOutcome degraded =
      await guard.ingestSample(_runtimeAVSyncSample(140));
  final List<CacheInvalidationEvent> deliveredSamples = await sampleEvents;

  _expect(degraded.decision?.health == AVSyncHealth.degraded,
      'Sustained AV drift must enter degraded health.');
  _expect(
      (await store.latestHealth('runtime-av-sync'))?.health ==
          StoredAVSyncHealthKind.degraded,
      'AV sync health must persist after evaluation.');
  _expect(deliveredSamples.whereType<AVSyncSampleIngested>().length == 3,
      'AV sync sample ingestion must publish invalidation.');
  _expect(deliveredSamples.whereType<AVSyncHealthTransitioned>().isNotEmpty,
      'AV sync health transitions must publish invalidation.');

  final Future<CacheInvalidationEvent> decisionEvent = bus.events.first;
  final AVSyncDegradationRequestOutcome decision =
      await guard.requestDegradation(
    _runtimeAVSyncSample(140, enhancementOverBudget: true),
  );
  final CacheInvalidationEvent deliveredDecision = await decisionEvent;
  _expect(
      decision.decision?.action ==
          AVSyncDegradationAction.reduceEnhancementIntensity,
      'AV sync degradation must prefer enhancement actions for budget pressure.');
  _expect(deliveredDecision is AVSyncDegradationDecisionRecorded,
      'AV sync degradation decisions must publish invalidation.');

  await guard.ingestSample(_runtimeAVSyncSample(20));
  await guard.ingestSample(_runtimeAVSyncSample(20));
  await guard.ingestSample(_runtimeAVSyncSample(20));
  final AVSyncRecoveryOutcome recovery = await guard.checkRecovery();
  await bus.close();
  await guard.close();
  _expect(recovery.decision?.health == AVSyncHealth.target,
      'AV sync guard must recover after sustained low drift.');

  final AVSyncEvaluationOutcome unsupported = await DeterministicAVSyncGuard(
    policy: AVSyncPolicy(),
    guardStore: DeterministicAVSyncGuardStore(),
    capabilities: PlaybackCapabilityMatrix(
      capabilities: <PlaybackCapability, CapabilityStatus>{
        PlaybackCapability.avSyncGuard:
            const CapabilityStatus.unsupported('Runtime AV sync unsupported.'),
      },
    ),
  ).ingestSample(_runtimeAVSyncSample(0));
  _expect(
      unsupported.failure?.kind == AVSyncGuardFailureKind.capabilityUnsupported,
      'Unsupported AVSyncGuard capability must return a typed failure.');
}

Future<void> _verifyAdvancedCaptionRenderingContract() async {
  final DateTime observedAt = DateTime.utc(2026, 6, 7, 12);
  final DeterministicAdvancedCaptionStore store =
      DeterministicAdvancedCaptionStore();
  await store.storeProfile(StoredAdvancedCaptionProfileRecord(
    id: 'runtime-captions',
    label: 'Runtime Captions',
    matrixDanmakuEnabled: true,
    dualSubtitlesEnabled: true,
    pgsRenderingEnabled: true,
    assEnhancementEnabled: true,
    primarySubtitleLanguageCode: 'ja',
    secondarySubtitleLanguageCode: 'en',
    isBuiltIn: true,
    createdAt: observedAt,
    updatedAt: observedAt,
  ));
  _expect((await store.findProfileById('runtime-captions'))?.isBuiltIn == true,
      'Advanced caption profiles must persist built-in metadata.');

  final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
  final DeterministicAdvancedCaptionRenderer renderer =
      DeterministicAdvancedCaptionRenderer(
    captionStore: store,
    capabilityMatrix: _runtimeAdvancedCaptionCapabilities(),
    profile: _runtimeAdvancedCaptionProfile(),
    cacheInvalidationBus: bus,
    scopeId: 'runtime-captions',
    clock: () => observedAt,
  );

  final Future<List<CacheInvalidationEvent>> evaluationEvents =
      bus.events.take(2).toList();
  final CaptionEvaluationOutcome evaluation =
      await renderer.evaluate(_runtimeAdvancedCaptionProfile());
  final List<CacheInvalidationEvent> deliveredEvaluationEvents =
      await evaluationEvents;
  _expect(evaluation.isSuccess && evaluation.report?.supported == true,
      'Supported advanced caption profiles must evaluate successfully.');
  _expect(
      deliveredEvaluationEvents
              .whereType<AdvancedCaptionCapabilityReevaluated>()
              .length ==
          1,
      'Advanced caption evaluation must publish capability invalidation.');

  final Future<List<CacheInvalidationEvent>> dualSubtitleEvents =
      bus.events.take(3).toList();
  final CaptionRenderOutcome dualSubtitleRender =
      await renderer.renderDualSubtitles(DualSubtitleRequest(
    primary: _runtimeSubtitle('runtime-subtitle-ja', 'ja'),
    secondary: _runtimeSubtitle('runtime-subtitle-en', 'en'),
  ));
  final List<CacheInvalidationEvent> deliveredDualSubtitleEvents =
      await dualSubtitleEvents;
  _expect(dualSubtitleRender.isSuccess,
      'Supported dual subtitles must render as a typed success.');
  _expect(
      (await store.dualSubtitleSelection('runtime-captions'))
              ?.primarySubtitleId ==
          'runtime-subtitle-ja',
      'Advanced captions must persist ordered primary subtitle selection.');
  _expect(
      deliveredDualSubtitleEvents
              .whereType<AdvancedCaptionDualSubtitleSelectionChanged>()
              .length ==
          1,
      'Dual subtitle selection must publish invalidation.');

  final CaptionRenderOutcome pgsRejected =
      await DeterministicAdvancedCaptionRenderer(
    captionStore: DeterministicAdvancedCaptionStore(),
    capabilityMatrix: PlaybackCapabilityMatrix(
      capabilities: <PlaybackCapability, CapabilityStatus>{
        PlaybackCapability.matrixDanmaku: const CapabilityStatus.supported(),
        PlaybackCapability.dualSubtitles: const CapabilityStatus.supported(),
        PlaybackCapability.pgsSubtitleRendering:
            const CapabilityStatus.unsupported('Runtime PGS unsupported.'),
        PlaybackCapability.assSubtitleEnhancement:
            const CapabilityStatus.supported(),
      },
    ),
    profile: _runtimeAdvancedCaptionProfile(),
  ).renderAdvancedSubtitle(AdvancedSubtitleRequest(
    source: _runtimeSubtitle('runtime-subtitle-pgs', 'ja'),
    intent: AdvancedSubtitleRenderIntent.pgsImageSubtitle,
  ));
  _expect(
      pgsRejected.failure?.kind ==
          AdvancedCaptionFailureKind.capabilityUnsupported,
      'Unsupported PGS rendering must return a typed capability failure.');

  final Future<List<CacheInvalidationEvent>> degradationEvents =
      bus.events.take(2).toList();
  final CaptionDegradationOutcome degradation =
      await renderer.acceptDegradation(
    AVSyncDegradationAction.disableAdvancedCaptions,
    reason: 'Runtime AV drift exceeded red line.',
  );
  final List<CacheInvalidationEvent> deliveredDegradationEvents =
      await degradationEvents;
  await bus.close();
  _expect(degradation.isSuccess,
      'disableAdvancedCaptions must be accepted as declarative input.');
  _expect(
      (await store.latestRendererState('runtime-captions'))?.state ==
          StoredAdvancedCaptionRendererStateKind.degraded,
      'Advanced caption degradation must persist renderer state.');
  _expect(
      deliveredDegradationEvents
              .whereType<AdvancedCaptionDegradationStateChanged>()
              .length ==
          1,
      'Advanced caption degradation must publish invalidation.');
}

Future<void> _verifyFallbackAdapterContract() async {
  final DateTime observedAt = DateTime.utc(2026, 6, 7, 12);
  final DeterministicFallbackAdapterStore store =
      DeterministicFallbackAdapterStore();
  final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
  final DeterministicPlaybackFallbackStrategy strategy =
      DeterministicPlaybackFallbackStrategy(
    store: store,
    cacheInvalidationBus: bus,
    scopeId: 'runtime-fallback',
    clock: () => observedAt,
  );
  final FallbackAdapterCandidate candidate = _runtimeFallbackCandidate(
    id: 'runtime-fallback-adapter',
    capabilities: _runtimeFallbackCapabilities(),
  );
  final Future<List<CacheInvalidationEvent>> selectionEvents =
      bus.events.take(3).toList();
  final FallbackRegistrationOutcome registered =
      await strategy.register(candidate);
  final FallbackEvaluationOutcome selected = await strategy.selectFallback(
    source: _localSource(),
    failure: const FallbackFailure(
      kind: FallbackFailureKind.loadFailure,
      message: 'Runtime primary adapter load failed.',
    ),
  );
  final List<CacheInvalidationEvent> deliveredSelectionEvents =
      await selectionEvents;
  _expect(registered.isSuccess,
      'Fallback registration must return a typed success outcome.');
  _expect(selected.isSuccess,
      'Fallback selection must return a typed selection outcome.');
  _expect(selected.selection?.candidate.id.value == 'runtime-fallback-adapter',
      'Fallback selection must preserve the selected candidate id.');
  _expect(
      selected.selection?.hiddenCapabilities
              .containsKey(PlaybackCapability.anime4kPreset) ==
          true,
      'Fallback selection must expose hidden unsupported capabilities.');
  _expect(
      (await store.activeConfiguration('runtime-fallback'))
              ?.selectedCandidateId ==
          'runtime-fallback-adapter',
      'Fallback selection must persist active configuration.');
  _expect((await store.selectionHistory('runtime-fallback')).isNotEmpty,
      'Fallback selection must persist selection history.');
  _expect(
      deliveredSelectionEvents
              .whereType<FallbackAdapterRegistrationChanged>()
              .length ==
          1,
      'Fallback registration must publish invalidation.');
  _expect(
      deliveredSelectionEvents
              .whereType<FallbackStrategyStateChanged>()
              .length ==
          1,
      'Fallback state changes must publish invalidation.');
  _expect(
      deliveredSelectionEvents.whereType<FallbackSelectionChanged>().length ==
          1,
      'Fallback selection changes must publish invalidation.');

  final Future<CacheInvalidationEvent> capabilityEvent = bus.events.first;
  final FallbackCapabilityReevaluationOutcome reevaluated =
      await strategy.reevaluateCapabilities(
          const FallbackAdapterId('runtime-fallback-adapter'));
  final CacheInvalidationEvent deliveredCapabilityEvent = await capabilityEvent;
  _expect(reevaluated.readModel?.hidesAnyCapability == true,
      'Fallback capability reevaluation must expose hidden capabilities.');
  _expect(deliveredCapabilityEvent is FallbackCapabilityReevaluated,
      'Fallback capability reevaluation must publish invalidation.');

  final FallbackEvaluationOutcome noCandidate =
      await DeterministicPlaybackFallbackStrategy(
    store: DeterministicFallbackAdapterStore(),
  ).selectFallback(
    source: _localSource(),
    failure: const FallbackFailure(
      kind: FallbackFailureKind.loadFailure,
      message: 'Runtime primary adapter load failed.',
    ),
  );
  _expect(
      noCandidate.failure?.kind == FallbackEvaluationFailureKind.noCandidate,
      'Missing fallback candidates must return a typed no-candidate failure.');

  final DeterministicPlaybackFallbackStrategy disabledStrategy =
      DeterministicPlaybackFallbackStrategy(
    store: DeterministicFallbackAdapterStore(),
  );
  await disabledStrategy.register(_runtimeFallbackCandidate(
    id: 'runtime-disabled-fallback',
    capabilities: _runtimeFallbackCapabilities(),
  ));
  await disabledStrategy.disable();
  final FallbackEvaluationOutcome disabledSelection =
      await disabledStrategy.selectFallback(
    source: _localSource(),
    failure: const FallbackFailure(
      kind: FallbackFailureKind.loadFailure,
      message: 'Runtime primary adapter load failed.',
    ),
  );
  await bus.close();
  _expect(
      disabledSelection.failure?.kind == FallbackEvaluationFailureKind.disabled,
      'Disabled fallback must return a typed disabled failure.');
}

void _verifySurfaceStateFromCapabilities() {
  final PlaybackSurfaceState transportState = PlaybackController(
    adapterResolver: _StaticAdapterResolver(
      _ConfigurablePlayerAdapter(
        capabilities: PlaybackCapabilityMatrix(
          capabilities: <PlaybackCapability, CapabilityStatus>{
            PlaybackCapability.playPause: CapabilityStatus.supported(),
            PlaybackCapability.seek: CapabilityStatus.supported(),
            PlaybackCapability.stop: CapabilityStatus.supported(),
            PlaybackCapability.progressReporting: CapabilityStatus.supported(),
          },
        ),
      ),
    ),
  ).resolveSurfaceState();

  _expect(
      transportState.visibleControls.contains(PlaybackSurfaceControl.playPause),
      'Transport state must expose play/pause.');
  _expect(transportState.visibleControls.contains(PlaybackSurfaceControl.seek),
      'Transport state must expose seek.');
  _expect(transportState.visibleControls.contains(PlaybackSurfaceControl.stop),
      'Transport state must expose stop.');
  _expect(
      transportState.visibleControls.contains(PlaybackSurfaceControl.progress),
      'Transport state must expose progress.');
  _expect(
      !transportState.visibleControls
          .contains(PlaybackSurfaceControl.audioTracks),
      'Transport-only state must hide audio tracks.');
  _expect(
      !transportState.visibleControls
          .contains(PlaybackSurfaceControl.subtitleTracks),
      'Transport-only state must hide subtitle tracks.');
  _expect(transportState.availablePanels.isEmpty,
      'Transport-only state must not expose secondary panels.');

  final PlaybackSurfaceState trackState = PlaybackController(
    adapterResolver: _StaticAdapterResolver(
      _ConfigurablePlayerAdapter(
        capabilities: PlaybackCapabilityMatrix(
          capabilities: <PlaybackCapability, CapabilityStatus>{
            PlaybackCapability.audioTrackSwitching:
                CapabilityStatus.supported(),
            PlaybackCapability.subtitleTrackSwitching:
                CapabilityStatus.supported(),
            PlaybackCapability.secondaryPanels: CapabilityStatus.supported(),
          },
        ),
      ),
    ),
  ).resolveSurfaceState();

  _expect(
      trackState.visibleControls.contains(PlaybackSurfaceControl.audioTracks),
      'Track state must expose audio track control.');
  _expect(
      trackState.visibleControls
          .contains(PlaybackSurfaceControl.subtitleTracks),
      'Track state must expose subtitle track control.');
  _expect(trackState.availablePanels.contains(PlaybackSurfacePanel.tracks),
      'Track state must expose tracks panel.');
}

void _verifyPlaybackPageSurfaceContract() {
  final PlaybackPageSurfaceDescriptor transportSurface = PlaybackPageContract(
    controller: PlaybackController(
      adapterResolver: _StaticAdapterResolver(
        _ConfigurablePlayerAdapter(
          capabilities: PlaybackCapabilityMatrix(
            capabilities: <PlaybackCapability, CapabilityStatus>{
              PlaybackCapability.playPause: CapabilityStatus.supported(),
              PlaybackCapability.seek: CapabilityStatus.supported(),
              PlaybackCapability.stop: CapabilityStatus.supported(),
              PlaybackCapability.progressReporting:
                  CapabilityStatus.supported(),
            },
          ),
        ),
      ),
    ),
  ).resolveSurface();

  _expect(transportSurface.hasActiveControl(PlaybackPageControlId.playPause),
      'Playback page surface must expose active play/pause control.');
  _expect(transportSurface.hasActiveControl(PlaybackPageControlId.seek),
      'Playback page surface must expose active seek control.');
  _expect(transportSurface.hasActiveControl(PlaybackPageControlId.stop),
      'Playback page surface must expose active stop control.');
  _expect(transportSurface.hasActiveControl(PlaybackPageControlId.progress),
      'Playback page surface must expose active progress control.');
  _expect(!transportSurface.hasActiveControl(PlaybackPageControlId.audioTracks),
      'Playback page surface must hide unsupported audio track control.');
  _expect(
      !transportSurface.hasActiveControl(PlaybackPageControlId.subtitleTracks),
      'Playback page surface must hide unsupported subtitle track control.');
  _expect(!transportSurface.hasActivePanel(PlaybackPagePanelId.tracks),
      'Playback page surface must hide unsupported tracks panel.');

  final PlaybackPageSurfaceDescriptor trackSurface = PlaybackPageContract(
    controller: PlaybackController(
      adapterResolver: _StaticAdapterResolver(
        _ConfigurablePlayerAdapter(
          capabilities: PlaybackCapabilityMatrix(
            capabilities: <PlaybackCapability, CapabilityStatus>{
              PlaybackCapability.audioTrackSwitching:
                  CapabilityStatus.supported(),
              PlaybackCapability.subtitleTrackSwitching:
                  CapabilityStatus.supported(),
              PlaybackCapability.secondaryPanels: CapabilityStatus.supported(),
            },
          ),
        ),
      ),
    ),
  ).resolveSurface();

  _expect(trackSurface.hasActiveControl(PlaybackPageControlId.audioTracks),
      'Playback page surface must expose supported audio track control.');
  _expect(trackSurface.hasActiveControl(PlaybackPageControlId.subtitleTracks),
      'Playback page surface must expose supported subtitle track control.');
  _expect(trackSurface.hasActivePanel(PlaybackPagePanelId.tracks),
      'Playback page surface must expose supported tracks panel.');
}

Future<void> _verifyPlaybackPageIntentContract() async {
  final _ConfigurablePlayerAdapter supportedAdapter =
      _ConfigurablePlayerAdapter(
    capabilities: PlaybackCapabilityMatrix(
      capabilities: <PlaybackCapability, CapabilityStatus>{
        PlaybackCapability.playPause: CapabilityStatus.supported(),
        PlaybackCapability.seek: CapabilityStatus.supported(),
        PlaybackCapability.stop: CapabilityStatus.supported(),
        PlaybackCapability.audioTrackSwitching: CapabilityStatus.supported(),
        PlaybackCapability.secondaryPanels: CapabilityStatus.supported(),
      },
    ),
  );
  final PlaybackPageContract supportedContract = PlaybackPageContract(
    controller: PlaybackController(
        adapterResolver: _StaticAdapterResolver(supportedAdapter)),
  );

  _expectIntentOutcome(
    await supportedContract.dispatch(const PlaybackPageIntent.play()),
    PlaybackPageIntentOutcome.executed,
  );
  _expectIntentOutcome(
    await supportedContract.dispatch(const PlaybackPageIntent.pause()),
    PlaybackPageIntentOutcome.executed,
  );
  _expectIntentOutcome(
    await supportedContract
        .dispatch(const PlaybackPageIntent.seek(Duration(seconds: 32))),
    PlaybackPageIntentOutcome.executed,
  );
  _expectIntentOutcome(
    await supportedContract.dispatch(const PlaybackPageIntent.stop()),
    PlaybackPageIntentOutcome.executed,
  );

  final PlaybackPageIntentResult panelResult = await supportedContract.dispatch(
    const PlaybackPageIntent.openPanel(PlaybackPagePanelId.tracks),
  );
  _expectIntentOutcome(panelResult, PlaybackPageIntentOutcome.executed);
  _expect(panelResult.panelId == PlaybackPagePanelId.tracks,
      'Open-panel intent must preserve panel id.');

  final PlaybackPageIntentResult trackResult = await supportedContract.dispatch(
    const PlaybackPageIntent.selectTrack(
      trackId: DomainMediaTrackId('audio-main'),
      trackType: DomainMediaTrackType.audio,
    ),
  );
  _expectIntentOutcome(trackResult, PlaybackPageIntentOutcome.executed);
  _expect(trackResult.trackSwitchResult?.isSuccess ?? false,
      'Track intent must preserve switch result.');

  _expect(supportedAdapter.playCount == 1,
      'Play intent must dispatch through PlaybackController.play.');
  _expect(supportedAdapter.pauseCount == 1,
      'Pause intent must dispatch through PlaybackController.pause.');
  _expect(supportedAdapter.seekCount == 1,
      'Seek intent must dispatch through PlaybackController.seek.');
  _expect(supportedAdapter.stopCount == 1,
      'Stop intent must dispatch through PlaybackController.stop.');
  _expect(supportedAdapter.switchCount == 1,
      'Track intent must dispatch through PlaybackController.switchTrack.');
  _expect(supportedAdapter.switchedTrackId?.value == 'audio-main',
      'Track intent must use Domain-facing track id.');

  final _ConfigurablePlayerAdapter unsupportedAdapter =
      _ConfigurablePlayerAdapter(
    capabilities: PlaybackCapabilityMatrix(
      capabilities: <PlaybackCapability, CapabilityStatus>{
        PlaybackCapability.playPause: CapabilityStatus.supported(),
      },
    ),
  );
  final PlaybackPageContract unsupportedContract = PlaybackPageContract(
    controller: PlaybackController(
        adapterResolver: _StaticAdapterResolver(unsupportedAdapter)),
  );

  _expectIntentOutcome(
    await unsupportedContract
        .dispatch(const PlaybackPageIntent.seek(Duration(seconds: 4))),
    PlaybackPageIntentOutcome.unsupported,
  );
  _expectIntentOutcome(
    await unsupportedContract.dispatch(
        const PlaybackPageIntent.openPanel(PlaybackPagePanelId.tracks)),
    PlaybackPageIntentOutcome.unsupported,
  );
  _expectIntentOutcome(
    await unsupportedContract.dispatch(
      const PlaybackPageIntent.selectTrack(
        trackId: DomainMediaTrackId('subtitle-ja'),
        trackType: DomainMediaTrackType.subtitle,
      ),
    ),
    PlaybackPageIntentOutcome.unsupported,
  );
  _expectIntentOutcome(
    await unsupportedContract.dispatch(const PlaybackPageIntent.noop()),
    PlaybackPageIntentOutcome.ignored,
  );

  _expect(unsupportedAdapter.seekCount == 0,
      'Unsupported seek intent must not delegate to adapter.');
  _expect(unsupportedAdapter.switchCount == 0,
      'Unsupported track intent must not delegate to adapter.');
}

void _verifyPlaybackStateContract() {
  final DateTime observedAt = DateTime.utc(2026, 6, 3, 10, 0);
  final PlaybackStateSnapshot pausedSnapshot = PlaybackStateSnapshot(
    status: PlaybackLifecycleStatus.paused,
    timeline: PlaybackTimelineState(
      position: const Duration(minutes: 12, seconds: 4),
      duration: const Duration(minutes: 24),
      observedAt: observedAt,
    ),
    activeTracks: const ActivePlaybackTrackState(
      audioTrackId: DomainMediaTrackId('audio-main'),
      subtitleTrackId: DomainMediaTrackId('subtitle-ja'),
    ),
    sourceUri: Uri.parse('file:///D:/media/example.mkv'),
  );

  _expect(pausedSnapshot.status == PlaybackLifecycleStatus.paused,
      'Playback state must preserve lifecycle status.');
  _expect(
      pausedSnapshot.timeline.position ==
          const Duration(minutes: 12, seconds: 4),
      'Playback state must preserve timeline position.');
  _expect(pausedSnapshot.timeline.duration == const Duration(minutes: 24),
      'Playback state must preserve timeline duration.');
  _expect(pausedSnapshot.timeline.observedAt == observedAt,
      'Playback state must preserve timeline observation timestamp.');
  _expect(pausedSnapshot.activeTracks.audioTrackId?.value == 'audio-main',
      'Playback state must preserve active audio track id.');
  _expect(pausedSnapshot.activeTracks.subtitleTrackId?.value == 'subtitle-ja',
      'Playback state must preserve active subtitle track id.');

  const PlaybackStateSnapshot bufferingSnapshot = PlaybackStateSnapshot(
    status: PlaybackLifecycleStatus.buffering,
    buffering: PlaybackBufferingState(
      isBuffering: true,
      bufferedPosition: Duration(minutes: 14),
      bufferedFraction: 0.58,
    ),
  );
  _expect(bufferingSnapshot.buffering.isBuffering,
      'Playback state must represent buffering as data.');
  _expect(
      bufferingSnapshot.buffering.bufferedPosition ==
          const Duration(minutes: 14),
      'Playback state must preserve buffered position.');
  _expect(bufferingSnapshot.buffering.bufferedFraction == 0.58,
      'Playback state must preserve buffered fraction.');

  final _ManualPlaybackStateObservable observable =
      _ManualPlaybackStateObservable(
    initialState:
        const PlaybackStateSnapshot(status: PlaybackLifecycleStatus.idle),
  );
  final _RecordingPlaybackStateObserver observer =
      _RecordingPlaybackStateObserver();
  observable.addPlaybackStateObserver(observer);
  observable.publish(pausedSnapshot);
  _expect(observable.currentState == pausedSnapshot,
      'Playback state observable must expose the current snapshot.');
  _expect(observer.snapshots.single == pausedSnapshot,
      'Playback state observer must receive published snapshots.');

  observable.removePlaybackStateObserver(observer);
  observable.publish(bufferingSnapshot);
  _expect(observer.snapshots.length == 1,
      'Removed playback state observer must not receive snapshots.');
}

void _verifyUndeclaredCapabilitiesRemainUnsupported() {
  final PlaybackCapabilityMatrix matrix = PlaybackCapabilityMatrix(
    capabilities: <PlaybackCapability, CapabilityStatus>{
      PlaybackCapability.playPause: CapabilityStatus.supported(),
    },
  );

  final CapabilityStatus status =
      matrix.statusOf(PlaybackCapability.hlsPlayback);
  _expect(!status.isSupported, 'Undeclared capability must be unsupported.');
  _expect(status.reason != null && status.reason!.isNotEmpty,
      'Undeclared capability must include a reason.');
}

Future<void> _verifyTrackRuntimeChecks() async {
  final _InMemoryMpvBinding binding = _InMemoryMpvBinding(tracks: _tracks);
  final PlaybackController controller = PlaybackController(
    adapterResolver:
        _StaticAdapterResolver(MpvPlayerAdapterFacade.bound(binding: binding)),
  );

  final TrackDiscoveryResult discovery = await controller.discoverTracks();
  _expect(discovery.tracks.length == 2,
      'Bound adapter must report normalized audio and subtitle tracks.');
  _expect(discovery.tracks.first.id.value == 'audio-main',
      'Audio track id must be stable.');
  _expect(discovery.tracks.first.type == MediaTrackType.audio,
      'First track must be audio.');
  _expect(discovery.tracks.last.type == MediaTrackType.subtitle,
      'Second track must be subtitle.');

  final TrackSwitchResult switchResult =
      await controller.switchTrack(const DomainMediaTrackId('subtitle-ja'));
  _expect(switchResult.isSuccess, 'Known track switch must succeed.');
  _expect(binding.switchedTrackId?.value == 'subtitle-ja',
      'Track switch must route through the binding.');

  final _ConfigurablePlayerAdapter unsupportedTrackAdapter =
      _ConfigurablePlayerAdapter(
    capabilities: PlaybackCapabilityMatrix(
      capabilities: <PlaybackCapability, CapabilityStatus>{
        PlaybackCapability.playPause: CapabilityStatus.supported(),
      },
    ),
  );
  final PlaybackController unsupportedTrackController = PlaybackController(
    adapterResolver: _StaticAdapterResolver(unsupportedTrackAdapter),
  );
  final PlaybackSurfaceState state =
      unsupportedTrackController.resolveSurfaceState();
  _expect(!state.visibleControls.contains(PlaybackSurfaceControl.audioTracks),
      'Unsupported audio track switching must be hidden.');
  _expect(
      !state.visibleControls.contains(PlaybackSurfaceControl.subtitleTracks),
      'Unsupported subtitle track switching must be hidden.');
  _expect(!state.availablePanels.contains(PlaybackSurfacePanel.tracks),
      'Unsupported track switching must hide tracks panel.');

  final TrackSwitchResult unsupportedSwitch = await unsupportedTrackController
      .switchTrack(const DomainMediaTrackId('subtitle-ja'));
  _expect(!unsupportedSwitch.isSuccess,
      'Controller must reject unsupported track switching before adapter delegation.');
  _expect(unsupportedTrackAdapter.switchCount == 0,
      'Controller must not delegate unsupported track switching.');
}

LocalFilePlaybackSource _localSource() {
  return LocalFilePlaybackSource(uri: Uri.file('D:/media/example.mkv'));
}

const List<MediaTrackDescriptor> _tracks = <MediaTrackDescriptor>[
  MediaTrackDescriptor(
    id: MediaTrackId('audio-main'),
    type: MediaTrackType.audio,
    label: 'Main Audio',
    languageCode: 'ja',
    isSelected: true,
  ),
  MediaTrackDescriptor(
    id: MediaTrackId('subtitle-ja'),
    type: MediaTrackType.subtitle,
    label: 'Japanese Subtitle',
    languageCode: 'ja',
  ),
];

Future<void> _verifyFoundationBootstrapContract() async {
  final DateTime observedAt = DateTime.utc(2026, 6, 8, 12);
  final FoundationBootstrap bootstrap = FoundationBootstrap();

  // Storage foundation is accessible and provides all 24 stores.
  final StorageFoundation storage = bootstrap.storage;
  final List<Object> foundationStores = <Object>[
    storage.metadata,
    storage.blobCache,
    storage.mediaCache,
    storage.settings,
    storage.mediaLibrary,
    storage.playbackHistory,
    storage.providerBinding,
    storage.subtitleCache,
    storage.rssFeed,
    storage.rssAutoDownloadPolicy,
    storage.onlineRuleRuntime,
    storage.webViewSessionBackfill,
    storage.networkPolicy,
    storage.diagnostics,
    storage.seasonalCatalog,
    storage.bangumiMatchQueue,
    storage.btTask,
    storage.virtualMediaStream,
    storage.piecePriorityScheduler,
    storage.timelineOverlay,
    storage.videoEnhancement,
    storage.avSyncGuard,
    storage.advancedCaptions,
    storage.fallbackAdapter,
  ];
  _expect(foundationStores.length == 24,
      "StorageFoundation must expose all 24 store contracts.");

  // Provider gateway is accessible and preserves registrations.
  final ProviderGateway gateway = bootstrap.gateway;
  await gateway.registerProvider(ProviderRegistration(
    providerId: const ProviderId("runtime-foundation-provider"),
    ratePolicy: const ProviderRatePolicy(
        maxRequests: 10, window: Duration(minutes: 1)),
    retryPolicy: const ProviderRetryPolicy(
        maxAttempts: 3, initialBackoff: Duration(seconds: 1)),
  ));

  final ProviderGatewayResponse<String> response =
      await gateway.execute<String>(ProviderGatewayRequest<String>(
    key: ProviderRequestKey(
      providerId: const ProviderId("runtime-foundation-provider"),
      cacheKey: "runtime-foundation-provider::test",
    ),
    load: () => Future<String>.value("runtime-foundation-result"),
    cachePolicy: ProviderCachePolicy.networkFirst,
    deduplicationWindow: const Duration(minutes: 1),
  ));
  _expect(response.value == "runtime-foundation-result",
      "ProviderGateway must execute supplied loaders.");
  _expect(response.source == ProviderGatewayResponseSource.network,
      "ProviderGateway must report network source for first execution.");

  // De-duplication preserves request outcomes.
  final ProviderGatewayResponse<String> deduped =
      await gateway.execute<String>(ProviderGatewayRequest<String>(
    key: ProviderRequestKey(
      providerId: const ProviderId("runtime-foundation-provider"),
      cacheKey: "runtime-foundation-provider::test",
    ),
    load: () => Future<String>.value("different-result"),
    deduplicationWindow: const Duration(minutes: 1),
  ));
  _expect(deduped.value == "runtime-foundation-result",
      "ProviderGateway must deduplicate matching request keys.");

  // Cache invalidation bus is accessible and lifecycle-managed.
  final CacheInvalidationBus invalidationBus = bootstrap.invalidationBus;
  _expect(identical(invalidationBus, bootstrap.invalidationBus),
      "FoundationBootstrap must expose a stable CacheInvalidationBus.");
  _expect(!bootstrap.isDisposed,
      "FoundationBootstrap must not be disposed before explicit dispose.");

  // Bus publishes payload-only events.
  final StreamCacheInvalidationBus bus =
      bootstrap.invalidationBus as StreamCacheInvalidationBus;
  final Future<List<CacheInvalidationEvent>> events =
      bus.events.take(2).toList();
  bus.publish(BindingChanged(
    occurredAt: observedAt,
    localMediaId: "runtime-foundation-media",
    providerId: "runtime-foundation-provider",
  ));
  bus.publish(HistoryRecorded(
    occurredAt: observedAt,
    localMediaId: "runtime-foundation-media",
  ));
  final List<CacheInvalidationEvent> delivered = await events;
  _expect(delivered.whereType<BindingChanged>().length == 1,
      "Bus must deliver binding change events.");
  _expect(delivered.whereType<HistoryRecorded>().length == 1,
      "Bus must deliver history events.");

  // Disposal rejects further publishes.
  await bootstrap.dispose();
  _expect(bootstrap.isDisposed,
      "FoundationBootstrap must report disposed after dispose.");
  _expect(
    _tryPublishAfterClose(bus, observedAt),
    "Bus must reject publishes after bootstrap dispose.",
  );

  // Layer manifest exposes 8-layer metadata.
  _expect(FoundationBootstrap.layerManifest.length == 8,
      "Foundation bootstrap must expose 8-layer manifest.");
  _expect(isLayerDependencyAllowed(from: LayerId.ui, to: LayerId.domain),
      "Layer manifest must allow UI->Domain dependency.");
  _expect(!isLayerDependencyAllowed(from: LayerId.ui, to: LayerId.playback),
      "Layer manifest must reject UI->Playback dependency.");
}

bool _tryPublishAfterClose(StreamCacheInvalidationBus bus, DateTime observedAt) {
  try {
    bus.publish(DanmakuPosted(
      occurredAt: observedAt,
      subjectId: "test",
      episodeId: "test",
    ));
    return false;
  } on StateError {
    return true;
  }
}
final class _StaticAdapterResolver implements ActivePlayerAdapterResolver {
  const _StaticAdapterResolver(this.activeAdapter);

  @override
  final PlayerAdapter activeAdapter;
}

final class _InMemoryMpvBinding implements MpvAdapterBinding {
  _InMemoryMpvBinding({required List<MediaTrackDescriptor> tracks})
      : _tracks = tracks;

  final List<MediaTrackDescriptor> _tracks;
  final List<PlaybackOperation> operations = <PlaybackOperation>[];
  PlaybackSource? loadedSource;
  MediaTrackId? switchedTrackId;

  @override
  Future<PlaybackCommandResult> load(PlaybackSource source) async {
    operations.add(PlaybackOperation.load);
    loadedSource = source;
    return const PlaybackCommandResult.success();
  }

  @override
  Future<PlaybackCommandResult> play() async {
    operations.add(PlaybackOperation.play);
    return const PlaybackCommandResult.success();
  }

  @override
  Future<PlaybackCommandResult> pause() async {
    operations.add(PlaybackOperation.pause);
    return const PlaybackCommandResult.success();
  }

  @override
  Future<PlaybackCommandResult> seek(Duration position) async {
    operations.add(PlaybackOperation.seek);
    return const PlaybackCommandResult.success();
  }

  @override
  Future<PlaybackCommandResult> stop() async {
    operations.add(PlaybackOperation.stop);
    return const PlaybackCommandResult.success();
  }

  @override
  Future<PlaybackCommandResult> dispose() async {
    operations.add(PlaybackOperation.dispose);
    return const PlaybackCommandResult.success();
  }

  @override
  Future<TrackDiscoveryResult> discoverTracks() async {
    operations.add(PlaybackOperation.discoverTracks);
    return TrackDiscoveryResult(
      tracks: _tracks,
      capabilityMatrix: PlaybackCapabilityMatrix(
        capabilities: <PlaybackCapability, CapabilityStatus>{
          PlaybackCapability.audioTrackDiscovery: CapabilityStatus.supported(),
          PlaybackCapability.audioTrackSwitching: CapabilityStatus.supported(),
          PlaybackCapability.subtitleTrackDiscovery:
              CapabilityStatus.supported(),
          PlaybackCapability.subtitleTrackSwitching:
              CapabilityStatus.supported(),
        },
      ),
    );
  }

  @override
  Future<TrackSwitchResult> switchTrack(MediaTrackId trackId) async {
    operations.add(PlaybackOperation.switchTrack);
    switchedTrackId = trackId;
    return const TrackSwitchResult.success();
  }
}

final class _ConfigurablePlayerAdapter implements PlayerAdapter {
  _ConfigurablePlayerAdapter({
    required this.capabilities,
    TrackDiscoveryResult? discoveryResult,
    TrackSwitchResult? switchResult,
  })  : _discoveryResult = discoveryResult,
        _switchResult = switchResult;

  @override
  final PlaybackCapabilityMatrix capabilities;
  final TrackDiscoveryResult? _discoveryResult;
  final TrackSwitchResult? _switchResult;
  int loadCount = 0;
  int playCount = 0;
  int pauseCount = 0;
  int seekCount = 0;
  int stopCount = 0;
  int switchCount = 0;
  MediaTrackId? switchedTrackId;

  @override
  String get id => 'configurable-player-adapter';

  @override
  String get displayName => 'Configurable Player Adapter';

  @override
  Future<PlaybackCommandResult> load(PlaybackSource source) async {
    loadCount += 1;
    return const PlaybackCommandResult.success();
  }

  @override
  Future<PlaybackCommandResult> play() async {
    playCount += 1;
    return const PlaybackCommandResult.success();
  }

  @override
  Future<PlaybackCommandResult> pause() async {
    pauseCount += 1;
    return const PlaybackCommandResult.success();
  }

  @override
  Future<PlaybackCommandResult> seek(Duration position) async {
    seekCount += 1;
    return const PlaybackCommandResult.success();
  }

  @override
  Future<PlaybackCommandResult> stop() async {
    stopCount += 1;
    return const PlaybackCommandResult.success();
  }

  @override
  Future<PlaybackCommandResult> dispose() async =>
      const PlaybackCommandResult.success();

  @override
  Future<TrackDiscoveryResult> discoverTracks() async {
    return _discoveryResult ??
        TrackDiscoveryResult.unsupported(
            reason: 'Track discovery is unsupported.');
  }

  @override
  Future<TrackSwitchResult> switchTrack(MediaTrackId trackId) async {
    switchCount += 1;
    switchedTrackId = trackId;
    return _switchResult ?? const TrackSwitchResult.success();
  }
}

final class _RuntimeLocalSubtitleScanner
    implements LocalExternalSubtitleScanner {
  @override
  Future<List<ExternalSubtitleCandidate>> scan(SubtitleScanRequest request) {
    return Future<List<ExternalSubtitleCandidate>>.value(
      <ExternalSubtitleCandidate>[
        ExternalSubtitleCandidate(
          source: ExternalSubtitleSource(
            id: 'runtime-local-subtitle',
            format: SubtitleFormat.srt,
            languageCode: 'ja',
            uri: Uri.file('D:/media/runtime.ja.srt'),
            title: 'Runtime Local Subtitle',
          ),
          matchConfidence: 0.9,
        ),
      ],
    );
  }
}

final class _RuntimeSubtitleProvider implements SubtitleProvider {
  _RuntimeSubtitleProvider({required this.candidate});

  final SubtitleProviderCandidate candidate;
  int searchCount = 0;
  int retrieveCount = 0;

  @override
  SubtitleProviderCachePolicy get cachePolicy => SubtitleProviderCachePolicy(
        searchTtl: const Duration(minutes: 10),
        fileTtl: const Duration(hours: 1),
      );

  @override
  String get displayName => 'Runtime Subtitle Provider';

  @override
  ProviderGateway get gateway => _RuntimeProviderGateway();

  @override
  String get id => 'runtime-subtitles';

  @override
  ProviderKind get kind => ProviderKind.subtitle;

  @override
  ProviderRegistration get registration => subtitleProviderRegistration(
      providerId: const SubtitleProviderId('runtime-subtitles'));

  @override
  SubtitleProviderId get subtitleProviderId =>
      const SubtitleProviderId('runtime-subtitles');

  @override
  Future<ProviderGatewayResponse<T>> executeGatewayRequest<T>({
    required String cacheKey,
    required Future<T> Function() load,
    ProviderCachePolicy cachePolicy = ProviderCachePolicy.networkOnly,
  }) {
    return load().then(
      (T value) => ProviderGatewayResponse<T>(
          value: value, source: ProviderGatewayResponseSource.network),
    );
  }

  @override
  ProviderRequestKey requestKey(String cacheKey) {
    return ProviderRequestKey(
        providerId: const ProviderId('runtime-subtitles'), cacheKey: cacheKey);
  }

  @override
  Future<AcgProviderResult<RetrievedSubtitleFile>> retrieveSubtitle(
      SubtitleProviderCandidate candidate) {
    retrieveCount += 1;
    return Future<AcgProviderResult<RetrievedSubtitleFile>>.value(
      AcgProviderSuccess<RetrievedSubtitleFile>(
        RetrievedSubtitleFile(
          candidate: candidate,
          content: '1\n00:00:01,000 --> 00:00:02,000\nRuntime subtitle',
          encodingHint: 'utf-8',
          cachedUri: Uri.parse('file:///D:/cache/runtime.srt'),
        ),
      ),
    );
  }

  @override
  Future<AcgProviderResult<List<SubtitleProviderCandidate>>> searchSubtitles(
      SubtitleSearchQuery query) {
    searchCount += 1;
    return Future<AcgProviderResult<List<SubtitleProviderCandidate>>>.value(
      AcgProviderSuccess<List<SubtitleProviderCandidate>>(
          <SubtitleProviderCandidate>[candidate]),
    );
  }
}

final class _RuntimeProviderGateway implements ProviderGateway {
  @override
  StorageFoundation get storage => throw StateError(
      'Runtime subtitle provider does not use gateway storage directly.');

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

final class _RuntimeFeedParser implements FeedParser {
  _RuntimeFeedParser({required this.items});

  final List<FeedItem> items;

  @override
  FeedFormat get format => FeedFormat.rss;

  @override
  Future<FeedParseResult> parse(FeedParseRequest request) {
    return Future<FeedParseResult>.value(
        FeedParseResult(sourceId: request.source.id, items: items));
  }
}

final class _RuntimeFeedFetcher implements FeedFetcher {
  _RuntimeFeedFetcher({required this.responses});

  final List<AcgProviderResult<FeedFetchResponse>> responses;
  final List<FeedFetchRequest> requests = <FeedFetchRequest>[];
  int _index = 0;

  @override
  String get displayName => 'Runtime Feed Fetcher';

  @override
  ProviderGateway get gateway => _RuntimeProviderGateway();

  @override
  String get id => 'runtime-feed-fetcher';

  @override
  ProviderKind get kind => ProviderKind.rss;

  @override
  ProviderRegistration get registration => rssProviderRegistration(
      sourceId: const FeedSourceId('runtime-feed-fetcher'));

  @override
  Future<ProviderGatewayResponse<T>> executeGatewayRequest<T>({
    required String cacheKey,
    required Future<T> Function() load,
    ProviderCachePolicy cachePolicy = ProviderCachePolicy.networkOnly,
  }) {
    return load().then(
      (T value) => ProviderGatewayResponse<T>(
          value: value, source: ProviderGatewayResponseSource.network),
    );
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
        providerId: const ProviderId('runtime-feed-fetcher'),
        cacheKey: cacheKey);
  }
}

final class _RuntimeSeasonalConsumer implements SeasonalAnimeConsumer {
  @override
  bool accepts(SeasonalFeedSourceId sourceId) =>
      sourceId.value == 'runtime-seasonal-rss';

  @override
  Future<List<SeasonalCatalogEntry>> consume(
      SeasonalFeedSourceId sourceId, Iterable<SeasonalSourceItem> items) {
    return Future<List<SeasonalCatalogEntry>>.value(
      <SeasonalCatalogEntry>[
        for (final SeasonalSourceItem item in items)
          SeasonalCatalogEntry(
            id: const SeasonalCatalogEntryId('runtime-seasonal-entry'),
            season: const AnimeSeason(year: 2026, kind: AnimeSeasonKind.summer),
            title: item.title,
            sourceItem: item,
            summary: item.summary,
            officialUri: item.link,
            publishedAt: item.publishedAt,
          ),
      ],
    );
  }
}

final class _RuntimeRssEngine implements RssEngineContract {
  final StreamController<FeedItem> _updates =
      StreamController<FeedItem>.broadcast(sync: true);

  @override
  Stream<FeedItem> get updates => _updates.stream;

  void emit(FeedItem item) {
    _updates.add(item);
  }

  @override
  Future<void> registerSource(FeedSource source) => Future<void>.value();

  @override
  Future<RssRefreshOutcome> refreshSource(RssRefreshRequest request) {
    return Future<RssRefreshOutcome>.value(
      RssRefreshOutcome.success(
          sourceId: request.sourceId, newItems: const <FeedItem>[]),
    );
  }

  Future<void> close() => _updates.close();
}

BtTaskMetadata _runtimeBtMetadata() {
  return const BtTaskMetadata(
    infoHash: InfoHash('runtimehash'),
    name: 'Runtime BT Pack',
    totalSizeBytes: 3072,
    pieceLengthBytes: 1024,
    files: <BtTaskFile>[
      BtTaskFile(
        index: BtFileIndex(0),
        path: 'Runtime Episode 1.mkv',
        lengthBytes: 1024,
        offsetBytes: 0,
        selectionState: BtFileSelectionState.selected,
      ),
      BtTaskFile(
        index: BtFileIndex(1),
        path: 'Runtime Episode 2.mkv',
        lengthBytes: 2048,
        offsetBytes: 1024,
        selectionState: BtFileSelectionState.selected,
      ),
    ],
  );
}

BtTaskStatus _runtimeBtStatus() {
  return BtTaskStatus(
    taskId: const BtTaskId('runtime-bt-task'),
    state: BtTaskLifecycleState.downloading,
    progress: 0.5,
    downloadRateBytesPerSecond: 4096,
    uploadRateBytesPerSecond: 512,
    connectedPeers: 4,
    metadata: _runtimeBtMetadata(),
  );
}

BtCapabilityMatrix _runtimeBtCapabilities() {
  return const BtCapabilityMatrix(
    capabilities: <BtStreamingCapability, BtCapabilityStatus>{
      BtStreamingCapability.taskManagement: BtCapabilityStatus.supported(),
      BtStreamingCapability.metadataFetching: BtCapabilityStatus.supported(),
      BtStreamingCapability.longBackgroundDownload:
          BtCapabilityStatus.supported(),
    },
  );
}

VideoEnhancementProfile _runtimeEnhancementProfile() {
  return const VideoEnhancementProfile(
    id: EnhancementProfileId('runtime-enhancement'),
    label: 'Runtime Enhancement',
    scaler: VideoScalerIntent.animeOptimized,
    hdrHandling: HdrHandlingIntent.toneMapToSdr,
    deband: DebandIntent.medium,
    anime4kPreset: Anime4kPresetIntent.restore,
  );
}

VideoEnhancementProfile _runtimeLightEnhancementProfile() {
  return const VideoEnhancementProfile(
    id: EnhancementProfileId('runtime-light'),
    label: 'Runtime Light',
    scaler: VideoScalerIntent.sharp,
    hdrHandling: HdrHandlingIntent.adapterDefault,
    deband: DebandIntent.light,
    anime4kPreset: Anime4kPresetIntent.off,
  );
}

PlaybackCapabilityMatrix _runtimeAVSyncCapabilities() {
  return PlaybackCapabilityMatrix(
    capabilities: <PlaybackCapability, CapabilityStatus>{
      PlaybackCapability.avSyncGuard: const CapabilityStatus.supported(),
    },
  );
}

FallbackAdapterCandidate _runtimeFallbackCandidate({
  required String id,
  required PlaybackCapabilityMatrix capabilities,
}) {
  return FallbackAdapterCandidate(
    id: FallbackAdapterId(id),
    adapter: _ConfigurablePlayerAdapter(capabilities: capabilities),
    capabilities: capabilities,
  );
}

PlaybackCapabilityMatrix _runtimeFallbackCapabilities() {
  return PlaybackCapabilityMatrix(
    capabilities: <PlaybackCapability, CapabilityStatus>{
      PlaybackCapability.fallbackAdapter: const CapabilityStatus.supported(),
      PlaybackCapability.localFilePlayback: const CapabilityStatus.supported(),
      PlaybackCapability.anime4kPreset:
          const CapabilityStatus.unsupported('Runtime fallback hides Anime4K.'),
    },
  );
}

AVSyncSample _runtimeAVSyncSample(int driftMillis,
    {bool enhancementOverBudget = false}) {
  return AVSyncSample(
    audioPosition: Duration(milliseconds: 1000 + driftMillis),
    videoPosition: const Duration(milliseconds: 1000),
    renderDelay: const Duration(milliseconds: 8),
    droppedFrames: enhancementOverBudget ? 1 : 0,
    enhancementPressure: enhancementOverBudget
        ? const RenderBudgetInput(
            frameBudget: Duration(milliseconds: 16),
            estimatedRenderCost: Duration(milliseconds: 24),
            droppedFrames: 1,
          )
        : null,
  );
}

AdvancedCaptionProfile _runtimeAdvancedCaptionProfile() {
  return const AdvancedCaptionProfile(
    id: AdvancedCaptionProfileId('runtime-captions'),
    label: 'Runtime Captions',
    matrixDanmakuEnabled: true,
    dualSubtitlesEnabled: true,
    pgsRenderingEnabled: true,
    assEnhancementEnabled: true,
    primarySubtitleLanguageCode: 'ja',
    secondarySubtitleLanguageCode: 'en',
  );
}

PlaybackCapabilityMatrix _runtimeAdvancedCaptionCapabilities() {
  return PlaybackCapabilityMatrix(
    capabilities: <PlaybackCapability, CapabilityStatus>{
      PlaybackCapability.matrixDanmaku: const CapabilityStatus.supported(),
      PlaybackCapability.dualSubtitles: const CapabilityStatus.supported(),
      PlaybackCapability.pgsSubtitleRendering:
          const CapabilityStatus.supported(),
      PlaybackCapability.assSubtitleEnhancement:
          const CapabilityStatus.supported(),
    },
  );
}

ExternalSubtitleSource _runtimeSubtitle(String id, String languageCode) {
  return ExternalSubtitleSource(
    id: id,
    format: SubtitleFormat.ass,
    languageCode: languageCode,
    uri: Uri.file('D:/media/$id.ass'),
  );
}

final class _RuntimeDownloadEngineAdapter implements DownloadEngineAdapter {
  _RuntimeDownloadEngineAdapter({BtCapabilityMatrix? capabilities})
      : capabilities = capabilities ?? _runtimeBtCapabilities();

  @override
  final BtCapabilityMatrix capabilities;

  final List<BtTaskCreateRequest> createdRequests = <BtTaskCreateRequest>[];
  final List<BtTaskId> pausedTaskIds = <BtTaskId>[];
  final List<BtTaskId> resumedTaskIds = <BtTaskId>[];
  final List<BtTaskId> removedTaskIds = <BtTaskId>[];
  final List<List<BtFileIndex>> selectedFiles = <List<BtFileIndex>>[];
  final StreamController<BtTaskStatus> _statusController =
      StreamController<BtTaskStatus>.broadcast(sync: true);
  final StreamController<BtTaskEvent> _eventController =
      StreamController<BtTaskEvent>.broadcast(sync: true);

  @override
  String get displayName => 'Runtime Download Engine';

  @override
  String get id => 'runtime-download-engine';

  @override
  Future<BtTaskId> createTask(BtTaskCreateRequest request) {
    createdRequests.add(request);
    return Future<BtTaskId>.value(const BtTaskId('runtime-bt-task'));
  }

  @override
  Future<BtTaskMetadata> ensureMetadata(BtTaskId taskId) {
    return Future<BtTaskMetadata>.value(_runtimeBtMetadata());
  }

  @override
  Future<void> pause(BtTaskId taskId) {
    pausedTaskIds.add(taskId);
    return Future<void>.value();
  }

  @override
  Future<void> remove(BtTaskId taskId) {
    removedTaskIds.add(taskId);
    return Future<void>.value();
  }

  @override
  Future<void> resume(BtTaskId taskId) {
    resumedTaskIds.add(taskId);
    return Future<void>.value();
  }

  @override
  Future<void> selectFiles(BtTaskId taskId, Iterable<BtFileIndex> files) {
    selectedFiles.add(<BtFileIndex>[...files]);
    return Future<void>.value();
  }

  @override
  Stream<BtTaskEvent> watchEvents(BtTaskId taskId) => _eventController.stream;

  @override
  Stream<BtTaskStatus> watchStatus(BtTaskId taskId) => _statusController.stream;

  void emitEvent(BtTaskEvent event) {
    _eventController.add(event);
  }

  void emitStatus(BtTaskStatus status) {
    _statusController.add(status);
  }
}

final class _RuntimePiecePriorityPlanApplier
    implements PiecePriorityPlanApplier {
  @override
  Future<PiecePriorityApplicationOutcome> apply(PiecePriorityPlan plan) {
    return Future<PiecePriorityApplicationOutcome>.value(
        const PiecePriorityApplicationOutcome.accepted());
  }
}

final class _RuntimeBangumiProvider implements BangumiProvider {
  @override
  String get displayName => 'Runtime Bangumi Provider';

  @override
  ProviderGateway get gateway => _RuntimeProviderGateway();

  @override
  String get id => 'runtime-bangumi';

  @override
  ProviderKind get kind => ProviderKind.metadata;

  @override
  ProviderRegistration get registration => ProviderRegistration(
        providerId: const ProviderId('runtime-bangumi'),
        ratePolicy: const ProviderRatePolicy(
            maxRequests: 12, window: Duration(minutes: 1)),
        retryPolicy: const ProviderRetryPolicy(
            maxAttempts: 3, initialBackoff: Duration(seconds: 1)),
      );

  @override
  Future<ProviderGatewayResponse<T>> executeGatewayRequest<T>({
    required String cacheKey,
    required Future<T> Function() load,
    ProviderCachePolicy cachePolicy = ProviderCachePolicy.networkOnly,
  }) {
    return load().then(
      (T value) => ProviderGatewayResponse<T>(
          value: value, source: ProviderGatewayResponseSource.network),
    );
  }

  @override
  Future<AcgProviderResult<BangumiEpisode>> lookupEpisode(BangumiEpisodeId id) {
    return Future<AcgProviderResult<BangumiEpisode>>.value(
      AcgProviderSuccess<BangumiEpisode>(
        BangumiEpisode(
          id: id,
          subjectId: const BangumiSubjectId('runtime-subject'),
          index: 1,
          title: 'Runtime Episode',
        ),
      ),
    );
  }

  @override
  Future<AcgProviderResult<BangumiSubject>> lookupSubject(BangumiSubjectId id) {
    return Future<AcgProviderResult<BangumiSubject>>.value(
      AcgProviderSuccess<BangumiSubject>(
          BangumiSubject(id: id, title: 'Runtime Seasonal Anime')),
    );
  }

  @override
  ProviderRequestKey requestKey(String cacheKey) {
    return ProviderRequestKey(
        providerId: const ProviderId('runtime-bangumi'), cacheKey: cacheKey);
  }

  @override
  Future<AcgProviderResult<List<BangumiSubject>>> searchSubjects(String query) {
    return Future<AcgProviderResult<List<BangumiSubject>>>.value(
      const AcgProviderSuccess<List<BangumiSubject>>(
        <BangumiSubject>[
          BangumiSubject(
            id: BangumiSubjectId('runtime-subject'),
            title: 'Runtime Seasonal Anime',
          ),
        ],
      ),
    );
  }
}

final class _RecordingPlaybackStateObserver implements PlaybackStateObserver {
  final List<PlaybackStateSnapshot> snapshots = <PlaybackStateSnapshot>[];

  @override
  void onPlaybackState(PlaybackStateSnapshot snapshot) {
    snapshots.add(snapshot);
  }
}

final class _ManualPlaybackStateObservable implements PlaybackStateObservable {
  _ManualPlaybackStateObservable({required PlaybackStateSnapshot initialState})
      : _currentState = initialState;

  PlaybackStateSnapshot _currentState;
  final List<PlaybackStateObserver> _observers = <PlaybackStateObserver>[];

  @override
  PlaybackStateSnapshot get currentState => _currentState;

  @override
  void addPlaybackStateObserver(PlaybackStateObserver observer) {
    if (!_observers.contains(observer)) {
      _observers.add(observer);
    }
  }

  @override
  void removePlaybackStateObserver(PlaybackStateObserver observer) {
    _observers.remove(observer);
  }

  void publish(PlaybackStateSnapshot snapshot) {
    _currentState = snapshot;
    for (final PlaybackStateObserver observer
        in List<PlaybackStateObserver>.of(_observers)) {
      observer.onPlaybackState(snapshot);
    }
  }
}


Future<void> _verifyFoundationRuntimeContract() async {
  // Verify FoundationRuntime composes Step 1-4 surfaces
  final DeterministicStorageFoundation storage = DeterministicStorageFoundation();
  final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
  final FoundationRuntime runtime = FoundationRuntime(
    storage: storage,
    invalidationBus: bus,
  );

  _expect(runtime.storage is DeterministicStorageFoundation,
      'FoundationRuntime must expose StorageFoundation.');
  _expect(runtime.gateway is DeterministicProviderGateway,
      'FoundationRuntime must expose ProviderGateway.');
  _expect(runtime.invalidationBus is StreamCacheInvalidationBus,
      'FoundationRuntime must expose CacheInvalidationBus.');
  _expect(!runtime.isDisposed,
      'FoundationRuntime must not be disposed before explicit disposal.');

  // Verify layer manifest has 8 layers
  _expect(FoundationRuntime.layerManifest.length == 8,
      'Layer manifest must contain exactly 8 layers.');

  // Verify layer boundary checker
  final List<String> manifestErrors = LayerBoundaryChecker.validateManifest();
  _expect(manifestErrors.isEmpty,
      'Layer manifest must be consistent.');

  // Verify storage foundation exposes all 24 store contracts
  _expect(storage.metadata is DeterministicMetadataStore,
      'StorageFoundation must expose MetadataStore.');
  _expect(storage.blobCache is DeterministicBlobCacheStore,
      'StorageFoundation must expose BlobCacheStore.');
  _expect(storage.mediaCache is DeterministicMediaCacheStore,
      'StorageFoundation must expose MediaCacheStore.');
  _expect(storage.settings is DeterministicSettingsStore,
      'StorageFoundation must expose SettingsStore.');
  _expect(storage.mediaLibrary is DeterministicMediaLibraryStore,
      'StorageFoundation must expose MediaLibraryStore.');
  _expect(storage.playbackHistory is DeterministicPlaybackHistoryRepository,
      'StorageFoundation must expose PlaybackHistoryRepository.');
  _expect(storage.providerBinding is DeterministicProviderBindingRepository,
      'StorageFoundation must expose ProviderBindingRepository.');

  // Verify provider gateway registration and execution
  final DeterministicProviderGateway gateway = DeterministicProviderGateway(
    storage: storage,
  );
  await gateway.registerProvider(
    const ProviderRegistration(
      providerId: ProviderId('runtime-test'),
      ratePolicy: ProviderRatePolicy(maxRequests: 5, window: Duration(minutes: 1)),
      retryPolicy: ProviderRetryPolicy(maxAttempts: 2, initialBackoff: Duration(seconds: 1)),
    ),
  );
  final ProviderGatewayResponse<String> response = await gateway.execute(
    ProviderGatewayRequest<String>(
      key: ProviderRequestKey(
        providerId: const ProviderId('runtime-test'),
        cacheKey: 'runtime-key',
      ),
      load: () => Future<String>.value('runtime-value'),
    ),
  );
  _expect(response.value == 'runtime-value',
      'ProviderGateway must execute supplied loaders.');
  _expect(response.source == ProviderGatewayResponseSource.network,
      'ProviderGateway must return network source for direct execution.');

  // Verify de-duplication boundary
  int loadCount = 0;
  final ProviderGatewayRequest<int> dedupeRequest = ProviderGatewayRequest<int>(
    key: ProviderRequestKey(
      providerId: const ProviderId('runtime-test'),
      cacheKey: 'dedupe-key',
    ),
    load: () {
      loadCount++;
      return Future<int>.value(99);
    },
    deduplicationWindow: const Duration(minutes: 5),
  );
  await gateway.execute(dedupeRequest);
  await gateway.execute(dedupeRequest);
  _expect(loadCount == 1,
      'ProviderGateway must deduplicate requests within the deduplication window.');

  // Verify invalidation bus lifecycle
  final Future<List<CacheInvalidationEvent>> events = bus.events.take(1).toList();
  bus.publish(BindingChanged(
    occurredAt: DateTime.utc(2026, 6, 8),
    localMediaId: 'test-media',
  ));
  final List<CacheInvalidationEvent> delivered = await events;
  _expect(delivered.whereType<BindingChanged>().length == 1,
      'CacheInvalidationBus must deliver events to subscribers.');
  await bus.close();

  // Verify disposal
  await runtime.dispose();
  _expect(runtime.isDisposed, 'FoundationRuntime must be disposed after dispose().');
  bool disposedAccess = false;
  try {
    runtime.storage;
  } on StateError {
    disposedAccess = true;
  }
  _expect(disposedAccess,
      'FoundationRuntime must reject access after disposal.');
}

Future<void> _verifyPlayerCoreRuntimeContract() async {
  final FoundationBootstrap foundation = FoundationBootstrap();
  final PlayerCoreBootstrap unsupportedBootstrap = PlayerCoreBootstrap(
    foundationDependency: foundation,
  );
  _expect(unsupportedBootstrap.runtime.foundationDependency == foundation,
      'PlayerCoreBootstrap must preserve the Phase 0 foundation dependency boundary.');
  _expect(!unsupportedBootstrap.runtime.capabilityMatrix
          .supports(PlaybackCapability.localFilePlayback),
      'Default player core bootstrap must not claim native playback support.');
  _expectFailureKind(await unsupportedBootstrap.controller.open(_localSource()),
      PlaybackFailureKind.unsupported);
  await unsupportedBootstrap.dispose();

  final DeterministicMpvBinding binding =
      PlayerCoreBootstrap.deterministicBinding(tracks: _tracks);
  final PlayerCoreRuntime runtime = PlayerCoreRuntime.bound(
    binding: binding,
    capabilities: PlaybackCapabilityMatrix(
      capabilities: <PlaybackCapability, CapabilityStatus>{
        PlaybackCapability.localFilePlayback: CapabilityStatus.supported(),
        PlaybackCapability.httpPlayback: CapabilityStatus.supported(),
        PlaybackCapability.hlsPlayback: CapabilityStatus.supported(),
        PlaybackCapability.playPause: CapabilityStatus.supported(),
        PlaybackCapability.seek: CapabilityStatus.supported(),
        PlaybackCapability.stop: CapabilityStatus.supported(),
        PlaybackCapability.progressReporting: CapabilityStatus.supported(),
        PlaybackCapability.audioTrackDiscovery: CapabilityStatus.supported(),
        PlaybackCapability.audioTrackSwitching: CapabilityStatus.supported(),
        PlaybackCapability.subtitleTrackDiscovery: CapabilityStatus.supported(),
        PlaybackCapability.subtitleTrackSwitching: CapabilityStatus.supported(),
        PlaybackCapability.secondaryPanels: CapabilityStatus.supported(),
      },
    ),
    foundationDependency: foundation,
  );
  final PlaybackControllerContract controller = runtime.controller;

  final _RecordingPlaybackStateObserver observer =
      _RecordingPlaybackStateObserver();
  controller.addPlaybackStateObserver(observer);
  _expectSuccess(await controller.open(_localSource()));
  _expectSuccess(await controller.play());
  _expectSuccess(await controller.seek(const Duration(seconds: 18)));
  final TrackDiscoveryResult discovery = await controller.discoverTracks();
  _expect(discovery.tracks.length == 2,
      'Player core runtime must discover normalized tracks through its active adapter.');
  final TrackSwitchResult switchResult = await controller.switchTrack(
    const DomainMediaTrackId('subtitle-ja'),
    trackType: DomainMediaTrackType.subtitle,
  );
  _expect(switchResult.isSuccess,
      'Player core runtime must switch known normalized tracks.');
  _expect(binding.loadedSource is LocalFilePlaybackSource,
      'Player core runtime must route load through deterministic binding.');
  _expect(binding.switchedTrackId?.value == 'subtitle-ja',
      'Player core runtime must route track switching through deterministic binding.');
  _expect(observer.snapshots.isNotEmpty,
      'Player core runtime must publish playback state snapshots.');
  _expect(runtime.currentState.timeline.position == const Duration(seconds: 18),
      'Player core runtime must update timeline state after seek.');
  _expect(runtime.currentState.activeTracks.subtitleTrackId?.value == 'subtitle-ja',
      'Player core runtime must update active subtitle track state.');

  final PlaybackPageContract page = PlaybackPageContract(
    controller: runtime.controller,
  );
  _expect(page.resolveSurface().hasActivePanel(PlaybackPagePanelId.tracks),
      'Playback page foundation must consume runtime-derived descriptors.');

  await runtime.dispose();
  _expect(runtime.isDisposed,
      'Player core runtime must report disposed after dispose.');
  _expect(binding.isDisposed,
      'Player core runtime must dispose its deterministic binding.');
  _expectFailureKind(await controller.play(), PlaybackFailureKind.disposed);
  await foundation.dispose();
}

void _expectIntentOutcome(
    PlaybackPageIntentResult result, PlaybackPageIntentOutcome outcome) {
  _expect(result.outcome == outcome,
      'Expected playback page intent outcome $outcome, got ${result.outcome}.');
}

void _expectSuccess(PlaybackCommandResult result) {
  _expect(result.isSuccess,
      'Expected playback command to succeed, got ${result.failure?.message}.');
}

void _expectFailureKind(
    PlaybackCommandResult result, PlaybackFailureKind kind) {
  final PlaybackFailure? failure = result.failure;
  _expect(failure != null, 'Expected playback command to fail.');
  _expect(failure!.kind == kind,
      'Expected failure kind $kind, got ${failure.kind}.');
}

void _expect(bool condition, String message) {
  if (!condition) {
    throw StateError(message);
  }
}
