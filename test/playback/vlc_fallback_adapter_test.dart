import 'package:celesteria/celesteria.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('adapter delegates local file commands to backend', () async {
    final _RecordingVlcBackend backend = _RecordingVlcBackend();
    final VlcFallbackAdapter adapter = VlcFallbackAdapter(backend: backend);
    final Uri uri = Uri.file('D:/media/fallback.mkv');

    expect((await adapter.load(LocalFilePlaybackSource(uri: uri))).isSuccess,
        isTrue);
    expect((await adapter.play()).isSuccess, isTrue);
    expect((await adapter.pause()).isSuccess, isTrue);
    expect((await adapter.seek(const Duration(seconds: 42))).isSuccess, isTrue);
    expect((await adapter.stop()).isSuccess, isTrue);
    expect((await adapter.dispose()).isSuccess, isTrue);

    expect(backend.calls, <String>[
      'openLocalFile:$uri',
      'play',
      'pause',
      'seek:0:00:42.000000',
      'stop',
      'dispose',
    ]);
  });

  test('adapter rejects unsupported sources without backend delegation',
      () async {
    final _RecordingVlcBackend backend = _RecordingVlcBackend();
    final VlcFallbackAdapter adapter = VlcFallbackAdapter(backend: backend);

    final PlaybackCommandResult result = await adapter.load(
      HttpPlaybackSource(uri: Uri.parse('https://example.test/video.m3u8')),
    );

    expect(result.isSuccess, isFalse);
    expect(result.failure?.kind, PlaybackFailureKind.unsupported);
    expect(backend.calls, isEmpty);
  });

  test('adapter reports unavailable when no backend is supplied', () async {
    final VlcFallbackAdapter adapter = VlcFallbackAdapter();

    expect(
      adapter.capabilities
          .statusOf(PlaybackCapability.fallbackAdapter)
          .isSupported,
      isFalse,
    );

    final PlaybackCommandResult result = await adapter.play();

    expect(result.isSuccess, isFalse);
    expect(result.failure?.kind, PlaybackFailureKind.adapterUnavailable);
  });

  test('adapter normalizes backend operation failures', () async {
    final VlcFallbackAdapter adapter = VlcFallbackAdapter(
      backend: _RecordingVlcBackend(failOn: 'pause'),
    );

    final PlaybackCommandResult result = await adapter.pause();

    expect(result.isSuccess, isFalse);
    expect(result.failure?.kind, PlaybackFailureKind.operationFailed);
  });

  test('adapter normalizes backend factory failures', () async {
    final VlcFallbackAdapter adapter = VlcFallbackAdapter(
      backendFactory: () => throw StateError('VLC backend creation failed'),
    );

    final PlaybackCommandResult result = await adapter.play();

    expect(result.isSuccess, isFalse);
    expect(result.failure?.kind, PlaybackFailureKind.operationFailed);
  });

  test('adapter rejects commands after dispose', () async {
    final VlcFallbackAdapter adapter = VlcFallbackAdapter(
      backend: _RecordingVlcBackend(),
    );

    expect((await adapter.dispose()).isSuccess, isTrue);
    final PlaybackCommandResult result = await adapter.play();

    expect(result.isSuccess, isFalse);
    expect(result.failure?.kind, PlaybackFailureKind.disposed);
  });

  test('fallback candidate selects VLC and exposes hidden capabilities',
      () async {
    final DeterministicPlaybackFallbackStrategy strategy =
        DeterministicPlaybackFallbackStrategy(
      store: DeterministicFallbackAdapterStore(),
      scopeId: 'playback-scope',
    );
    final FallbackRegistrationOutcome registered = await strategy.register(
      vlcFallbackAdapterCandidate(backend: _RecordingVlcBackend()),
    );
    final FallbackEvaluationOutcome selected = await strategy.selectFallback(
      source: LocalFilePlaybackSource(uri: Uri.file('D:/media/fallback.mkv')),
      failure: const FallbackFailure(
        kind: FallbackFailureKind.loadFailure,
        message: 'Primary adapter failed to load.',
      ),
    );

    expect(registered.isSuccess, isTrue);
    expect(selected.isSuccess, isTrue);
    expect(selected.selection?.candidate.id.value, vlcFallbackAdapterId);
    expect(selected.selection?.hiddenCapabilities,
        contains(PlaybackCapability.videoEnhancement));
    expect(selected.selection?.hiddenCapabilities,
        contains(PlaybackCapability.danmakuRendering));
  });

  test('candidate without backend is rejected by fallback strategy', () async {
    final DeterministicPlaybackFallbackStrategy strategy =
        DeterministicPlaybackFallbackStrategy(
      store: DeterministicFallbackAdapterStore(),
    );

    final FallbackRegistrationOutcome result =
        await strategy.register(vlcFallbackAdapterCandidate());

    expect(result.isSuccess, isFalse);
    expect(
      result.failure?.kind,
      FallbackRegistrationFailureKind.capabilityUnsupported,
    );
  });
}

final class _RecordingVlcBackend implements VlcFallbackBackend {
  _RecordingVlcBackend({this.failOn});

  final String? failOn;
  final List<String> calls = <String>[];

  @override
  Future<void> openLocalFile(Uri uri) async {
    _record('openLocalFile:$uri');
  }

  @override
  Future<void> play() async {
    _record('play');
  }

  @override
  Future<void> pause() async {
    _record('pause');
  }

  @override
  Future<void> seek(Duration position) async {
    _record('seek:$position');
  }

  @override
  Future<void> stop() async {
    _record('stop');
  }

  @override
  Future<void> dispose() async {
    _record('dispose');
  }

  void _record(String call) {
    if (call == failOn) {
      throw StateError('forced VLC backend failure');
    }
    calls.add(call);
  }
}
