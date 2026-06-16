import 'package:celesteria/celesteria.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('prepares local media identity into local file playback source', () {
    const LocalPlaybackSourceHandoff handoff = LocalPlaybackSourceHandoff();
    final LocalMediaIdentity identity =
        _identity(Uri.file('D:/media/example.mkv'));

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
    expect(result.failure?.kind,
        PlaybackSourceHandoffFailureKind.unsupportedScheme);
    expect(result.failure?.uri, Uri.parse('https://example.test/video.mkv'));
  });

  test('reports missing source data without throwing', () {
    const LocalPlaybackSourceHandoff handoff = LocalPlaybackSourceHandoff();

    final PlaybackSourceHandoffResult result = handoff.prepare(
      PlaybackSourceHandoffInput.localMediaIdentity(_identity(Uri.parse(''))),
    );

    expect(result.isSuccess, isFalse);
    expect(result.source, isNull);
    expect(result.failure?.kind,
        PlaybackSourceHandoffFailureKind.missingSourceData);
    expect(result.failure?.uri, isNull);
  });

  test('prepares virtual stream source value into playback source', () {
    const LocalPlaybackSourceHandoff handoff = LocalPlaybackSourceHandoff();
    final Uri uri = Uri.parse('celesteria-virtual-stream://task-1%3A%3A1');

    final PlaybackSourceHandoffResult result = handoff.prepare(
      PlaybackSourceHandoffInput.virtualStreamSource(
        VirtualStreamPlaybackSource.fromDescriptor(
          PlaybackVirtualStreamDescriptor(
            id: const VirtualPlaybackStreamId('task-1::1'),
            contentUri: uri,
          ),
        ),
      ),
    );

    expect(result.isSuccess, isTrue);
    expect(result.source, isA<VirtualStreamPlaybackSource>());
    expect(result.source?.uri, uri);
    expect((result.source as VirtualStreamPlaybackSource).streamId.value,
        'task-1::1');
  });

  test('prepares virtual stream descriptor into playback source', () {
    const LocalPlaybackSourceHandoff handoff = LocalPlaybackSourceHandoff();
    final Uri uri = Uri.parse('celesteria-virtual-stream://task-2%3A%3A0');

    final PlaybackSourceHandoffResult result = handoff.prepare(
      PlaybackSourceHandoffInput.virtualStreamDescriptor(
        PlaybackVirtualStreamDescriptor(
          id: const VirtualPlaybackStreamId('task-2::0'),
          contentUri: uri,
        ),
      ),
    );

    expect(result.isSuccess, isTrue);
    expect(result.source, isA<VirtualStreamPlaybackSource>());
    expect(result.source?.uri, uri);
    expect((result.source as VirtualStreamPlaybackSource).streamId.value,
        'task-2::0');
  });

  test('prepares virtual stream snapshot into playback source', () {
    const LocalPlaybackSourceHandoff handoff = LocalPlaybackSourceHandoff();
    final VirtualMediaStreamSnapshot snapshot = VirtualMediaStreamSnapshot(
      descriptor: const VirtualMediaStreamDescriptor(
        id: VirtualMediaStreamId('task-3::0'),
        taskId: BtTaskId('task-3'),
        fileIndex: BtFileIndex(0),
        lengthBytes: 1024,
      ),
      lifecycleState: StoredVirtualMediaStreamLifecycleState.active,
      createdAt: DateTime.utc(2026, 6, 12, 12),
      updatedAt: DateTime.utc(2026, 6, 12, 12),
      restart: const VirtualStreamRestartProjection(
        streamId: VirtualMediaStreamId('task-3::0'),
        disposition: VirtualStreamRestartDisposition.active,
        requiresTaskReconciliation: true,
      ),
    );

    final PlaybackSourceHandoffResult result = handoff.prepare(
      PlaybackSourceHandoffInput.virtualStreamDescriptor(
        _playbackDescriptorFromVirtualSnapshot(snapshot),
      ),
    );

    expect(result.isSuccess, isTrue);
    expect(result.source, isA<VirtualStreamPlaybackSource>());
    expect(result.source?.uri,
        Uri.parse('celesteria-virtual-stream://task-3%3A%3A0'));
  });

  test('converts virtual stream descriptors in playback source layer', () {
    final PlaybackSource source = VirtualStreamPlaybackSource.fromDescriptor(
      const PlaybackVirtualStreamDescriptor(
        id: VirtualPlaybackStreamId('task-1::1'),
      ),
    );

    expect(source, isA<VirtualStreamPlaybackSource>());
    expect(source.uri, Uri.parse('celesteria-virtual-stream://task-1%3A%3A1'));
    expect((source as VirtualStreamPlaybackSource).streamId.value, 'task-1::1');
  });

  test('reports unsupported direct playback source input', () {
    const LocalPlaybackSourceHandoff handoff = LocalPlaybackSourceHandoff();

    final PlaybackSourceHandoffResult result = handoff.prepare(
      PlaybackSourceHandoffInput.unsupportedSource(
        StoredBtTaskRecord(
          id: 'task-raw',
          sourceKind: StoredBtTaskSourceKind.magnet,
          sourceUri: 'magnet:?xt=urn:btih:raw',
          lifecycleState: StoredBtTaskLifecycleState.ready,
          createdAt: DateTime.utc(2026, 6, 12, 12),
          updatedAt: DateTime.utc(2026, 6, 12, 12),
        ),
      ),
    );

    expect(result.isSuccess, isFalse);
    expect(result.source, isNull);
    expect(result.failure?.kind,
        PlaybackSourceHandoffFailureKind.unsupportedSource);
  });

  test('controller opens source produced by playback source handoff', () async {
    const LocalPlaybackSourceHandoff handoff = LocalPlaybackSourceHandoff();
    final PlaybackSourceHandoffResult handoffResult = handoff.prepare(
      PlaybackSourceHandoffInput.localMediaIdentity(
          _identity(Uri.file('D:/media/controller.mkv'))),
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

PlaybackVirtualStreamDescriptor _playbackDescriptorFromVirtualSnapshot(
  VirtualMediaStreamSnapshot snapshot,
) {
  return PlaybackVirtualStreamDescriptor(
    id: VirtualPlaybackStreamId(snapshot.descriptor.id.value),
    contentUri: snapshot.descriptor.contentUri,
  );
}
