// Video enhancement contract tests define profile and budget semantics before
// runtime storage and adapter mapping are involved.
import 'package:elaina/elaina.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('enhancement store persists profiles active selection and state',
      () async {
    final DeterministicEnhancementProfileStore store =
        DeterministicEnhancementProfileStore();
    final DateTime observedAt = DateTime.utc(2026, 6, 6, 12);

    await store.storeProfile(_storedProfile(observedAt));
    await store.setActiveProfile(StoredActiveEnhancementProfileRecord(
      scopeId: 'adapter-1',
      profileId: 'anime-vivid',
      selectedAt: observedAt,
    ));
    await store.recordPipelineState(StoredEnhancementPipelineStateRecord(
      scopeId: 'adapter-1',
      profileId: 'anime-vivid',
      state: StoredEnhancementPipelineStateKind.applied,
      supported: true,
      updatedAt: observedAt,
    ));

    expect((await store.findProfileById('anime-vivid'))?.label, 'Anime Vivid');
    expect((await store.activeProfile('adapter-1'))?.profileId, 'anime-vivid');
    expect((await store.latestPipelineState('adapter-1'))?.state,
        StoredEnhancementPipelineStateKind.applied);
  });

  test('deterministic pipeline evaluates unsupported enhancement components',
      () async {
    final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
    final DeterministicVideoEnhancementPipeline pipeline =
        DeterministicVideoEnhancementPipeline(
      profileStore: DeterministicEnhancementProfileStore(),
      capabilities: PlaybackCapabilityMatrix(
        capabilities: <PlaybackCapability, CapabilityStatus>{
          PlaybackCapability.videoEnhancement:
              const CapabilityStatus.supported(),
          PlaybackCapability.hdrToneMapping:
              const CapabilityStatus.unsupported('HDR unavailable.'),
          PlaybackCapability.debandFiltering:
              const CapabilityStatus.unsupported('Deband unavailable.'),
          PlaybackCapability.anime4kPreset:
              const CapabilityStatus.unsupported('Anime4K unavailable.'),
        },
      ),
      cacheInvalidationBus: bus,
      clock: () => DateTime.utc(2026, 6, 6, 12),
    );
    final Future<CacheInvalidationEvent> event = bus.events.first;

    final EnhancementEvaluationOutcome outcome =
        await pipeline.evaluate(_profile());
    final CacheInvalidationEvent delivered = await event;

    expect(outcome.isSuccess, isTrue);
    expect(outcome.report?.supported, isFalse);
    expect(outcome.report?.unsupportedComponents, hasLength(3));
    expect(delivered, isA<EnhancementCapabilityReevaluated>());
    await bus.close();
  });

  test('deterministic pipeline applies disables and publishes invalidation',
      () async {
    final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
    final DeterministicEnhancementProfileStore store =
        DeterministicEnhancementProfileStore();
    final DeterministicVideoEnhancementPipeline pipeline =
        DeterministicVideoEnhancementPipeline(
      profileStore: store,
      capabilities: _supportedCapabilities(),
      cacheInvalidationBus: bus,
      scopeId: 'adapter-1',
      clock: () => DateTime.utc(2026, 6, 6, 12),
    );
    final Future<List<CacheInvalidationEvent>> appliedEvents =
        bus.events.take(3).toList();

    final EnhancementApplyOutcome applied = await pipeline.apply(_profile());
    final List<CacheInvalidationEvent> deliveredApplied = await appliedEvents;
    final Future<CacheInvalidationEvent> disabledEvent = bus.events.first;
    final EnhancementDisableOutcome disabled = await pipeline.disable();
    final CacheInvalidationEvent deliveredDisabled = await disabledEvent;

    expect(applied.isSuccess, isTrue);
    expect((await store.activeProfile('adapter-1'))?.profileId, 'anime-vivid');
    expect(deliveredApplied.whereType<EnhancementCapabilityReevaluated>(),
        isNotEmpty);
    expect(deliveredApplied.whereType<EnhancementProfileChanged>(), isNotEmpty);
    expect(deliveredApplied.whereType<EnhancementPipelineStateChanged>(),
        isNotEmpty);
    expect(disabled.isSuccess, isTrue);
    expect(deliveredDisabled, isA<EnhancementPipelineStateChanged>());
    await bus.close();
  });

  test('pipeline reports render budget pressure without AV sync policy',
      () async {
    final DeterministicVideoEnhancementPipeline pipeline =
        DeterministicVideoEnhancementPipeline(
      profileStore: DeterministicEnhancementProfileStore(),
      capabilities: _supportedCapabilities(),
      clock: () => DateTime.utc(2026, 6, 6, 12),
    );

    final EnhancementDegradationOutcome outcome =
        await pipeline.requestDegradation(EnhancementDegradationRequest(
      profile: _profile(),
      renderBudget: const RenderBudgetInput(
        frameBudget: Duration(milliseconds: 16),
        estimatedRenderCost: Duration(milliseconds: 24),
        droppedFrames: 1,
      ),
      candidateTargets: <VideoEnhancementProfile>[_lighterProfile()],
    ));

    expect(outcome.isSuccess, isTrue);
    expect(outcome.snapshot?.isOverBudget, isTrue);
    expect(outcome.snapshot?.degradationTarget?.id.value, 'anime-light');
  });
}

StoredEnhancementProfileRecord _storedProfile(DateTime observedAt) {
  return StoredEnhancementProfileRecord(
    id: 'anime-vivid',
    label: 'Anime Vivid',
    scalerIntent: VideoScalerIntent.animeOptimized.name,
    hdrHandlingIntent: HdrHandlingIntent.toneMapToSdr.name,
    debandIntent: DebandIntent.medium.name,
    anime4kPresetIntent: Anime4kPresetIntent.restore.name,
    isBuiltIn: true,
    createdAt: observedAt,
    updatedAt: observedAt,
  );
}

VideoEnhancementProfile _profile() {
  return const VideoEnhancementProfile(
    id: EnhancementProfileId('anime-vivid'),
    label: 'Anime Vivid',
    scaler: VideoScalerIntent.animeOptimized,
    hdrHandling: HdrHandlingIntent.toneMapToSdr,
    deband: DebandIntent.medium,
    anime4kPreset: Anime4kPresetIntent.restore,
  );
}

VideoEnhancementProfile _lighterProfile() {
  return const VideoEnhancementProfile(
    id: EnhancementProfileId('anime-light'),
    label: 'Anime Light',
    scaler: VideoScalerIntent.sharp,
    hdrHandling: HdrHandlingIntent.adapterDefault,
    deband: DebandIntent.light,
    anime4kPreset: Anime4kPresetIntent.off,
  );
}

PlaybackCapabilityMatrix _supportedCapabilities() {
  return PlaybackCapabilityMatrix(
    capabilities: <PlaybackCapability, CapabilityStatus>{
      PlaybackCapability.videoEnhancement: const CapabilityStatus.supported(),
      PlaybackCapability.hdrToneMapping: const CapabilityStatus.supported(),
      PlaybackCapability.debandFiltering: const CapabilityStatus.supported(),
      PlaybackCapability.anime4kPreset: const CapabilityStatus.supported(),
    },
  );
}
