import 'package:celesteria/celesteria.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('concrete binding maps local file commands to backend operations',
      () async {
    final _FakeMediaKitMpvBackend backend = _FakeMediaKitMpvBackend();
    final MediaKitMpvBinding binding = MediaKitMpvBinding(backend: backend);
    final LocalFilePlaybackSource source = _localSource();

    expect((await binding.load(source)).isSuccess, isTrue);
    expect((await binding.play()).isSuccess, isTrue);
    expect((await binding.pause()).isSuccess, isTrue);
    expect((await binding.seek(const Duration(seconds: 42))).isSuccess, isTrue);
    expect((await binding.stop()).isSuccess, isTrue);
    expect((await binding.dispose()).isSuccess, isTrue);

    expect(backend.openedUri, source.uri);
    expect(backend.seekPosition, const Duration(seconds: 42));
    expect(
      backend.operations,
      <PlaybackOperation>[
        PlaybackOperation.load,
        PlaybackOperation.play,
        PlaybackOperation.pause,
        PlaybackOperation.seek,
        PlaybackOperation.stop,
        PlaybackOperation.dispose,
      ],
    );
    expect(binding.isDisposed, isTrue);
  });

  test('concrete binding rejects non-local sources without backend delegation',
      () async {
    final _FakeMediaKitMpvBackend backend = _FakeMediaKitMpvBackend();
    final MediaKitMpvBinding binding = MediaKitMpvBinding(backend: backend);

    final PlaybackCommandResult result = await binding.load(
      HttpPlaybackSource(uri: Uri.parse('https://example.invalid/video.mkv')),
    );

    expect(result.isSuccess, isFalse);
    expect(result.failure?.kind, PlaybackFailureKind.unsupported);
    expect(backend.operations, isEmpty);
  });

  test('concrete binding normalizes backend operation failures', () async {
    final _FakeMediaKitMpvBackend backend = _FakeMediaKitMpvBackend(
      failOn: PlaybackOperation.play,
    );
    final MediaKitMpvBinding binding = MediaKitMpvBinding(backend: backend);

    final PlaybackCommandResult result = await binding.play();

    expect(result.isSuccess, isFalse);
    expect(result.failure?.operation, PlaybackOperation.play);
    expect(result.failure?.kind, PlaybackFailureKind.operationFailed);
    expect(backend.operations, <PlaybackOperation>[PlaybackOperation.play]);
  });

  test('concrete binding normalizes backend construction failures', () async {
    final MediaKitMpvBinding binding = MediaKitMpvBinding(
      backendFactory: () => throw StateError('native player unavailable'),
    );

    final PlaybackCommandResult result = await binding.play();

    expect(result.isSuccess, isFalse);
    expect(result.failure?.operation, PlaybackOperation.play);
    expect(result.failure?.kind, PlaybackFailureKind.operationFailed);
  });

  test('concrete binding rejects commands after dispose', () async {
    final _FakeMediaKitMpvBackend backend = _FakeMediaKitMpvBackend();
    final MediaKitMpvBinding binding = MediaKitMpvBinding(backend: backend);

    expect((await binding.dispose()).isSuccess, isTrue);
    final PlaybackCommandResult result = await binding.stop();

    expect(result.isSuccess, isFalse);
    expect(result.failure?.operation, PlaybackOperation.stop);
    expect(result.failure?.kind, PlaybackFailureKind.disposed);
    expect(backend.operations, <PlaybackOperation>[PlaybackOperation.dispose]);
  });

  test('concrete binding leaves tracks unsupported until mapped', () async {
    final MediaKitMpvBinding binding = MediaKitMpvBinding(
      backend: _FakeMediaKitMpvBackend(),
    );

    final TrackDiscoveryResult discovery = await binding.discoverTracks();
    final TrackSwitchResult switchResult = await binding.switchTrack(
      const MediaTrackId('subtitle-ja'),
    );

    expect(discovery.tracks, isEmpty);
    expect(
      discovery.capabilityMatrix
          .supports(PlaybackCapability.audioTrackDiscovery),
      isFalse,
    );
    expect(switchResult.isSuccess, isFalse);
  });

  test('local file capability matrix declares only verified operations', () {
    final PlaybackCapabilityMatrix matrix =
        mediaKitLocalFilePlaybackCapabilities();

    expect(matrix.supports(PlaybackCapability.localFilePlayback), isTrue);
    expect(matrix.supports(PlaybackCapability.playPause), isTrue);
    expect(matrix.supports(PlaybackCapability.seek), isTrue);
    expect(matrix.supports(PlaybackCapability.stop), isTrue);
    expect(matrix.supports(PlaybackCapability.httpPlayback), isFalse);
    expect(matrix.supports(PlaybackCapability.hlsPlayback), isFalse);
    expect(matrix.supports(PlaybackCapability.audioTrackDiscovery), isFalse);
    expect(matrix.supports(PlaybackCapability.subtitleTrackSwitching), isFalse);
  });

  test('bootstrap can wire concrete binding with verified capabilities',
      () async {
    final _FakeMediaKitMpvBackend backend = _FakeMediaKitMpvBackend();
    final PlayerCoreBootstrap bootstrap = PlayerCoreBootstrap.withBinding(
      binding: MediaKitMpvBinding(backend: backend),
      capabilities: mediaKitLocalFilePlaybackCapabilities(),
    );

    expect(
      bootstrap.runtime.capabilityMatrix
          .supports(PlaybackCapability.localFilePlayback),
      isTrue,
    );
    expect((await bootstrap.controller.open(_localSource())).isSuccess, isTrue);
    expect((await bootstrap.controller.play()).isSuccess, isTrue);

    final PlaybackCommandResult hlsResult = await bootstrap.controller.open(
      HlsPlaybackSource(
          uri: Uri.parse('https://example.invalid/playlist.m3u8')),
    );

    expect(hlsResult.isSuccess, isFalse);
    expect(hlsResult.failure?.kind, PlaybackFailureKind.unsupported);
    expect(
      backend.operations,
      <PlaybackOperation>[
        PlaybackOperation.load,
        PlaybackOperation.play,
      ],
    );

    await bootstrap.dispose();
  });
}

LocalFilePlaybackSource _localSource() {
  return LocalFilePlaybackSource(uri: Uri.file('D:/media/example.mkv'));
}

final class _FakeMediaKitMpvBackend implements MediaKitMpvBackend {
  _FakeMediaKitMpvBackend({this.failOn});

  final PlaybackOperation? failOn;
  final List<PlaybackOperation> operations = <PlaybackOperation>[];
  Uri? openedUri;
  Duration? seekPosition;

  @override
  Future<void> openLocalFile(Uri uri) async {
    _record(PlaybackOperation.load);
    openedUri = uri;
  }

  @override
  Future<void> play() async {
    _record(PlaybackOperation.play);
  }

  @override
  Future<void> pause() async {
    _record(PlaybackOperation.pause);
  }

  @override
  Future<void> seek(Duration position) async {
    _record(PlaybackOperation.seek);
    seekPosition = position;
  }

  @override
  Future<void> stop() async {
    _record(PlaybackOperation.stop);
  }

  @override
  Future<void> dispose() async {
    _record(PlaybackOperation.dispose);
  }

  void _record(PlaybackOperation operation) {
    operations.add(operation);
    if (failOn == operation) {
      throw StateError('forced $operation failure');
    }
  }
}
