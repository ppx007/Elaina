import 'dart:io';

import 'package:celesteria/celesteria.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sqlite storage persists core stores after reopen', () async {
    final File databaseFile = await _tempDatabaseFile();
    addTearDown(() async {
      if (databaseFile.parent.existsSync()) {
        await databaseFile.parent.delete(recursive: true);
      }
    });

    final SqliteStorageFoundation first =
        SqliteStorageFoundation.open(databaseFile.path);
    await first.settings.writeString(key: 'theme', value: 'dark');
    await first.blobCache.putBlob(
      key: 'poster',
      bytes: Stream<List<int>>.value(<int>[1, 2, 3]),
    );
    await first.mediaCache.recordBufferedRange(
      mediaId: 'media-1',
      startByte: 0,
      endByte: 1024,
    );
    await first.mediaLibrary.store(_mediaRecord());
    await first.playbackHistory.record(_historyRecord());
    await first.providerBinding.saveUserConfirmed(_confirmedBinding());
    final StoredProviderBindingRecord automatic =
        await first.providerBinding.saveAutomaticIfAllowed(_automaticBinding());
    first.dispose();

    expect(automatic.id, 'binding-confirmed');

    final SqliteStorageFoundation second =
        SqliteStorageFoundation.open(databaseFile.path);
    addTearDown(second.dispose);

    expect(await second.settings.readString('theme'), 'dark');
    final Stream<List<int>>? blob = await second.blobCache.readBlob('poster');
    expect(blob, isNotNull);
    expect(
      await blob!.fold<List<int>>(
        <int>[],
        (List<int> previous, List<int> chunk) => previous..addAll(chunk),
      ),
      <int>[1, 2, 3],
    );
    expect((await second.mediaCache.bufferedRanges('media-1')).single.endByte,
        1024);
    expect((await second.mediaLibrary.findById('item-1'))?.basename,
        'episode-1.mkv');
    expect((await second.mediaLibrary.findByUri(_mediaUri()))?.id, 'item-1');
    expect(
      (await second.mediaLibrary.findByFingerprint(
        const StoredMediaFileFingerprint(
          algorithm: 'sha256',
          value: 'hash-1',
        ),
      ))
          ?.localMediaId,
      'media-1',
    );
    expect(
      (await second.playbackHistory.latestFor('media-1'))?.position,
      const Duration(minutes: 5),
    );
    expect(
      (await second.providerBinding.bindingFor('media-1'))?.id,
      'binding-confirmed',
    );
  });

  test('sqlite subtitle cache preserves records and evicts expired state',
      () async {
    final SqliteStorageFoundation storage = SqliteStorageFoundation.inMemory();
    addTearDown(storage.dispose);
    final DateTime cachedAt = DateTime.utc(2026, 6, 17, 12);

    await storage.subtitleCache.storeSearchResults(
      StoredSubtitleSearchCacheRecord(
        providerId: 'opensubtitles',
        queryKey: 'frieren|ja|1|1|',
        candidates: const <StoredSubtitleSearchCandidateRecord>[
          StoredSubtitleSearchCandidateRecord(
            id: 'candidate-1',
            providerId: 'opensubtitles',
            title: 'Japanese',
            format: 'srt',
            reference: 'ref-1',
            confidence: 0.9,
            languageCode: 'ja',
          ),
        ],
        cachedAt: cachedAt,
        expiresAt: cachedAt.add(const Duration(minutes: 10)),
      ),
    );
    await storage.subtitleCache.storeContent(
      StoredSubtitleContentCacheRecord(
        providerId: 'opensubtitles',
        candidateReference: 'ref-1',
        content: '1\n00:00:01,000 --> 00:00:02,000\nFrieren',
        cachedAt: cachedAt,
        expiresAt: cachedAt.add(const Duration(hours: 1)),
        encodingHint: 'utf-8',
        cachedUri: Uri.parse('file:///cache/frieren.srt'),
      ),
    );

    expect(
      (await storage.subtitleCache.searchResults(
        providerId: 'opensubtitles',
        queryKey: 'frieren|ja|1|1|',
        now: cachedAt.add(const Duration(minutes: 1)),
      ))
          ?.candidates
          .single
          .reference,
      'ref-1',
    );
    expect(
      (await storage.subtitleCache.content(
        providerId: 'opensubtitles',
        candidateReference: 'ref-1',
        now: cachedAt.add(const Duration(minutes: 30)),
      ))
          ?.encodingHint,
      'utf-8',
    );
    expect(
      await storage.subtitleCache.searchResults(
        providerId: 'opensubtitles',
        queryKey: 'frieren|ja|1|1|',
        now: cachedAt.add(const Duration(minutes: 10)),
      ),
      isNull,
    );
    expect(
      await storage.subtitleCache.content(
        providerId: 'opensubtitles',
        candidateReference: 'ref-1',
        now: cachedAt.add(const Duration(hours: 1)),
      ),
      isNull,
    );
  });

  test(
      'sqlite metadata migration is durable and fallback stores stay injectable',
      () async {
    final File databaseFile = await _tempDatabaseFile();
    addTearDown(() async {
      if (databaseFile.parent.existsSync()) {
        await databaseFile.parent.delete(recursive: true);
      }
    });
    final DeterministicStorageFoundation fallback =
        DeterministicStorageFoundation();
    final SqliteStorageFoundation first = SqliteStorageFoundation.open(
      databaseFile.path,
      fallback: fallback,
    );

    expect(first.metadata.schemaVersion.value, sqliteStorageSchemaVersion);
    expect(first.rssFeed, same(fallback.rssFeed));

    await first.metadata.migrateToLatest(<SchemaMigration>[
      _Migration(from: sqliteStorageSchemaVersion, to: 2),
    ]);
    first.dispose();

    final SqliteStorageFoundation second =
        SqliteStorageFoundation.open(databaseFile.path);
    addTearDown(second.dispose);
    expect(second.metadata.schemaVersion.value, 2);
  });
}

Future<File> _tempDatabaseFile() async {
  final Directory directory =
      await Directory.systemTemp.createTemp('celesteria_sqlite_storage_');
  return File('${directory.path}${Platform.pathSeparator}storage.db');
}

Uri _mediaUri() => Uri.parse('file:///D:/media/episode-1.mkv');

StoredMediaLibraryItemRecord _mediaRecord() {
  return StoredMediaLibraryItemRecord(
    id: 'item-1',
    localMediaId: 'media-1',
    uri: _mediaUri(),
    basename: 'episode-1.mkv',
    addedAt: DateTime.utc(2026, 6, 17, 10),
    fingerprint: const StoredMediaFileFingerprint(
      algorithm: 'sha256',
      value: 'hash-1',
    ),
    duration: const Duration(minutes: 24),
  );
}

StoredPlaybackHistoryRecord _historyRecord() {
  return StoredPlaybackHistoryRecord(
    id: 'history-1',
    localMediaId: 'media-1',
    position: const Duration(minutes: 5),
    duration: const Duration(minutes: 24),
    updatedAt: DateTime.utc(2026, 6, 17, 11),
  );
}

StoredProviderBindingRecord _confirmedBinding() {
  return StoredProviderBindingRecord(
    id: 'binding-confirmed',
    localMediaId: 'media-1',
    providerId: 'bangumi',
    providerSubjectId: 'subject-1',
    authority: 'user-confirmed',
    confidence: 0.8,
    createdAt: DateTime.utc(2026, 6, 17, 10),
  );
}

StoredProviderBindingRecord _automaticBinding() {
  return StoredProviderBindingRecord(
    id: 'binding-auto',
    localMediaId: 'media-1',
    providerId: 'bangumi',
    providerSubjectId: 'subject-2',
    authority: 'automatic',
    confidence: 1,
    createdAt: DateTime.utc(2026, 6, 17, 11),
  );
}

final class _Migration implements SchemaMigration {
  _Migration({required int from, required int to})
      : from = SchemaVersion(from),
        to = SchemaVersion(to);

  @override
  final SchemaVersion from;

  @override
  final SchemaVersion to;

  @override
  Future<void> migrate(MigrationExecutor executor) async {
    await executor.execute(
      'create table if not exists migration_probe(id text primary key)',
    );
  }
}
