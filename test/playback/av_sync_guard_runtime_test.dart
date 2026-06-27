import 'dart:async';

import 'package:elaina/elaina.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AVSyncGuardRuntime initial', () {
    test('snapshot for supported scope returns projection with seeded health',
        () async {
      final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
      final DeterministicAVSyncGuardStore store = DeterministicAVSyncGuardStore(
        seedHealth: <StoredAVSyncHealthRecord>[
          StoredAVSyncHealthRecord(
            scopeId: 'adapter-1',
            health: StoredAVSyncHealthKind.warning,
            lastDriftMillis: 84,
            sampleCount: 3,
            reason: 'warning drift',
            updatedAt: DateTime.utc(2026, 6, 15, 12),
          ),
        ],
        seedDecisions: <StoredAVSyncDegradationDecisionRecord>[
          StoredAVSyncDegradationDecisionRecord(
            id: 'decision-1',
            scopeId: 'adapter-1',
            health: StoredAVSyncHealthKind.degraded,
            action: AVSyncDegradationAction.reduceEnhancementIntensity.name,
            reason: 'red line',
            occurredAt: DateTime.utc(2026, 6, 15, 12),
          ),
        ],
      );
      final AVSyncGuardRuntime runtime = _bootstrap(
        store: store,
        bus: bus,
      ).createRuntime();

      final AVSyncGuardRuntimeActionResult<AVSyncGuardRuntimeProjection>
          result = await runtime.snapshot('adapter-1');

      expect(result.isSuccess, isTrue);
      expect(result.value!.health, AVSyncHealth.warning);
      expect(result.value!.latestDriftMillis, 84);
      expect(result.value!.latestDegradationAction,
          AVSyncDegradationAction.reduceEnhancementIntensity.name);
      // Restart projection replays stored state
      expect(result.value!.restart.health, StoredAVSyncHealthKind.warning);
      expect(result.value!.restart.latestDegradationAction,
          AVSyncDegradationAction.reduceEnhancementIntensity.name);
      await runtime.dispose();
      await bus.close();
    });
  });

  group('AVSyncGuardRuntime ingestSample', () {
    test('returns typed success with health and drift', () async {
      final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
      final DeterministicAVSyncGuardStore store =
          DeterministicAVSyncGuardStore();
      final AVSyncGuardRuntime runtime = _bootstrap(
        store: store,
        bus: bus,
      ).createRuntime();

      final AVSyncGuardRuntimeActionResult<AVSyncGuardRuntimeProjection>
          result = await runtime.ingestSample('adapter-1', _sample(130));

      expect(result.isSuccess, isTrue);
      expect(result.value!.health, AVSyncHealth.degraded);
      expect(result.value!.latestDriftMillis, 130);
      await runtime.dispose();
      await bus.close();
    });
  });

  group('AVSyncGuardRuntime requestDegradation', () {
    test('returns typed success outcome with degradation action', () async {
      final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
      final DeterministicAVSyncGuardStore store =
          DeterministicAVSyncGuardStore();
      final AVSyncGuardRuntime runtime = _bootstrap(
        store: store,
        bus: bus,
      ).createRuntime();

      final AVSyncGuardRuntimeActionResult<AVSyncGuardRuntimeProjection>
          result = await runtime.requestDegradation('adapter-1', _sample(140));

      expect(result.isSuccess, isTrue);
      expect(result.value!.latestDegradationAction,
          AVSyncDegradationAction.reduceEnhancementIntensity.name);
      await runtime.dispose();
      await bus.close();
    });
  });

  group('AVSyncGuardRuntime checkRecovery', () {
    test('returns typed success on recovered drift', () async {
      final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
      final DeterministicAVSyncGuardStore store =
          DeterministicAVSyncGuardStore();
      final AVSyncGuardRuntime runtime = _bootstrap(
        store: store,
        bus: bus,
      ).createRuntime();

      // Ingert degraded samples then recover
      await runtime.ingestSample('adapter-1', _sample(140));
      await runtime.ingestSample('adapter-1', _sample(140));
      await runtime.ingestSample('adapter-1', _sample(140));
      await runtime.ingestSample('adapter-1', _sample(20));
      await runtime.ingestSample('adapter-1', _sample(20));
      await runtime.ingestSample('adapter-1', _sample(20));

      final AVSyncGuardRuntimeActionResult<AVSyncGuardRuntimeProjection>
          result = await runtime.checkRecovery('adapter-1');

      expect(result.isSuccess, isTrue);
      expect(result.value!.health, AVSyncHealth.target);
      await runtime.dispose();
      await bus.close();
    });
  });

  group('AVSyncGuardRuntime unsupported', () {
    test('unsupported scope ingest returns failure with capabilityUnsupported',
        () async {
      final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
      final AVSyncGuardRuntime runtime = AVSyncGuardBootstrap(
        guardStore: DeterministicAVSyncGuardStore(),
        guardByScope: <String, DeterministicAVSyncGuard>{
          'adapter-unsupported': DeterministicAVSyncGuard(
            policy: AVSyncPolicy(),
            guardStore: DeterministicAVSyncGuardStore(),
            capabilities: PlaybackCapabilityMatrix(
              capabilities: <PlaybackCapability, CapabilityStatus>{
                PlaybackCapability.avSyncGuard:
                    const CapabilityStatus.unsupported('No samples.'),
              },
            ),
            scopeId: 'adapter-unsupported',
            clock: _now,
          ),
        },
        capabilitiesByScope: <String, PlaybackCapabilityMatrix>{
          'adapter-unsupported': PlaybackCapabilityMatrix(
            capabilities: <PlaybackCapability, CapabilityStatus>{
              PlaybackCapability.avSyncGuard:
                  const CapabilityStatus.unsupported('No samples.'),
            },
          ),
        },
        cacheInvalidationBus: bus,
      ).createRuntime();

      final AVSyncGuardRuntimeActionResult<AVSyncGuardRuntimeProjection>
          result =
          await runtime.ingestSample('adapter-unsupported', _sample(0));

      expect(result.isSuccess, isFalse);
      expect(result.failure!.kind,
          AVSyncGuardRuntimeFailureKind.capabilityUnsupported);
      await runtime.dispose();
      await bus.close();
    });
  });

  group('AVSyncGuardRuntime unavailable', () {
    test('unavailable runtime rejects all operations', () async {
      final AVSyncGuardRuntime runtime =
          AVSyncGuardRuntime.unavailable(reason: 'No guard available.');

      final AVSyncGuardRuntimeActionResult<AVSyncGuardRuntimeProjection>
          snapshot = await runtime.snapshot('any');
      final AVSyncGuardRuntimeActionResult<AVSyncGuardRuntimeProjection>
          ingest = await runtime.ingestSample('any', _sample(0));
      final AVSyncGuardRuntimeActionResult<AVSyncGuardRuntimeProjection>
          degradation = await runtime.requestDegradation('any', _sample(140));
      final AVSyncGuardRuntimeActionResult<AVSyncGuardRuntimeProjection>
          recovery = await runtime.checkRecovery('any');

      expect(snapshot.isSuccess, isFalse);
      expect(snapshot.failure!.kind, AVSyncGuardRuntimeFailureKind.unavailable);
      expect(ingest.isSuccess, isFalse);
      expect(ingest.failure!.kind, AVSyncGuardRuntimeFailureKind.unavailable);
      expect(degradation.isSuccess, isFalse);
      expect(
          degradation.failure!.kind, AVSyncGuardRuntimeFailureKind.unavailable);
      expect(recovery.isSuccess, isFalse);
      expect(recovery.failure!.kind, AVSyncGuardRuntimeFailureKind.unavailable);
    });
  });

  group('AVSyncGuardRuntime disposed', () {
    test('disposed runtime rejects snapshot', () async {
      final AVSyncGuardRuntime runtime = _bootstrap().createRuntime();
      await runtime.dispose();

      final AVSyncGuardRuntimeActionResult<AVSyncGuardRuntimeProjection>
          result = await runtime.snapshot('adapter-1');

      expect(result.isSuccess, isFalse);
      expect(result.failure!.kind, AVSyncGuardRuntimeFailureKind.disposed);
    });
  });

  group('AVSyncGuardRuntime invalidations', () {
    test(
        'storage-visible invalidation events arrive after health transition and degradation',
        () async {
      final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
      final DeterministicAVSyncGuardStore store =
          DeterministicAVSyncGuardStore();
      final AVSyncGuardRuntime runtime = _bootstrap(
        store: store,
        bus: bus,
      ).createRuntime();
      final Future<List<CacheInvalidationEvent>> events =
          bus.events.take(4).toList();

      await runtime.ingestSample('adapter-1', _sample(130));
      await runtime.ingestSample('adapter-1', _sample(130));
      await runtime.ingestSample('adapter-1', _sample(140));
      final List<CacheInvalidationEvent> delivered = await events;

      expect(delivered.whereType<AVSyncSampleIngested>(), hasLength(3));
      expect(delivered.whereType<AVSyncHealthTransitioned>(), isNotEmpty);
      await runtime.dispose();
      await bus.close();
    });
  });

  group('AVSyncGuardRuntime restart projection', () {
    test(
        'restart projection replays stored health and latest degradation action',
        () async {
      final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
      final DeterministicAVSyncGuardStore store =
          DeterministicAVSyncGuardStore();
      final AVSyncGuardBootstrap bootstrap = _bootstrap(
        store: store,
        bus: bus,
      );
      final AVSyncGuardRuntime first = bootstrap.createRuntime();

      // Trigger degradation
      await first.ingestSample('adapter-1', _sample(140));
      await first.ingestSample('adapter-1', _sample(140));
      await first.ingestSample('adapter-1', _sample(140));
      await first.requestDegradation('adapter-1', _sample(150));
      await first.dispose();

      // Restart: new runtime with same store
      final AVSyncGuardRuntime second = bootstrap.createRuntime();
      final AVSyncGuardRuntimeActionResult<AVSyncGuardRuntimeProjection>
          result = await second.snapshot('adapter-1');

      expect(result.isSuccess, isTrue);
      expect(result.value!.restart.health, StoredAVSyncHealthKind.degraded);
      expect(result.value!.restart.latestDegradationAction,
          AVSyncDegradationAction.reduceEnhancementIntensity.name);
      await second.dispose();
      await bus.close();
    });
  });

  group('AVSyncGuardMonitorRuntime', () {
    test('samples only while playback is active with a source', () async {
      final AVSyncGuardRuntime runtime = _bootstrap().createRuntime();
      final _FakeAVSyncSampleSource source = _FakeAVSyncSampleSource(
        <AVSyncSample>[_sample(20)],
      );
      final MockPlaybackController controller = MockPlaybackController(
        matrix: _supportedCapabilities(),
        initialState: const PlaybackStateSnapshot(
          status: PlaybackLifecycleStatus.paused,
        ),
      );
      final AVSyncGuardMonitorRuntime monitor = AVSyncGuardMonitorRuntime(
        playbackController: controller,
        sampleSource: source,
        guardRuntime: runtime,
        scopeId: 'adapter-1',
      );

      await monitor.tick();
      await controller.open(LocalFilePlaybackSource(
        uri: Uri.parse('file:///D:/Anime/sample.mkv'),
      ));
      await monitor.tick();
      await controller.play();
      await monitor.tick();

      expect(source.sampleCalls, 1);
      expect(monitor.snapshot.latestDriftMillis, 20);
      expect(monitor.snapshot.sampleCount, 1);
      await monitor.dispose();
      await runtime.dispose();
    });

    test('does not run concurrent samples', () async {
      final AVSyncGuardRuntime runtime = _bootstrap().createRuntime();
      final _BlockingAVSyncSampleSource source = _BlockingAVSyncSampleSource();
      final MockPlaybackController controller = _playingController();
      final AVSyncGuardMonitorRuntime monitor = AVSyncGuardMonitorRuntime(
        playbackController: controller,
        sampleSource: source,
        guardRuntime: runtime,
        scopeId: 'adapter-1',
      );

      final Future<void> firstTick = monitor.tick();
      await Future<void>.delayed(Duration.zero);
      await monitor.tick();
      source.complete(_sample(30));
      await firstTick;

      expect(source.sampleCalls, 1);
      expect(monitor.snapshot.latestDriftMillis, 30);
      await monitor.dispose();
      await runtime.dispose();
    });

    test('records degradation decision after red-line samples', () async {
      final DeterministicAVSyncGuardStore store =
          DeterministicAVSyncGuardStore();
      final AVSyncGuardRuntime runtime =
          _bootstrap(store: store).createRuntime();
      final _FakeAVSyncSampleSource source = _FakeAVSyncSampleSource(
        <AVSyncSample>[_sample(140), _sample(140), _sample(140)],
      );
      final AVSyncGuardMonitorRuntime monitor = AVSyncGuardMonitorRuntime(
        playbackController: _playingController(),
        sampleSource: source,
        guardRuntime: runtime,
        scopeId: 'adapter-1',
      );

      await monitor.tick();
      await monitor.tick();
      await monitor.tick();
      final List<StoredAVSyncDegradationDecisionRecord> decisions =
          await store.degradationHistory('adapter-1');

      expect(monitor.snapshot.health, AVSyncHealth.degraded);
      expect(monitor.snapshot.latestDegradationAction,
          AVSyncDegradationAction.reduceEnhancementIntensity.name);
      expect(decisions, isNotEmpty);
      await monitor.dispose();
      await runtime.dispose();
    });

    test('preserves previous health when sampler fails', () async {
      final AVSyncGuardRuntime runtime = _bootstrap().createRuntime();
      final _FakeAVSyncSampleSource source = _FakeAVSyncSampleSource(
        <AVSyncSample>[_sample(30)],
      );
      final AVSyncGuardMonitorRuntime monitor = AVSyncGuardMonitorRuntime(
        playbackController: _playingController(),
        sampleSource: source,
        guardRuntime: runtime,
        scopeId: 'adapter-1',
      );

      await monitor.tick();
      source.failNext('mpv unavailable');
      await monitor.tick();

      expect(monitor.snapshot.latestDriftMillis, 30);
      expect(monitor.snapshot.latestSampleFailure?.message, 'mpv unavailable');
      await monitor.dispose();
      await runtime.dispose();
    });
  });
}

AVSyncGuardBootstrap _bootstrap({
  DeterministicAVSyncGuardStore? store,
  StreamCacheInvalidationBus? bus,
}) {
  final DeterministicAVSyncGuardStore guardStore =
      store ?? DeterministicAVSyncGuardStore();
  return AVSyncGuardBootstrap(
    guardStore: guardStore,
    guardByScope: <String, DeterministicAVSyncGuard>{
      'adapter-1': DeterministicAVSyncGuard(
        policy: AVSyncPolicy(),
        guardStore: guardStore,
        capabilities: _supportedCapabilities(),
        cacheInvalidationBus: bus,
        scopeId: 'adapter-1',
        clock: _now,
      ),
    },
    capabilitiesByScope: <String, PlaybackCapabilityMatrix>{
      'adapter-1': _supportedCapabilities(),
    },
    cacheInvalidationBus: bus,
  );
}

PlaybackCapabilityMatrix _supportedCapabilities() {
  return PlaybackCapabilityMatrix(
    capabilities: <PlaybackCapability, CapabilityStatus>{
      PlaybackCapability.localFilePlayback: const CapabilityStatus.supported(),
      PlaybackCapability.playPause: const CapabilityStatus.supported(),
      PlaybackCapability.avSyncGuard: const CapabilityStatus.supported(),
    },
  );
}

DateTime _now() => DateTime.utc(2026, 6, 15, 12);

AVSyncSample _sample(int driftMillis) {
  return AVSyncSample(
    audioPosition: Duration(milliseconds: 1000 + driftMillis),
    videoPosition: const Duration(milliseconds: 1000),
    renderDelay: const Duration(milliseconds: 8),
    droppedFrames: 0,
  );
}

MockPlaybackController _playingController() {
  return MockPlaybackController(
    matrix: _supportedCapabilities(),
    initialState: PlaybackStateSnapshot(
      status: PlaybackLifecycleStatus.playing,
      sourceUri: Uri.parse('file:///D:/Anime/sample.mkv'),
    ),
  );
}

final class _FakeAVSyncSampleSource implements AVSyncSampleSource {
  _FakeAVSyncSampleSource(Iterable<AVSyncSample> samples)
      : _samples = List<AVSyncSample>.of(samples);

  final List<AVSyncSample> _samples;
  String? _failureMessage;
  int sampleCalls = 0;

  void failNext(String message) {
    _failureMessage = message;
  }

  @override
  Future<AVSyncSampleReadResult> sample() async {
    sampleCalls += 1;
    final String? failure = _failureMessage;
    if (failure != null) {
      _failureMessage = null;
      return AVSyncSampleReadResult.failure(
        AVSyncSampleReadFailure(
          kind: AVSyncSampleReadFailureKind.backendFailure,
          message: failure,
        ),
      );
    }
    return AVSyncSampleReadResult.success(_samples.removeAt(0));
  }
}

final class _BlockingAVSyncSampleSource implements AVSyncSampleSource {
  final Completer<AVSyncSampleReadResult> _completer =
      Completer<AVSyncSampleReadResult>();
  int sampleCalls = 0;

  void complete(AVSyncSample sample) {
    _completer.complete(AVSyncSampleReadResult.success(sample));
  }

  @override
  Future<AVSyncSampleReadResult> sample() {
    sampleCalls += 1;
    return _completer.future;
  }
}
