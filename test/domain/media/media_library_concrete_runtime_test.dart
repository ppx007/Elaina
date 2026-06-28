import 'dart:io';

// Concrete media library runtime tests verify storage-backed scanning/import
// wiring after the domain contract tests define expected behavior.
import 'package:elaina/elaina.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('local file scanner scans supported files and emits events', () async {
    final Directory root = await Directory.systemTemp.createTemp(
      'elaina-media-scan-',
    );
    addTearDown(() async {
      if (root.existsSync()) await root.delete(recursive: true);
    });
    final File first =
        await File(_join(root.path, 'episode-1.mkv')).writeAsString('first');
    await File(_join(root.path, 'notes.txt')).writeAsString('notes');
    final Directory nested =
        await Directory(_join(root.path, 'nested')).create();
    final File second =
        await File(_join(nested.path, 'episode-2.MKV')).writeAsString('second');
    const MediaScanId scanId = MediaScanId('local-file-scan-test');
    final DateTime now = DateTime.utc(2026, 6, 17, 12);
    final LocalFileMediaLibraryScanner scanner = LocalFileMediaLibraryScanner(
      scanIdFactory: () => scanId,
      clock: () => now,
    );

    final MediaScanResult result = await scanner.scan(
      MediaScanScope(
        roots: <Uri>[root.uri],
        extensions: const <String>{'mkv'},
      ),
    );
    final List<MediaScanCandidate> candidates = result.candidates.toList()
      ..sort((MediaScanCandidate left, MediaScanCandidate right) =>
          left.identity.basename.compareTo(right.identity.basename));
    final List<MediaScanEvent> events = await scanner.watch(scanId).toList();

    expect(result.failures, isEmpty);
    expect(candidates, hasLength(2));
    expect(candidates.first.identity.uri, first.uri);
    expect(candidates.first.sizeBytes, 5);
    expect(candidates.first.discoveredAt, now);
    expect(candidates.last.identity.uri, second.uri);
    expect(candidates.last.sizeBytes, 6);
    expect(
      events.whereType<MediaScanCandidateDiscovered>(),
      hasLength(2),
    );
    expect(events.whereType<MediaScanCompleted>(), hasLength(1));
  });

  test('local file scanner attaches probed duration without failing scan',
      () async {
    final Directory root = await Directory.systemTemp.createTemp(
      'elaina-media-duration-scan-',
    );
    addTearDown(() async {
      if (root.existsSync()) await root.delete(recursive: true);
    });
    final File first =
        await File(_join(root.path, 'episode-1.mkv')).writeAsString('first');
    final File second =
        await File(_join(root.path, 'episode-2.mkv')).writeAsString('second');
    const MediaScanId scanId = MediaScanId('local-duration-scan-test');
    final LocalFileMediaLibraryScanner scanner = LocalFileMediaLibraryScanner(
      scanIdFactory: () => scanId,
      durationProbe: _FakeLocalMediaDurationProbe(
        durations: <Uri, Duration>{
          first.uri: const Duration(minutes: 24, seconds: 3),
        },
        failingUris: <Uri>{second.uri},
      ),
    );

    final MediaScanResult result = await scanner.scan(
      MediaScanScope(
        roots: <Uri>[root.uri],
        extensions: const <String>{'mkv'},
      ),
    );
    final List<MediaScanCandidate> candidates = result.candidates.toList()
      ..sort((MediaScanCandidate left, MediaScanCandidate right) =>
          left.identity.basename.compareTo(right.identity.basename));

    expect(result.failures, isEmpty);
    expect(candidates, hasLength(2));
    expect(candidates.first.identity.uri, first.uri);
    expect(candidates.first.duration, const Duration(minutes: 24, seconds: 3));
    expect(candidates.last.identity.uri, second.uri);
    expect(candidates.last.duration, isNull);
  });

  test('storage-backed media library runtime replays state after reopen',
      () async {
    final Directory root = await Directory.systemTemp.createTemp(
      'elaina-media-runtime-',
    );
    addTearDown(() async {
      if (root.existsSync()) await root.delete(recursive: true);
    });
    await File(_join(root.path, 'episode-1.mkv')).writeAsString('video');
    final String databasePath = _join(root.path, 'library.sqlite');
    final DateTime now = DateTime.utc(2026, 6, 17, 13);
    const MediaScanId scanId = MediaScanId('storage-backed-scan');
    final StreamCacheInvalidationBus firstBus = StreamCacheInvalidationBus();
    final List<CacheInvalidationEvent> events = <CacheInvalidationEvent>[];
    final subscription = firstBus.events.listen(events.add);
    final SqliteStorageFoundation firstStorage =
        SqliteStorageFoundation.open(databasePath);
    final MediaLibraryBootstrap firstBootstrap =
        storageBackedMediaLibraryBootstrap(
      storage: firstStorage,
      invalidationBus: firstBus,
      scanner: LocalFileMediaLibraryScanner(
        scanIdFactory: () => scanId,
        clock: () => now,
      ),
      now: () => now,
    );

    final MediaScanResult scan = (await firstBootstrap.scan(
      MediaScanScope(
        roots: <Uri>[root.uri],
        extensions: const <String>{'mkv'},
      ),
    ))
        .value!;
    final MediaImportResult imported =
        (await firstBootstrap.importCandidates(scan.candidates)).value!;
    final MediaLibraryItem item = imported.imported.single;
    await firstBootstrap.runtime.recordHistory(
      PlaybackHistoryEntry(
        id: const PlaybackHistoryEntryId('history-1'),
        mediaId: item.identity.id,
        position: const Duration(minutes: 3),
        duration: const Duration(minutes: 24),
        updatedAt: now,
      ),
    );
    await firstBootstrap.runtime.saveUserBinding(
      ProviderBinding(
        id: const ProviderBindingId('binding-1'),
        localMediaId: item.identity.id,
        providerId: defaultVideoDetailMetadataProviderId,
        subjectId: const ProviderSubjectId('subject-1'),
        authority: ProviderBindingAuthority.userConfirmed,
        confidence: 1,
        createdAt: now,
      ),
    );
    final MediaLibraryActionResult<PlaybackSourceHandoffResult> play =
        await firstBootstrap.runtime.playItem(item.id);

    expect(play.isSuccess, isTrue);
    expect(
      events.whereType<MediaLibraryItemChanged>(),
      hasLength(1),
    );

    firstBootstrap.dispose();
    firstStorage.dispose();
    await subscription.cancel();
    await firstBus.close();

    final SqliteStorageFoundation secondStorage =
        SqliteStorageFoundation.open(databasePath);
    addTearDown(secondStorage.dispose);
    final StreamCacheInvalidationBus secondBus = StreamCacheInvalidationBus();
    addTearDown(secondBus.close);
    final MediaLibraryBootstrap secondBootstrap =
        storageBackedMediaLibraryBootstrap(
      storage: secondStorage,
      invalidationBus: secondBus,
      scanner: LocalFileMediaLibraryScanner(
        scanIdFactory: () => const MediaScanId('unused-after-reopen'),
        clock: () => now,
      ),
      now: () => now,
    );
    addTearDown(secondBootstrap.dispose);

    final MediaLibraryRuntimeSnapshot replayed =
        (await secondBootstrap.refresh()).value!;
    final MediaLibraryCatalogItemState state = replayed.catalogItems.single;
    final MediaLibraryActionResult<PlaybackSourceHandoffResult> replayedPlay =
        await secondBootstrap.runtime.playItem(state.item.id);

    expect(state.item.identity.uri.path, endsWith('episode-1.mkv'));
    expect(state.continueWatching?.position, const Duration(minutes: 3));
    expect(state.binding?.authority, ProviderBindingAuthority.userConfirmed);
    expect(
      replayed.continueWatching.single.mediaId.value,
      state.item.identity.id.value,
    );
    expect(replayedPlay.isSuccess, isTrue);
  });
}

final class _FakeLocalMediaDurationProbe implements LocalMediaDurationProbe {
  const _FakeLocalMediaDurationProbe({
    required this.durations,
    this.failingUris = const <Uri>{},
  });

  final Map<Uri, Duration> durations;
  final Set<Uri> failingUris;

  @override
  Future<Duration?> durationFor(Uri uri) async {
    if (failingUris.contains(uri)) {
      throw StateError('duration probe failed');
    }
    return durations[uri];
  }
}

String _join(String directory, String name) {
  return '$directory${Platform.pathSeparator}$name';
}
