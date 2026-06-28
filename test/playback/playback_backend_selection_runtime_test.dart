import 'dart:async';

import 'package:elaina/elaina.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defaults to MPV backend and routes local file load to primary',
      () async {
    final _RecordingAdapter mpv = _RecordingAdapter(
      id: playbackBackendMediaKitMpvId,
      displayName: 'MPV',
      capabilities: _mpvCapabilities(),
    );
    final VlcFallbackAdapter vlc =
        VlcFallbackAdapter(backend: _RecordingVlcBackend());
    final FakeSettingsRuntime settings = FakeSettingsRuntime();
    final PlaybackBackendSelectionRuntime runtime = _runtime(
      settings: settings,
      mpv: mpv,
      vlc: vlc,
    );

    final PlaybackBackendSelectionSnapshot snapshot = await runtime.snapshot();
    final PlaybackCommandResult result = await runtime.load(
      LocalFilePlaybackSource(uri: Uri.file('D:/media/a.mkv')),
    );

    expect(snapshot.configuredMode, PlaybackBackendMode.mediaKitMpv);
    expect(snapshot.activeBackendId, playbackBackendMediaKitMpvId);
    expect(result.isSuccess, isTrue);
    expect(mpv.calls, <String>['load:file:///D:/media/a.mkv']);

    await runtime.dispose();
  });

  test('forced VLC mode does not call MPV load', () async {
    final _RecordingAdapter mpv = _RecordingAdapter(
      id: playbackBackendMediaKitMpvId,
      displayName: 'MPV',
      capabilities: _mpvCapabilities(),
    );
    final _RecordingVlcBackend vlcBackend = _RecordingVlcBackend();
    final VlcFallbackAdapter vlc = VlcFallbackAdapter(backend: vlcBackend);
    final FakeSettingsRuntime settings = FakeSettingsRuntime();
    final PlaybackBackendSelectionRuntime runtime = _runtime(
      settings: settings,
      mpv: mpv,
      vlc: vlc,
    );

    await runtime.selectMode(PlaybackBackendMode.vlcFallback);
    final PlaybackCommandResult result = await runtime.load(
      LocalFilePlaybackSource(uri: Uri.file('D:/media/b.mkv')),
    );
    final PlaybackBackendSelectionSnapshot snapshot = await runtime.snapshot();

    expect(result.isSuccess, isTrue);
    expect(snapshot.activeBackendId, playbackBackendVlcFallbackId);
    expect(mpv.calls, isEmpty);
    expect(vlcBackend.calls, <String>['openLocalFile:file:///D:/media/b.mkv']);

    await runtime.dispose();
  });

  test('active backend id stream only emits for real backend switches',
      () async {
    final _ManualTelemetrySource mpvTelemetry = _ManualTelemetrySource();
    final _RecordingAdapter mpv = _RecordingAdapter(
      id: playbackBackendMediaKitMpvId,
      displayName: 'MPV',
      capabilities: _mpvCapabilities(),
    );
    final _RecordingVlcBackend vlcBackend = _RecordingVlcBackend();
    final VlcFallbackAdapter vlc = VlcFallbackAdapter(backend: vlcBackend);
    final FakeSettingsRuntime settings = FakeSettingsRuntime();
    final PlaybackBackendSelectionRuntime runtime = _runtime(
      settings: settings,
      mpv: mpv,
      vlc: vlc,
      mpvTelemetry: mpvTelemetry,
    );
    final List<String> activeBackendIds = <String>[];
    final StreamSubscription<String> subscription =
        runtime.activeBackendIdChanges.listen(activeBackendIds.add);

    mpvTelemetry.emit(
      PlayerTelemetrySnapshot(position: const Duration(seconds: 1)),
    );
    await pumpEventQueue();
    expect(activeBackendIds, isEmpty);

    await runtime.selectMode(PlaybackBackendMode.vlcFallback);
    await pumpEventQueue();
    expect(activeBackendIds, <String>[playbackBackendVlcFallbackId]);

    mpvTelemetry.emit(
      PlayerTelemetrySnapshot(position: const Duration(seconds: 2)),
    );
    await pumpEventQueue();
    expect(activeBackendIds, <String>[playbackBackendVlcFallbackId]);

    await runtime.selectMode(PlaybackBackendMode.mediaKitMpv);
    await pumpEventQueue();
    expect(activeBackendIds, <String>[
      playbackBackendVlcFallbackId,
      playbackBackendMediaKitMpvId,
    ]);

    await subscription.cancel();
    await runtime.dispose();
    await mpvTelemetry.dispose();
  });

  test('auto fallback switches to VLC after compatible MPV load failure',
      () async {
    final _RecordingAdapter mpv = _RecordingAdapter(
      id: playbackBackendMediaKitMpvId,
      displayName: 'MPV',
      capabilities: _mpvCapabilities(),
      loadFailure: const PlaybackFailure(
        operation: PlaybackOperation.load,
        kind: PlaybackFailureKind.operationFailed,
        message: 'MPV codec rejected file.',
      ),
    );
    final _RecordingVlcBackend vlcBackend = _RecordingVlcBackend();
    final VlcFallbackAdapter vlc = VlcFallbackAdapter(backend: vlcBackend);
    final FakeSettingsRuntime settings = FakeSettingsRuntime();
    final PlaybackBackendSelectionRuntime runtime = _runtime(
      settings: settings,
      mpv: mpv,
      vlc: vlc,
    );

    await runtime.selectMode(PlaybackBackendMode.autoFallback);
    final PlaybackCommandResult result = await runtime.load(
      LocalFilePlaybackSource(uri: Uri.file('D:/media/c.mkv')),
    );
    final PlaybackBackendSelectionSnapshot snapshot = await runtime.snapshot();

    expect(result.isSuccess, isTrue);
    expect(snapshot.activeBackendId, playbackBackendVlcFallbackId);
    expect(snapshot.latestFallbackReason, contains('MPV 加载失败'));
    expect(snapshot.hiddenCapabilities,
        contains(PlaybackCapability.videoEnhancement));
    expect(snapshot.hiddenCapabilities,
        contains(PlaybackCapability.anime4kPreset));
    expect(vlcBackend.calls, <String>['openLocalFile:file:///D:/media/c.mkv']);

    await runtime.selectMode(PlaybackBackendMode.mediaKitMpv);
    final PlaybackBackendSelectionSnapshot restored = await runtime.snapshot();
    expect(restored.activeBackendId, playbackBackendMediaKitMpvId);
    expect(restored.latestFallbackReason, isNull);
    expect(restored.hiddenCapabilities, isEmpty);

    await runtime.dispose();
  });
}

PlaybackBackendSelectionRuntime _runtime({
  required FakeSettingsRuntime settings,
  required _RecordingAdapter mpv,
  required VlcFallbackAdapter vlc,
  PlayerTelemetrySource? mpvTelemetry,
}) {
  return PlaybackBackendSelectionRuntime(
    settingsRuntime: settings,
    mediaKitMpvAdapter: mpv,
    mediaKitMpvProbeSource: _FakeProbeSource(
      label: mpv.displayName,
      matrix: mpv.capabilities,
    ),
    mediaKitMpvTelemetrySource: mpvTelemetry,
    vlcFallbackAdapter: vlc,
    vlcFallbackProbeSource: vlc,
  );
}

PlaybackCapabilityMatrix _mpvCapabilities() {
  return PlaybackCapabilityMatrix(
    capabilities: <PlaybackCapability, CapabilityStatus>{
      for (final PlaybackCapability capability in PlaybackCapability.values)
        capability: const CapabilityStatus.unsupported('unsupported in test'),
      PlaybackCapability.localFilePlayback: const CapabilityStatus.supported(),
      PlaybackCapability.playPause: const CapabilityStatus.supported(),
      PlaybackCapability.seek: const CapabilityStatus.supported(),
      PlaybackCapability.stop: const CapabilityStatus.supported(),
      PlaybackCapability.progressReporting: const CapabilityStatus.supported(),
      PlaybackCapability.videoEnhancement: const CapabilityStatus.supported(),
      PlaybackCapability.hdrToneMapping: const CapabilityStatus.supported(),
      PlaybackCapability.debandFiltering: const CapabilityStatus.supported(),
      PlaybackCapability.anime4kPreset: const CapabilityStatus.supported(),
    },
  );
}

final class _FakeProbeSource implements PlaybackCapabilityProbeSource {
  const _FakeProbeSource({required this.label, required this.matrix});

  final String label;
  final PlaybackCapabilityMatrix matrix;

  @override
  PlaybackCapabilityProbeSnapshot get currentCapabilityProbe {
    return PlaybackCapabilityProbeSnapshot(
      capabilities: matrix,
      checkedAt: DateTime.utc(2026),
      source: 'test',
      backendLabel: label,
    );
  }
}

final class _RecordingAdapter implements PlayerAdapter {
  _RecordingAdapter({
    required this.id,
    required this.displayName,
    required this.capabilities,
    this.loadFailure,
  });

  @override
  final String id;

  @override
  final String displayName;

  @override
  final PlaybackCapabilityMatrix capabilities;

  final PlaybackFailure? loadFailure;
  final List<String> calls = <String>[];

  @override
  Future<PlaybackCommandResult> load(PlaybackSource source) async {
    calls.add('load:${source.uri}');
    final PlaybackFailure? failure = loadFailure;
    if (failure != null) return PlaybackCommandResult.failure(failure);
    return const PlaybackCommandResult.success();
  }

  @override
  Future<PlaybackCommandResult> play() async {
    calls.add('play');
    return const PlaybackCommandResult.success();
  }

  @override
  Future<PlaybackCommandResult> pause() async {
    calls.add('pause');
    return const PlaybackCommandResult.success();
  }

  @override
  Future<PlaybackCommandResult> seek(Duration position) async {
    calls.add('seek:$position');
    return const PlaybackCommandResult.success();
  }

  @override
  Future<PlaybackCommandResult> stop() async {
    calls.add('stop');
    return const PlaybackCommandResult.success();
  }

  @override
  Future<PlaybackCommandResult> dispose() async {
    calls.add('dispose');
    return const PlaybackCommandResult.success();
  }

  @override
  Future<TrackDiscoveryResult> discoverTracks() async {
    return TrackDiscoveryResult.unsupported(reason: 'test');
  }

  @override
  Future<TrackSwitchResult> switchTrack(MediaTrackId trackId) async {
    return const TrackSwitchResult.unsupported('test');
  }

  @override
  Future<EnhancementApplyOutcome> applyEnhancement(
    VideoEnhancementProfile profile,
  ) async {
    return EnhancementApplyOutcome.applied(profile: profile);
  }

  @override
  Future<EnhancementDisableOutcome> disableEnhancement() async {
    return const EnhancementDisableOutcome.disabled();
  }
}

final class _ManualTelemetrySource implements PlayerTelemetrySource {
  final StreamController<PlayerTelemetrySnapshot> _controller =
      StreamController<PlayerTelemetrySnapshot>.broadcast(sync: true);

  PlayerTelemetrySnapshot _current = PlayerTelemetrySnapshot();

  @override
  PlayerTelemetrySnapshot get currentTelemetry => _current;

  @override
  Stream<PlayerTelemetrySnapshot> get telemetry => _controller.stream;

  void emit(PlayerTelemetrySnapshot snapshot) {
    _current = snapshot;
    _controller.add(snapshot);
  }

  Future<void> dispose() {
    return _controller.close();
  }
}

final class _RecordingVlcBackend implements VlcFallbackBackend {
  final List<String> calls = <String>[];

  @override
  Future<void> openLocalFile(Uri uri) async {
    calls.add('openLocalFile:$uri');
  }

  @override
  Future<void> play() async {
    calls.add('play');
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
  }

  @override
  Future<void> seek(Duration position) async {
    calls.add('seek:$position');
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
  }

  @override
  Future<void> dispose() async {
    calls.add('dispose');
  }
}
