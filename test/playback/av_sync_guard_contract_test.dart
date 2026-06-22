// AV-sync guard contract tests define drift thresholds and degradation outcomes
// before runtime persistence records measurements.
import 'package:elaina/elaina.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AV sync guard store persists policy health samples and decisions',
      () async {
    final DeterministicAVSyncGuardStore store = DeterministicAVSyncGuardStore();
    final DateTime observedAt = DateTime.utc(2026, 6, 6, 12);

    await store.storePolicy(_storedPolicy(observedAt));
    await store.recordHealth(StoredAVSyncHealthRecord(
      scopeId: 'adapter-1',
      health: StoredAVSyncHealthKind.warning,
      lastDriftMillis: 84,
      sampleCount: 3,
      reason: 'warning drift',
      updatedAt: observedAt,
    ));
    await store.recordSampleMetadata(StoredAVSyncSampleHistoryMetadataRecord(
      scopeId: 'adapter-1',
      sequence: 1,
      audioPositionMillis: 1000,
      videoPositionMillis: 900,
      driftMillis: 100,
      renderDelayMillis: 8,
      droppedFrames: 0,
      recordedAt: observedAt,
    ));
    await store.recordDegradationDecision(StoredAVSyncDegradationDecisionRecord(
      id: 'decision-1',
      scopeId: 'adapter-1',
      health: StoredAVSyncHealthKind.degraded,
      action: AVSyncDegradationAction.reduceEnhancementIntensity.name,
      reason: 'red line',
      occurredAt: observedAt,
    ));

    expect((await store.activePolicy('default'))?.sampleWindowSize, 3);
    expect((await store.latestHealth('adapter-1'))?.health,
        StoredAVSyncHealthKind.warning);
    expect((await store.sampleHistory('adapter-1')).single.driftMillis, 100);
    expect((await store.degradationHistory('adapter-1')).single.action,
        AVSyncDegradationAction.reduceEnhancementIntensity.name);
  });

  test('deterministic guard evaluates sustained drift and publishes events',
      () async {
    final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
    final DeterministicAVSyncGuardStore store = DeterministicAVSyncGuardStore();
    final DeterministicAVSyncGuard guard = _guard(
      store: store,
      bus: bus,
    );
    final Future<List<CacheInvalidationEvent>> events =
        bus.events.take(4).toList();

    final AVSyncEvaluationOutcome first =
        await guard.ingestSample(_sample(130));
    final AVSyncEvaluationOutcome second =
        await guard.ingestSample(_sample(130));
    final AVSyncEvaluationOutcome third =
        await guard.ingestSample(_sample(140));
    final List<CacheInvalidationEvent> delivered = await events;

    expect(first.isSuccess, isTrue);
    expect(second.isSuccess, isTrue);
    expect(third.decision?.health, AVSyncHealth.degraded);
    expect(third.decision?.action,
        AVSyncDegradationAction.reduceEnhancementIntensity);
    expect((await store.latestHealth('adapter-1'))?.health,
        StoredAVSyncHealthKind.degraded);
    expect(delivered.whereType<AVSyncSampleIngested>(), hasLength(3));
    expect(delivered.whereType<AVSyncHealthTransitioned>(), isNotEmpty);
    await guard.close();
    await bus.close();
  });

  test('deterministic guard recovers when sustained drift drops', () async {
    final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
    final DeterministicAVSyncGuard guard = _guard(bus: bus);

    await guard.ingestSample(_sample(140));
    await guard.ingestSample(_sample(140));
    await guard.ingestSample(_sample(140));
    await guard.ingestSample(_sample(20));
    await guard.ingestSample(_sample(20));
    await guard.ingestSample(_sample(20));
    final Future<CacheInvalidationEvent> event = bus.events.first;
    final AVSyncRecoveryOutcome recovery = await guard.checkRecovery();
    final CacheInvalidationEvent delivered = await event;

    expect(recovery.isSuccess, isTrue);
    expect(recovery.decision?.health, AVSyncHealth.target);
    expect(delivered, isA<AVSyncRecoveryStateChanged>());
    await guard.close();
    await bus.close();
  });

  test('deterministic guard rejects unsupported capability', () async {
    final DeterministicAVSyncGuard guard = _guard(
      capabilities: PlaybackCapabilityMatrix(
        capabilities: <PlaybackCapability, CapabilityStatus>{
          PlaybackCapability.avSyncGuard:
              const CapabilityStatus.unsupported('No normalized samples.'),
        },
      ),
    );

    final AVSyncEvaluationOutcome outcome =
        await guard.ingestSample(_sample(0));
    final AVSyncDegradationRequestOutcome degradation =
        await guard.requestDegradation(_sample(140));

    expect(outcome.isSuccess, isFalse);
    expect(outcome.failure?.kind, AVSyncGuardFailureKind.capabilityUnsupported);
    expect(degradation.isSuccess, isFalse);
    await guard.close();
  });

  test('degradation ordering uses enhancement pressure as input data',
      () async {
    final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
    final DeterministicAVSyncGuardStore store = DeterministicAVSyncGuardStore();
    final DeterministicAVSyncGuard guard = _guard(
      store: store,
      bus: bus,
      policy: AVSyncPolicy(
        degradationOrder: const <AVSyncDegradationAction>[
          AVSyncDegradationAction.disableAdvancedCaptions,
          AVSyncDegradationAction.disableEnhancementProfile,
        ],
      ),
    );
    final Future<CacheInvalidationEvent> event = bus.events.first;

    final AVSyncDegradationRequestOutcome outcome = await guard
        .requestDegradation(_sample(140, enhancementOverBudget: true));
    final CacheInvalidationEvent delivered = await event;

    expect(outcome.isSuccess, isTrue);
    expect(outcome.decision?.action,
        AVSyncDegradationAction.disableEnhancementProfile);
    expect((await store.degradationHistory('adapter-1')).single.action,
        AVSyncDegradationAction.disableEnhancementProfile.name);
    expect(delivered, isA<AVSyncDegradationDecisionRecorded>());
    await guard.close();
    await bus.close();
  });
}

StoredAVSyncPolicyRecord _storedPolicy(DateTime observedAt) {
  return StoredAVSyncPolicyRecord(
    id: 'default',
    targetDriftMillis: 40,
    warningDriftMillis: 80,
    degradationDriftMillis: 120,
    recoveryDriftMillis: 60,
    sampleWindowSize: 3,
    degradationOrder: <String>[
      AVSyncDegradationAction.reduceEnhancementIntensity.name,
      AVSyncDegradationAction.disableAdvancedCaptions.name,
      AVSyncDegradationAction.disableEnhancementProfile.name,
    ],
    updatedAt: observedAt,
  );
}

DeterministicAVSyncGuard _guard({
  DeterministicAVSyncGuardStore? store,
  StreamCacheInvalidationBus? bus,
  PlaybackCapabilityMatrix? capabilities,
  AVSyncPolicy? policy,
}) {
  return DeterministicAVSyncGuard(
    policy: policy ?? AVSyncPolicy(),
    guardStore: store ?? DeterministicAVSyncGuardStore(),
    capabilities: capabilities ?? _supportedCapabilities(),
    cacheInvalidationBus: bus,
    scopeId: 'adapter-1',
    clock: () => DateTime.utc(2026, 6, 6, 12),
  );
}

PlaybackCapabilityMatrix _supportedCapabilities() {
  return PlaybackCapabilityMatrix(
    capabilities: <PlaybackCapability, CapabilityStatus>{
      PlaybackCapability.avSyncGuard: const CapabilityStatus.supported(),
    },
  );
}

AVSyncSample _sample(int driftMillis, {bool enhancementOverBudget = false}) {
  return AVSyncSample(
    audioPosition: Duration(milliseconds: 1000 + driftMillis),
    videoPosition: const Duration(milliseconds: 1000),
    renderDelay: const Duration(milliseconds: 8),
    droppedFrames: enhancementOverBudget ? 1 : 0,
    enhancementPressure: enhancementOverBudget
        ? const RenderBudgetInput(
            frameBudget: Duration(milliseconds: 16),
            estimatedRenderCost: Duration(milliseconds: 24),
            droppedFrames: 1,
          )
        : null,
  );
}
