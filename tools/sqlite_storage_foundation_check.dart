import '../lib/elaina.dart';

Future<void> main() async {
  await verifySqliteStorageFoundation();
}

Future<void> verifySqliteStorageFoundation() async {
  final SqliteStorageFoundation storage = SqliteStorageFoundation.inMemory();
  try {
    await storage.settings.writeString(key: 'language', value: 'ja');
    _expect(await storage.settings.readString('language') == 'ja',
        'SQLite settings store must round-trip values.');

    await storage.mediaLibrary.store(
      StoredMediaLibraryItemRecord(
        id: 'check-item',
        localMediaId: 'check-media',
        uri: Uri.parse('file:///D:/media/check.mkv'),
        basename: 'check.mkv',
        addedAt: DateTime.utc(2026, 6, 17, 12),
      ),
    );
    _expect((await storage.mediaLibrary.count()) == 1,
        'SQLite media library store must persist item count.');
    _expect(
        (await storage.mediaLibrary.findByLocalMediaId('check-media'))?.id ==
            'check-item',
        'SQLite media library store must read by local media id.');

    await storage.playbackHistory.record(
      StoredPlaybackHistoryRecord(
        id: 'check-history',
        localMediaId: 'check-media',
        position: const Duration(minutes: 3),
        duration: const Duration(minutes: 24),
        updatedAt: DateTime.utc(2026, 6, 17, 12, 1),
      ),
    );
    _expect(
      (await storage.playbackHistory.latestFor('check-media'))?.position ==
          const Duration(minutes: 3),
      'SQLite playback history must expose latest history.',
    );

    await storage.subtitleCache.storeSearchResults(
      StoredSubtitleSearchCacheRecord(
        providerId: 'opensubtitles',
        queryKey: 'check|ja|||',
        candidates: const <StoredSubtitleSearchCandidateRecord>[
          StoredSubtitleSearchCandidateRecord(
            id: 'check-subtitle',
            providerId: 'opensubtitles',
            title: 'Check Subtitle',
            format: 'srt',
            reference: 'check-ref',
            confidence: 0.9,
          ),
        ],
        cachedAt: DateTime.utc(2026, 6, 17, 12),
        expiresAt: DateTime.utc(2026, 6, 17, 13),
      ),
    );
    _expect(
      (await storage.subtitleCache.searchResults(
            providerId: 'opensubtitles',
            queryKey: 'check|ja|||',
            now: DateTime.utc(2026, 6, 17, 12, 30),
          ))
              ?.candidates
              .single
              .reference ==
          'check-ref',
      'SQLite subtitle search cache must round-trip candidates.',
    );
  } finally {
    storage.dispose();
  }
}

void _expect(bool condition, String message) {
  if (!condition) throw StateError(message);
}
