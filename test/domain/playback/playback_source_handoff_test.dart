import 'package:celesteria/celesteria.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('prepares local media identity into local file playback source', () {
    const LocalPlaybackSourceHandoff handoff = LocalPlaybackSourceHandoff();
    final LocalMediaIdentity identity = _identity(Uri.file('D:/media/example.mkv'));

    final PlaybackSourceHandoffResult result = handoff.prepare(
      PlaybackSourceHandoffInput.localMediaIdentity(identity),
    );

    expect(result.isSuccess, isTrue);
    expect(result.source, isA<LocalFilePlaybackSource>());
    expect(result.source?.uri, identity.uri);
    expect(result.failure, isNull);
  });

  test('prepares media scan candidate into local file playback source', () {
    const LocalPlaybackSourceHandoff handoff = LocalPlaybackSourceHandoff();
    final MediaScanCandidate candidate = MediaScanCandidate(
      identity: _identity(Uri.file('D:/media/scanned.mkv')),
      sizeBytes: 42,
    );

    final PlaybackSourceHandoffResult result = handoff.prepare(
      PlaybackSourceHandoffInput.mediaScanCandidate(candidate),
    );

    expect(result.isSuccess, isTrue);
    expect(result.source, isA<LocalFilePlaybackSource>());
    expect(result.source?.uri, candidate.identity.uri);
  });

  test('reports unsupported source scheme without throwing', () {
    const LocalPlaybackSourceHandoff handoff = LocalPlaybackSourceHandoff();

    final PlaybackSourceHandoffResult result = handoff.prepare(
      PlaybackSourceHandoffInput.localMediaIdentity(
        _identity(Uri.parse('https://example.test/video.mkv')),
      ),
    );

    expect(result.isSuccess, isFalse);
    expect(result.source, isNull);
    expect(result.failure?.kind, PlaybackSourceHandoffFailureKind.unsupportedScheme);
    expect(result.failure?.uri, Uri.parse('https://example.test/video.mkv'));
  });

  test('reports missing source data without throwing', () {
    const LocalPlaybackSourceHandoff handoff = LocalPlaybackSourceHandoff();

    final PlaybackSourceHandoffResult result = handoff.prepare(
      PlaybackSourceHandoffInput.localMediaIdentity(_identity(Uri.parse(''))),
    );

    expect(result.isSuccess, isFalse);
    expect(result.source, isNull);
    expect(result.failure?.kind, PlaybackSourceHandoffFailureKind.missingSourceData);
    expect(result.failure?.uri, isNull);
  });

  test('controller opens source produced by playback source handoff', () async {
    const LocalPlaybackSourceHandoff handoff = LocalPlaybackSourceHandoff();
    final PlaybackSourceHandoffResult handoffResult = handoff.prepare(
      PlaybackSourceHandoffInput.localMediaIdentity(_identity(Uri.file('D:/media/controller.mkv'))),
    );
    final PlaybackSource source = handoffResult.source!;
    final MockPlaybackController controller = MockPlaybackController(
      matrix: PlaybackCapabilityMatrix(
        capabilities: const <PlaybackCapability, CapabilityStatus>{
          PlaybackCapability.localFilePlayback: CapabilityStatus.supported(),
        },
      ),
    );

    final PlaybackCommandResult openResult = await controller.open(source);

    expect(openResult.isSuccess, isTrue);
    expect(controller.currentState.sourceUri, source.uri);
    expect(controller.currentState.status, PlaybackLifecycleStatus.paused);
  });
}

LocalMediaIdentity _identity(Uri uri) {
  return LocalMediaIdentity(
    id: const LocalMediaId('local-media'),
    uri: uri,
    basename: 'example.mkv',
  );
}
