import 'package:elaina/elaina.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/provider_test_fakes.dart';
import '../../support/runtime_test_fakes.dart';

void main() {
  test('runtime scans imports projects catalog state and publishes events',
      () async {
    final DateTime now = DateTime.utc(2026, 6, 10, 9);
    final MediaScanCandidate firstCandidate =
        _candidate('media-1', 'episode-1.mkv');
    final MediaScanCandidate secondCandidate =
        _candidate('media-2', 'episode-2.mkv');
    const MediaScanId scanId = MediaScanId('runtime-scan');
    final DeterministicMediaLibraryCatalogRepository repository =
        DeterministicMediaLibraryCatalogRepository();
    final DeterministicPlaybackHistoryStore historyStore =
        DeterministicPlaybackHistoryStore();
    await historyStore.record(_history('history-2', secondCandidate.identity.id,
        const Duration(minutes: 8), now.add(const Duration(minutes: 1))));
    final DeterministicProviderBindingStore bindingStore =
        DeterministicProviderBindingStore();
    await bindingStore.saveAutomaticIfAllowed(_binding(
        'binding-auto',
        firstCandidate.identity.id,
        ProviderBindingAuthority.automatic,
        0.7,
        now));
    final RecordingCacheInvalidationBus invalidationBus =
        RecordingCacheInvalidationBus();
    final MediaLibraryRuntime runtime = MediaLibraryRuntime(
      scanner: DeterministicMediaLibraryScanner(
          scanId: scanId,
          candidates: <MediaScanCandidate>[firstCandidate, secondCandidate]),
      catalogRepository: repository,
      importer: DeterministicMediaBatchImportContract(
          repository: repository, clock: () => now),
      historyStore: historyStore,
      bindingStore: bindingStore,
      playbackSourceHandoff: const LocalPlaybackSourceHandoff(),
      invalidationBus: invalidationBus,
      now: () => now,
    );
    final _RuntimeObserver observer = _RuntimeObserver();
    runtime.addObserver(observer);

    final MediaLibraryActionResult<MediaScanResult> scan =
        await runtime.scan(_scope());
    final MediaLibraryActionResult<List<MediaScanEvent>> events =
        await runtime.watchScan(scanId);
    final MediaLibraryActionResult<MediaImportResult> imported =
        await runtime.importCandidates(scan.value!.candidates);
    final MediaLibraryActionResult<MediaLibraryRuntimeSnapshot> snapshot =
        await runtime.refresh();

    expect(scan.isSuccess, isTrue);
    expect(scan.value?.candidates,
        <MediaScanCandidate>[firstCandidate, secondCandidate]);
    expect(
        events.value?.whereType<MediaScanCandidateDiscovered>(), hasLength(2));
    expect(imported.value?.importedCount, 2);
    expect(snapshot.value?.catalogItems, hasLength(2));
    expect(snapshot.value?.continueWatching.single.mediaId.value, 'media-2');
    expect(
        snapshot.value?.catalogItems.first.binding?.id.value, 'binding-auto');
    expect(invalidationBus.publishedEvents.whereType<MediaLibraryItemChanged>(),
        hasLength(2));
    expect(
        observer.snapshots
            .map((MediaLibraryRuntimeSnapshot value) => value.status),
        contains(MediaLibraryRuntimeStatus.scanning));

    runtime.dispose();
    expect(runtime.currentSnapshot.status, MediaLibraryRuntimeStatus.disposed);
  });

  test(
      'runtime import catalog history binding and playback actions are normalized',
      () async {
    final DateTime now = DateTime.utc(2026, 6, 10, 10);
    final MediaFileFingerprint fingerprint =
        const MediaFileFingerprint(algorithm: 'sha256', value: 'same-file');
    final MediaScanCandidate firstCandidate =
        _candidate('media-1', 'episode-1.mkv', fingerprint: fingerprint);
    final MediaScanCandidate duplicateCandidate = _candidate(
        'media-duplicate', 'episode-duplicate.mkv',
        fingerprint: fingerprint);
    final DeterministicMediaLibraryCatalogRepository repository =
        DeterministicMediaLibraryCatalogRepository();
    final DeterministicProviderBindingStore bindingStore =
        DeterministicProviderBindingStore();
    final RecordingCacheInvalidationBus invalidationBus =
        RecordingCacheInvalidationBus();
    final MediaLibraryRuntime runtime = MediaLibraryRuntime(
      scanner: const EmptyMediaLibraryScanner(),
      catalogRepository: repository,
      importer: DeterministicMediaBatchImportContract(
          repository: repository, clock: () => now),
      historyStore: DeterministicPlaybackHistoryStore(),
      bindingStore: bindingStore,
      playbackSourceHandoff: const LocalPlaybackSourceHandoff(),
      invalidationBus: invalidationBus,
      now: () => now,
    );

    final MediaImportResult importResult = (await runtime.importCandidates(
            <MediaScanCandidate>[firstCandidate, duplicateCandidate]))
        .value!;
    final MediaLibraryItem item = importResult.imported.single;
    final MediaLibraryActionResult<int> count = await runtime.count();
    final MediaLibraryActionResult<MediaLibraryItem> detail =
        await runtime.detail(item.id);
    final MediaLibraryActionResult<PlaybackSourceHandoffResult> play =
        await runtime.playItem(item.id);
    final MediaLibraryActionResult<PlaybackSourceHandoffResult> unsupported =
        runtime.playCandidate(_candidateWithUri(
            'remote-media', Uri.parse('https://example.test/remote.mkv')));
    final MediaLibraryActionResult<void> history = await runtime.recordHistory(
        _history(
            'history-1', item.identity.id, const Duration(minutes: 4), now));
    final ProviderBinding confirmed = _binding('binding-user', item.identity.id,
        ProviderBindingAuthority.userConfirmed, 0.2, now);
    final ProviderBinding automatic = _binding(
        'binding-auto',
        item.identity.id,
        ProviderBindingAuthority.automatic,
        1,
        now.add(const Duration(minutes: 1)));
    final MediaLibraryActionResult<ProviderBinding> savedConfirmed =
        await runtime.saveUserBinding(confirmed);
    final MediaLibraryActionResult<ProviderBinding> savedAutomatic =
        await runtime.saveAutomaticBinding(automatic);
    final MediaLibraryActionResult<MediaLibraryItem> update =
        await runtime.update(MediaLibraryItem(
            id: item.id,
            identity: item.identity,
            addedAt: item.addedAt,
            duration: const Duration(minutes: 24)));
    final MediaLibraryActionResult<bool> remove = await runtime.remove(item.id);
    final MediaLibraryActionResult<bool> removeAgain =
        await runtime.remove(item.id);

    expect(importResult.importedCount, 1);
    expect(importResult.skippedDuplicateCount, 1);
    expect(count.value, 1);
    expect(detail.value?.id.value, item.id.value);
    expect(play.isSuccess, isTrue);
    expect(unsupported.kind, MediaLibraryActionResultKind.unsupported);
    expect(history.isSuccess, isTrue);
    expect(savedConfirmed.value, confirmed);
    expect(savedAutomatic.value, confirmed);
    expect(update.value?.duration, const Duration(minutes: 24));
    expect(remove.value, isTrue);
    expect(removeAgain.kind, MediaLibraryActionResultKind.ignored);
    expect(removeAgain.failure?.kind, MediaLibraryRuntimeFailureKind.ignored);
    expect(invalidationBus.publishedEvents.whereType<HistoryRecorded>(),
        hasLength(1));
    expect(invalidationBus.publishedEvents.whereType<BindingChanged>(),
        hasLength(1));
    expect(
        invalidationBus.publishedEvents
            .whereType<MediaLibraryItemChanged>()
            .map((MediaLibraryItemChanged event) => event.changeKind),
        contains(MediaLibraryChangeKind.removed));
  });

  test('runtime searches and confirms Bangumi matches for local media',
      () async {
    final DateTime now = DateTime.utc(2026, 6, 20, 22);
    final DeterministicMediaLibraryCatalogRepository repository =
        DeterministicMediaLibraryCatalogRepository();
    final DeterministicProviderBindingStore bindingStore =
        DeterministicProviderBindingStore();
    final FakeBangumiProvider bangumiProvider = FakeBangumiProvider(
      subjects: const <BangumiSubject>[
        BangumiSubject(id: BangumiSubjectId('42'), title: 'Frieren'),
        BangumiSubject(id: BangumiSubjectId('43'), title: 'Frieren Special'),
      ],
    );
    final MediaLibraryRuntime runtime = MediaLibraryRuntime(
      scanner: const EmptyMediaLibraryScanner(),
      catalogRepository: repository,
      importer: DeterministicMediaBatchImportContract(
          repository: repository, clock: () => now),
      historyStore: DeterministicPlaybackHistoryStore(),
      bindingStore: bindingStore,
      playbackSourceHandoff: const LocalPlaybackSourceHandoff(),
      invalidationBus: RecordingCacheInvalidationBus(),
      bangumiMatcher: BangumiLocalMediaMatcher(
        bangumiProvider: bangumiProvider,
      ),
      now: () => now,
    );
    final MediaLibraryItem item = (await runtime.importCandidates(
      <MediaScanCandidate>[
        _candidate('media-frieren', '[Fansub] Frieren - 01 [1080p].mkv'),
      ],
    ))
        .value!
        .imported
        .single;

    final MediaLibraryActionResult<LocalMediaBangumiMatchResult> matches =
        await runtime.searchBangumiMatches(item.identity.id);
    final LocalMediaBangumiMatchCandidate candidate =
        matches.value!.candidates.first;
    final MediaLibraryActionResult<ProviderBinding> confirmed =
        await runtime.confirmBangumiMatch(
      mediaId: item.identity.id,
      candidate: candidate,
    );
    final MediaLibraryActionResult<MediaLibraryRuntimeSnapshot> snapshot =
        await runtime.refresh();

    expect(matches.isSuccess, isTrue);
    expect(matches.value?.query, 'Frieren');
    expect(bangumiProvider.searchedQueries, <String>['Frieren']);
    expect(candidate.subjectId.value, '42');
    expect(candidate.confidence, bangumiLocalMediaExactTitleConfidence);
    expect(confirmed.value?.authority, ProviderBindingAuthority.userConfirmed);
    expect(confirmed.value?.providerId, bangumiProviderBindingProviderId);
    expect(confirmed.value?.subjectId?.value, '42');
    expect(
      (await bindingStore.bindingFor(item.identity.id))?.authority,
      ProviderBindingAuthority.userConfirmed,
    );
    expect(snapshot.value?.catalogItems.single.binding?.subjectId?.value, '42');
  });

  test('runtime exposes cancellation failures and disposed outcomes', () async {
    const MediaScanId scanId = MediaScanId('runtime-cancel');
    final DeterministicMediaLibraryCatalogRepository repository =
        DeterministicMediaLibraryCatalogRepository();
    final MediaLibraryRuntime runtime = MediaLibraryRuntime(
      scanner: DeterministicMediaLibraryScanner(scanId: scanId),
      catalogRepository: repository,
      importer: DeterministicMediaBatchImportContract(repository: repository),
      historyStore: DeterministicPlaybackHistoryStore(),
      bindingStore: DeterministicProviderBindingStore(),
      playbackSourceHandoff: const LocalPlaybackSourceHandoff(),
      invalidationBus: RecordingCacheInvalidationBus(),
    );

    await runtime.cancelScan(scanId);
    final MediaLibraryActionResult<MediaScanResult> cancelled =
        await runtime.scan(_scope());
    runtime.dispose();
    final MediaLibraryActionResult<int> disposed = await runtime.count();

    expect(
        cancelled.value?.failures.single.kind, MediaScanFailureKind.cancelled);
    expect(runtime.currentSnapshot.status, MediaLibraryRuntimeStatus.disposed);
    expect(disposed.kind, MediaLibraryActionResultKind.failed);
    expect(disposed.failure?.kind, MediaLibraryRuntimeFailureKind.disposed);
  });
}

MediaScanScope _scope() {
  return MediaScanScope(
      roots: <Uri>[Uri.parse('file:///D:/media/')],
      extensions: const <String>{'mkv'});
}

MediaScanCandidate _candidate(String mediaId, String basename,
    {MediaFileFingerprint? fingerprint}) {
  return _candidateWithUri(mediaId, Uri.parse('file:///D:/media/$basename'),
      fingerprint: fingerprint);
}

MediaScanCandidate _candidateWithUri(String mediaId, Uri uri,
    {MediaFileFingerprint? fingerprint}) {
  return MediaScanCandidate(
    identity: LocalMediaIdentity(
        id: LocalMediaId(mediaId),
        uri: uri,
        basename:
            uri.pathSegments.isEmpty ? 'episode.mkv' : uri.pathSegments.last,
        fingerprint: fingerprint),
    sizeBytes: 42,
    duration: const Duration(minutes: 24),
  );
}

PlaybackHistoryEntry _history(
    String id, LocalMediaId mediaId, Duration position, DateTime updatedAt) {
  return PlaybackHistoryEntry(
      id: PlaybackHistoryEntryId(id),
      mediaId: mediaId,
      position: position,
      duration: const Duration(minutes: 24),
      updatedAt: updatedAt);
}

ProviderBinding _binding(String id, LocalMediaId mediaId,
    ProviderBindingAuthority authority, double confidence, DateTime createdAt) {
  return ProviderBinding(
    id: ProviderBindingId(id),
    localMediaId: mediaId,
    providerId: defaultVideoDetailMetadataProviderId,
    subjectId: const ProviderSubjectId('subject-1'),
    authority: authority,
    confidence: confidence,
    createdAt: createdAt,
  );
}

final class _RuntimeObserver implements MediaLibraryRuntimeObserver {
  final List<MediaLibraryRuntimeSnapshot> snapshots =
      <MediaLibraryRuntimeSnapshot>[];

  @override
  void onMediaLibraryRuntimeSnapshot(MediaLibraryRuntimeSnapshot snapshot) {
    snapshots.add(snapshot);
  }
}
