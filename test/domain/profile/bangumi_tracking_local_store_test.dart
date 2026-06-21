import 'package:elaina/elaina.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cloud-first tracking returns remote loaded collection over local data',
      () async {
    final SettingsBangumiLocalTrackingStore localStore =
        SettingsBangumiLocalTrackingStore(DeterministicSettingsStore());
    await _saveLocalRecord(localStore);

    final CloudFirstBangumiTrackingProvider provider =
        CloudFirstBangumiTrackingProvider(
      localStore: localStore,
      remoteProvider: _SnapshotBangumiTrackingProvider(
        BangumiTrackingSnapshot.loaded(<BangumiTrackingItem>[
          const BangumiTrackingItem(
            subjectId: 'remote-subject',
            title: 'Remote Anime',
            status: BangumiTrackingStatus.watching,
            watchedEpisodes: 3,
            totalEpisodes: 12,
          ),
        ]),
      ),
    );

    final BangumiTrackingSnapshot snapshot =
        await provider.currentAnimeCollection();

    expect(snapshot.status, BangumiTrackingLoadStatus.loaded);
    expect(snapshot.items.single.subjectId, 'remote-subject');
  });

  test('cloud-first tracking uses local fallback only when unauthenticated',
      () async {
    final SettingsBangumiLocalTrackingStore localStore =
        SettingsBangumiLocalTrackingStore(DeterministicSettingsStore());
    await _saveLocalRecord(localStore);

    final CloudFirstBangumiTrackingProvider provider =
        CloudFirstBangumiTrackingProvider(
      localStore: localStore,
      remoteProvider: const _SnapshotBangumiTrackingProvider(
        BangumiTrackingSnapshot.unauthenticated('missing token'),
      ),
    );

    final BangumiTrackingSnapshot snapshot =
        await provider.currentAnimeCollection();

    expect(snapshot.status, BangumiTrackingLoadStatus.loaded);
    expect(snapshot.items.single.subjectId, 'local-subject');
  });

  test('cloud-first tracking preserves remote failure instead of stale local',
      () async {
    final SettingsBangumiLocalTrackingStore localStore =
        SettingsBangumiLocalTrackingStore(DeterministicSettingsStore());
    await _saveLocalRecord(localStore);

    final CloudFirstBangumiTrackingProvider provider =
        CloudFirstBangumiTrackingProvider(
      localStore: localStore,
      remoteProvider: const _SnapshotBangumiTrackingProvider(
        BangumiTrackingSnapshot.failed('remote failed'),
      ),
    );

    final BangumiTrackingSnapshot snapshot =
        await provider.currentAnimeCollection();

    expect(snapshot.status, BangumiTrackingLoadStatus.failed);
    expect(snapshot.message, 'remote failed');
    expect(snapshot.items, isEmpty);
  });
}

Future<void> _saveLocalRecord(BangumiLocalTrackingStore store) {
  return store.save(
    BangumiLocalTrackingRecord(
      subjectId: 'local-subject',
      title: 'Local Anime',
      status: BangumiTrackingStatus.planned,
      updatedAt: DateTime.utc(2026, 6, 21),
      syncState: BangumiLocalTrackingSyncState.pending,
    ),
  );
}

final class _SnapshotBangumiTrackingProvider
    implements BangumiTrackingProvider {
  const _SnapshotBangumiTrackingProvider(this.snapshot);

  final BangumiTrackingSnapshot snapshot;

  @override
  Future<BangumiTrackingSnapshot> currentAnimeCollection() async => snapshot;
}
