import 'package:celesteria/celesteria.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizes file scan scope extensions and exclude patterns', () {
    final MediaScanScopeNormalizationResult result = normalizeMediaScanScope(
      MediaScanScope(
        roots: <Uri>[Uri.parse('file:///D:/media/')],
        extensions: <String>{'.MKV', ' mp4 ', ''},
        excludePatterns: const <String>[' Skip ', ''],
      ),
    );

    expect(result.isSuccess, isTrue);
    expect(result.scope?.extensions, <String>{'mkv', 'mp4'});
    expect(result.scope?.excludePatterns, <String>['skip']);
    expect(
      result.scope?.accepts(Uri.parse('file:///D:/media/episode.mkv'), basename: 'episode.mkv'),
      isTrue,
    );
    expect(
      result.scope?.accepts(Uri.parse('file:///D:/media/skip/episode.mkv'), basename: 'episode.mkv'),
      isFalse,
    );
  });

  test('normalization reports unsupported scan root scheme', () {
    final MediaScanScopeNormalizationResult result = normalizeMediaScanScope(
      MediaScanScope(
        roots: <Uri>[Uri.parse('https://example.test/media/')],
        extensions: const <String>{'mkv'},
      ),
    );

    expect(result.isSuccess, isFalse);
    expect(result.failures.single.kind, MediaScanFailureKind.unsupportedScheme);
    expect(result.failures.single.uri, Uri.parse('https://example.test/media/'));
  });

  test('deterministic scanner publishes accepted candidates and completion event', () async {
    const MediaScanId scanId = MediaScanId('scan-accepted');
    final MediaScanCandidate candidate = _candidate(Uri.parse('file:///D:/media/episode.mkv'));
    final DeterministicMediaLibraryScanner scanner = DeterministicMediaLibraryScanner(
      scanId: scanId,
      candidates: <MediaScanCandidate>[candidate],
    );

    final MediaScanResult result = await scanner.scan(_scope());
    final List<MediaScanEvent> events = await scanner.watch(scanId).toList();

    expect(result.candidates.single, candidate);
    expect(result.failures, isEmpty);
    expect(events.whereType<MediaScanCandidateDiscovered>().single.candidate, candidate);
    expect(events.whereType<MediaScanProgressChanged>().single.scannedCount, 1);
    expect(events.whereType<MediaScanCompleted>().single.result, result);
  });

  test('deterministic scanner reports excluded and unreadable entries as typed failures', () async {
    const MediaScanId scanId = MediaScanId('scan-failures');
    final DeterministicMediaLibraryScanner scanner = DeterministicMediaLibraryScanner(
      scanId: scanId,
      candidates: <MediaScanCandidate>[
        _candidate(Uri.parse('file:///D:/media/skip/episode.mkv')),
      ],
      unreadableEntries: <MediaScanFailure>[
        MediaScanFailure(
          kind: MediaScanFailureKind.unreadableEntry,
          uri: Uri.parse('file:///D:/media/broken.mkv'),
          message: 'Unreadable test entry.',
        ),
      ],
    );

    final MediaScanResult result = await scanner.scan(_scope(excludePatterns: const <String>['skip']));

    expect(result.candidates, isEmpty);
    expect(result.failures.map((MediaScanFailure failure) => failure.kind), <MediaScanFailureKind>[
      MediaScanFailureKind.unreadableEntry,
      MediaScanFailureKind.excluded,
    ]);
  });

  test('deterministic scanner cancellation is idempotent and terminal', () async {
    const MediaScanId scanId = MediaScanId('scan-cancelled');
    final DeterministicMediaLibraryScanner scanner = DeterministicMediaLibraryScanner(scanId: scanId);

    await scanner.cancel(scanId);
    await scanner.cancel(scanId);
    final MediaScanResult result = await scanner.scan(_scope());
    final List<MediaScanEvent> events = await scanner.watch(scanId).toList();

    expect(result.candidates, isEmpty);
    expect(result.failures.single.kind, MediaScanFailureKind.cancelled);
    expect(events.whereType<MediaScanCancelled>().length, 1);
  });

  test('scanner-produced candidate remains compatible with playback source handoff', () async {
    const MediaScanId scanId = MediaScanId('scan-handoff');
    final DeterministicMediaLibraryScanner scanner = DeterministicMediaLibraryScanner(
      scanId: scanId,
      candidates: <MediaScanCandidate>[
        _candidate(Uri.parse('file:///D:/media/handoff.mkv')),
      ],
    );

    final MediaScanResult scanResult = await scanner.scan(_scope());
    final PlaybackSourceHandoffResult handoffResult = const LocalPlaybackSourceHandoff().prepare(
      PlaybackSourceHandoffInput.mediaScanCandidate(scanResult.candidates.single),
    );

    expect(handoffResult.isSuccess, isTrue);
    expect(handoffResult.source, isA<LocalFilePlaybackSource>());
    expect(handoffResult.source?.uri, scanResult.candidates.single.identity.uri);
  });

  test('invalid scanner candidate uses existing handoff failure', () {
    final PlaybackSourceHandoffResult handoffResult = const LocalPlaybackSourceHandoff().prepare(
      PlaybackSourceHandoffInput.mediaScanCandidate(
        _candidate(Uri.parse('https://example.test/media.mkv')),
      ),
    );

    expect(handoffResult.isSuccess, isFalse);
    expect(handoffResult.failure?.kind, PlaybackSourceHandoffFailureKind.unsupportedScheme);
  });
}

MediaScanScope _scope({List<String> excludePatterns = const <String>[]}) {
  return MediaScanScope(
    roots: <Uri>[Uri.parse('file:///D:/media/')],
    extensions: const <String>{'mkv'},
    excludePatterns: excludePatterns,
  );
}

MediaScanCandidate _candidate(Uri uri) {
  return MediaScanCandidate(
    identity: LocalMediaIdentity(
      id: const LocalMediaId('local-media'),
      uri: uri,
      basename: uri.pathSegments.isEmpty ? 'episode.mkv' : uri.pathSegments.last,
    ),
    sizeBytes: 42,
  );
}
