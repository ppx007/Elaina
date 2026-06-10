import '../lib/celesteria.dart';
import 'video_detail_runtime_check.dart';

Future<void> main() async {
  await verifyMediaLibraryRuntimeContract();
}

Future<void> verifyMediaLibraryRuntimeContract() async {
  final DateTime now = DateTime.utc(2026, 6, 10, 12);
  final MediaScanCandidate first = _candidate('check-media-1', 'check-1.mkv');
  final MediaScanCandidate second = _candidate('check-media-2', 'check-2.mkv');
  const MediaScanId scanId = MediaScanId('media-library-runtime-check');
  final DeterministicMediaLibraryCatalogRepository repository = DeterministicMediaLibraryCatalogRepository();
  final DeterministicPlaybackHistoryStore historyStore = DeterministicPlaybackHistoryStore();
  await historyStore.record(PlaybackHistoryEntry(
    id: const PlaybackHistoryEntryId('check-history'),
    mediaId: second.identity.id,
    position: const Duration(minutes: 6),
    duration: const Duration(minutes: 24),
    updatedAt: now,
  ));
  final DeterministicProviderBindingStore bindingStore = DeterministicProviderBindingStore();
  await bindingStore.saveUserConfirmed(ProviderBinding(
    id: const ProviderBindingId('check-binding'),
    localMediaId: first.identity.id,
    providerId: 'bangumi',
    subjectId: const ProviderSubjectId('check-subject'),
    authority: ProviderBindingAuthority.userConfirmed,
    confidence: 1,
    createdAt: now,
  ));
  final StreamCacheInvalidationBus invalidationBus = StreamCacheInvalidationBus();
  final List<CacheInvalidationEvent> events = <CacheInvalidationEvent>[];
  final subscription = invalidationBus.events.listen(events.add);
  final MediaLibraryBootstrap bootstrap = MediaLibraryBootstrap(
    scanner: DeterministicMediaLibraryScanner(scanId: scanId, candidates: <MediaScanCandidate>[first, second]),
    catalogRepository: repository,
    importer: DeterministicMediaBatchImportContract(repository: repository, clock: () => now),
    historyStore: historyStore,
    bindingStore: bindingStore,
    playbackSourceHandoff: const LocalPlaybackSourceHandoff(),
    invalidationBus: invalidationBus,
    now: () => now,
  );

  final MediaLibraryActionResult<MediaScanResult> scan = await bootstrap.scan(_scope());
  _expect(scan.isSuccess && scan.value?.candidates.length == 2, 'Media library runtime must scan deterministic candidates.');
  final MediaLibraryActionResult<MediaImportResult> imported = await bootstrap.importCandidates(scan.value!.candidates);
  _expect(imported.value?.importedCount == 2, 'Media library runtime must import scanned candidates.');
  final MediaLibraryRuntimeSnapshot snapshot = (await bootstrap.refresh()).value!;
  _expect(snapshot.catalogItems.length == 2, 'Media library runtime must project imported catalog items.');
  _expect(snapshot.continueWatching.single.mediaId.value == second.identity.id.value, 'Media library runtime must expose continue-watching state.');
  _expect(snapshot.catalogItems.first.binding?.authority == ProviderBindingAuthority.userConfirmed, 'Media library runtime must expose strongest provider binding.');
  final MediaLibraryActionResult<PlaybackSourceHandoffResult> play = await bootstrap.runtime.playItem(snapshot.catalogItems.first.item.id);
  _expect(play.isSuccess, 'Media library runtime must route playback through handoff.');
  _expect(events.whereType<MediaLibraryItemChanged>().length == 2, 'Media library runtime must publish imported item invalidation events.');

  bootstrap.dispose();
  await subscription.cancel();
  await invalidationBus.close();
  await verifyVideoDetailRuntimeContract();
}

MediaScanScope _scope() {
  return MediaScanScope(roots: <Uri>[Uri.parse('file:///D:/media/')], extensions: const <String>{'mkv'});
}

MediaScanCandidate _candidate(String mediaId, String basename) {
  final Uri uri = Uri.parse('file:///D:/media/$basename');
  return MediaScanCandidate(
    identity: LocalMediaIdentity(id: LocalMediaId(mediaId), uri: uri, basename: basename),
    sizeBytes: 42,
    duration: const Duration(minutes: 24),
  );
}

void _expect(bool condition, String message) {
  if (!condition) throw StateError(message);
}
