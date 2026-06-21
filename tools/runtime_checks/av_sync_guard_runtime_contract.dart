import '../../lib/elaina.dart';

Future<void> main() async {
  await verifyAVSyncGuardRuntimeContract();
}

Future<void> verifyAVSyncGuardRuntimeContract() async {
  final _RuntimeHarness harness = await _harness();

  // Initial snapshot from seeded store.
  final AVSyncGuardRuntimeActionResult<AVSyncGuardRuntimeProjection> initial =
      await harness.runtime.snapshot('adapter-1');
  _expect(initial.isSuccess, 'Initial runtime snapshot must pass.');
  _expect(initial.value?.health == AVSyncHealth.warning,
      'Runtime snapshot must replay stored warning health.');
  _expect(initial.value?.latestDriftMillis == 84,
      'Runtime snapshot must replay stored drift millis.');
  _expect(
      initial.value?.latestDegradationAction ==
          AVSyncDegradationAction.reduceEnhancementIntensity.name,
      'Runtime snapshot must replay stored degradation action.');
  _expect(initial.value?.restart.health == StoredAVSyncHealthKind.warning,
      'Runtime restart projection must replay stored health kind.');
  _expect(
      initial.value?.restart.latestDegradationAction ==
          AVSyncDegradationAction.reduceEnhancementIntensity.name,
      'Runtime restart projection must replay stored degradation action.');

  // Ingest sample returns typed success with health and drift.
  final AVSyncGuardRuntimeActionResult<AVSyncGuardRuntimeProjection> ingested =
      await harness.runtime.ingestSample('adapter-1', _sample(130));
  _expect(ingested.isSuccess, 'Ingest sample must return typed success.');
  _expect(ingested.value?.health == AVSyncHealth.degraded,
      'Ingest sample must expose degraded health.');
  _expect(ingested.value?.latestDriftMillis == 130,
      'Ingest sample must expose drift millis.');

  // Request degradation returns typed success with action.
  final AVSyncGuardRuntimeActionResult<AVSyncGuardRuntimeProjection> degraded =
      await harness.runtime.requestDegradation('adapter-1', _sample(140));
  _expect(degraded.isSuccess, 'Request degradation must return typed success.');
  _expect(
      degraded.value?.latestDegradationAction ==
          AVSyncDegradationAction.reduceEnhancementIntensity.name,
      'Request degradation must expose degradation action.');

  // Check recovery after target samples.
  await harness.runtime.ingestSample('adapter-1', _sample(20));
  await harness.runtime.ingestSample('adapter-1', _sample(20));
  await harness.runtime.ingestSample('adapter-1', _sample(20));
  final AVSyncGuardRuntimeActionResult<AVSyncGuardRuntimeProjection> recovered =
      await harness.runtime.checkRecovery('adapter-1');
  _expect(recovered.isSuccess, 'Check recovery must return typed success.');
  _expect(recovered.value?.health == AVSyncHealth.target,
      'Check recovery must expose target health after recovery.');

  // Unsupported capability returns typed failure.
  final AVSyncGuardRuntimeActionResult<AVSyncGuardRuntimeProjection>
      unsupported = await harness.unsupportedRuntime
          .ingestSample('adapter-unsupported', _sample(0));
  _expect(
      unsupported.failure?.kind ==
          AVSyncGuardRuntimeFailureKind.capabilityUnsupported,
      'Unsupported scope must return capabilityUnsupported failure.');

  // Unavailable runtime rejects all operations.
  final AVSyncGuardRuntime unavailable =
      AVSyncGuardRuntime.unavailable(reason: 'No guard available.');
  await _expectFailure(
    unavailable.snapshot('any'),
    AVSyncGuardRuntimeFailureKind.unavailable,
    'Unavailable runtime must reject snapshot.',
  );
  await _expectFailure(
    unavailable.ingestSample('any', _sample(0)),
    AVSyncGuardRuntimeFailureKind.unavailable,
    'Unavailable runtime must reject ingest.',
  );
  await _expectFailure(
    unavailable.requestDegradation('any', _sample(140)),
    AVSyncGuardRuntimeFailureKind.unavailable,
    'Unavailable runtime must reject degradation.',
  );
  await _expectFailure(
    unavailable.checkRecovery('any'),
    AVSyncGuardRuntimeFailureKind.unavailable,
    'Unavailable runtime must reject recovery.',
  );

  // Disposed runtime rejects snapshot.
  await harness.runtime.dispose();
  await _expectFailure(
    harness.runtime.snapshot('adapter-1'),
    AVSyncGuardRuntimeFailureKind.disposed,
    'Disposed runtime must reject snapshot.',
  );

  await harness.close();
}

Future<void> _expectFailure(
  Future<AVSyncGuardRuntimeActionResult<AVSyncGuardRuntimeProjection>> action,
  AVSyncGuardRuntimeFailureKind kind,
  String message,
) async {
  final AVSyncGuardRuntimeActionResult<AVSyncGuardRuntimeProjection> result =
      await action;
  _expect(!result.isSuccess, message);
  _expect(result.failure?.kind == kind, message);
}

void _expect(bool condition, String message) {
  if (!condition) throw StateError(message);
}

final class _RuntimeHarness {
  _RuntimeHarness({required this.store, required this.bus}) {
    runtime = AVSyncGuardBootstrap(
      guardStore: store,
      guardByScope: <String, DeterministicAVSyncGuard>{
        'adapter-1': DeterministicAVSyncGuard(
          policy: AVSyncPolicy(),
          guardStore: store,
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
    ).createRuntime();

    unsupportedRuntime = AVSyncGuardBootstrap(
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
  }

  final DeterministicAVSyncGuardStore store;
  final StreamCacheInvalidationBus bus;
  late final AVSyncGuardRuntime runtime;
  late final AVSyncGuardRuntime unsupportedRuntime;

  Future<void> close() => bus.close();
}

Future<_RuntimeHarness> _harness() async {
  final DeterministicAVSyncGuardStore store = DeterministicAVSyncGuardStore(
    seedHealth: <StoredAVSyncHealthRecord>[
      StoredAVSyncHealthRecord(
        scopeId: 'adapter-1',
        health: StoredAVSyncHealthKind.warning,
        lastDriftMillis: 84,
        sampleCount: 3,
        reason: 'warning drift',
        updatedAt: _now(),
      ),
    ],
    seedDecisions: <StoredAVSyncDegradationDecisionRecord>[
      StoredAVSyncDegradationDecisionRecord(
        id: 'decision-1',
        scopeId: 'adapter-1',
        health: StoredAVSyncHealthKind.degraded,
        action: AVSyncDegradationAction.reduceEnhancementIntensity.name,
        reason: 'red line',
        occurredAt: _now(),
      ),
    ],
  );

  return _RuntimeHarness(store: store, bus: StreamCacheInvalidationBus());
}

PlaybackCapabilityMatrix _supportedCapabilities() {
  return PlaybackCapabilityMatrix(
    capabilities: <PlaybackCapability, CapabilityStatus>{
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
