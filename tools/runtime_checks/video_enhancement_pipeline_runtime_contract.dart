import '../../lib/elaina.dart';

Future<void> main() async {
  await verifyVideoEnhancementPipelineRuntimeContract();
}

Future<void> verifyVideoEnhancementPipelineRuntimeContract() async {
  final _RuntimeHarness harness = await _harness();

  final VideoEnhancementPipelineRuntimeActionResult<
          VideoEnhancementPipelineRuntimeProjection> initial =
      await harness.runtime.snapshot('adapter-1');
  _expect(initial.isSuccess, 'Initial runtime snapshot must pass.');
  _expect(initial.value?.activeProfileId == 'anime-vivid',
      'Runtime snapshot must replay the active profile.');
  _expect(
      initial.value?.latestPipelineState?.state ==
          EnhancementPipelineState.applied,
      'Runtime snapshot must replay the latest pipeline state.');
  _expect(initial.value?.latestPipelineState?.budgetPressure == 1.5,
      'Runtime snapshot must replay budget pressure.');
  _expect(initial.value?.restart.degradationTargetProfileId == 'anime-light',
      'Runtime restart projection must replay degradation target.');

  final Future<bool?> capabilityVisible =
      _eventsOfType<EnhancementCapabilityReevaluated>(harness.bus.events)
          .first
          .then((EnhancementCapabilityReevaluated _) async =>
              (await harness.store.latestPipelineState('adapter-1'))
                  ?.supported);
  final Future<String?> activeProfileVisible =
      _eventsOfType<EnhancementProfileChanged>(harness.bus.events).first.then(
          (EnhancementProfileChanged _) async =>
              (await harness.store.activeProfile('adapter-1'))?.profileId);
  final Future<StoredEnhancementPipelineStateKind?> pipelineVisible =
      _eventsOfType<EnhancementPipelineStateChanged>(harness.bus.events)
          .first
          .then((EnhancementPipelineStateChanged _) async =>
              (await harness.store.latestPipelineState('adapter-1'))?.state);

  final VideoEnhancementPipelineRuntimeActionResult<
          VideoEnhancementPipelineRuntimeProjection> evaluated =
      await harness.runtime.evaluate(
    scopeId: 'adapter-1',
    profile: _profile(),
  );
  _expect(evaluated.isSuccess, 'Supported runtime evaluation must pass.');
  _expect(evaluated.value?.latestCapabilityReport?.supported == true,
      'Supported runtime evaluation must expose capability report.');
  _expect(await capabilityVisible == true,
      'Capability invalidation must arrive after storage-visible state.');

  final VideoEnhancementPipelineRuntimeActionResult<
          VideoEnhancementPipelineRuntimeProjection> applied =
      await harness.runtime.apply(
    scopeId: 'adapter-1',
    profileId: 'anime-vivid',
  );
  _expect(applied.isSuccess, 'Supported runtime apply must pass.');
  _expect(applied.value?.activeProfileId == 'anime-vivid',
      'Supported runtime apply must project the active profile.');
  _expect(await activeProfileVisible == 'anime-vivid',
      'Profile invalidation must arrive after storage-visible state.');
  _expect(await pipelineVisible == StoredEnhancementPipelineStateKind.applied,
      'Pipeline invalidation must arrive after storage-visible state.');

  final VideoEnhancementPipelineRuntimeActionResult<
          VideoEnhancementPipelineRuntimeProjection> unsupported =
      await harness.runtime.evaluate(
    scopeId: 'adapter-unsupported',
    profile: _profile(),
  );
  _expect(
      unsupported.failure?.kind ==
          VideoEnhancementPipelineRuntimeFailureKind.unsupportedCapabilities,
      'Unsupported runtime evaluation must return a typed failure.');

  final VideoEnhancementPipelineRuntimeActionResult<
          VideoEnhancementPipelineRuntimeProjection> degraded =
      await harness.runtime.requestDegradation(
    scopeId: 'adapter-1',
    request: EnhancementRuntimeDegradationRequest(
      profileId: 'anime-vivid',
      renderBudget: const RenderBudgetInput(
        frameBudget: Duration(milliseconds: 16),
        estimatedRenderCost: Duration(milliseconds: 24),
        droppedFrames: 1,
      ),
      candidateTargetProfileIds: const <String>['anime-light'],
    ),
  );
  _expect(degraded.isSuccess, 'Runtime degradation request must pass.');
  _expect(degraded.value?.latestBudgetPressure?.pressureRatio == 1.5,
      'Runtime degradation request must project budget pressure.');
  _expect(degraded.value?.degradationTargetProfileId == 'anime-light',
      'Runtime degradation request must project degradation target.');

  final VideoEnhancementPipelineRuntime restarted =
      VideoEnhancementPipelineBootstrap(
    profileStore: harness.store,
    runtimeByScope: <String, VideoEnhancementPipeline>{
      'adapter-1': DeterministicVideoEnhancementPipeline(
        profileStore: harness.store,
        capabilities: _supportedCapabilities(),
        cacheInvalidationBus: harness.bus,
        scopeId: 'adapter-1',
        clock: _now,
      ),
    },
    capabilitiesByScope: <String, PlaybackCapabilityMatrix>{
      'adapter-1': _supportedCapabilities(),
    },
    cacheInvalidationBus: harness.bus,
    clock: _now,
  ).createRuntime();
  final VideoEnhancementPipelineRuntimeActionResult<
          VideoEnhancementPipelineRuntimeProjection> restartSnapshot =
      await restarted.snapshot('adapter-1');
  _expect(restartSnapshot.isSuccess, 'Restart snapshot must pass.');
  _expect(restartSnapshot.value?.restart.activeProfileId == 'anime-vivid',
      'Restart projection must replay the active profile.');
  _expect(
      restartSnapshot.value?.restart.degradationTargetProfileId ==
          'anime-light',
      'Restart projection must replay degradation target.');

  final VideoEnhancementPipelineRuntime unavailable =
      VideoEnhancementPipelineRuntime.unavailable(
    reason: 'Runtime dependencies are unavailable.',
  );
  await _expectFailure(
    unavailable.snapshot('adapter-1'),
    VideoEnhancementPipelineRuntimeFailureKind.unavailable,
    'Unavailable runtime must return a typed outcome.',
  );

  await harness.runtime.dispose();
  await _expectFailure(
    harness.runtime.snapshot('adapter-1'),
    VideoEnhancementPipelineRuntimeFailureKind.disposed,
    'Disposed runtime must reject snapshot lookup.',
  );

  await harness.close();
}

Future<void> _expectFailure(
  Future<
          VideoEnhancementPipelineRuntimeActionResult<
              VideoEnhancementPipelineRuntimeProjection>>
      action,
  VideoEnhancementPipelineRuntimeFailureKind kind,
  String message,
) async {
  final VideoEnhancementPipelineRuntimeActionResult<
      VideoEnhancementPipelineRuntimeProjection> result = await action;
  _expect(!result.isSuccess, message);
  _expect(result.failure?.kind == kind, message);
}

void _expect(bool condition, String message) {
  if (!condition) throw StateError(message);
}

final class _RuntimeHarness {
  _RuntimeHarness({required this.store, required this.bus}) {
    runtime = VideoEnhancementPipelineBootstrap(
      profileStore: store,
      runtimeByScope: <String, VideoEnhancementPipeline>{
        'adapter-1': DeterministicVideoEnhancementPipeline(
          profileStore: store,
          capabilities: _supportedCapabilities(),
          cacheInvalidationBus: bus,
          scopeId: 'adapter-1',
          clock: _now,
        ),
        'adapter-unsupported': DeterministicVideoEnhancementPipeline(
          profileStore: store,
          capabilities: PlaybackCapabilityMatrix.unsupported(
            reason: 'Enhancement runtime unavailable for this adapter.',
          ),
          cacheInvalidationBus: bus,
          scopeId: 'adapter-unsupported',
          clock: _now,
        ),
      },
      capabilitiesByScope: <String, PlaybackCapabilityMatrix>{
        'adapter-1': _supportedCapabilities(),
        'adapter-unsupported': PlaybackCapabilityMatrix.unsupported(
          reason: 'Enhancement runtime unavailable for this adapter.',
        ),
      },
      cacheInvalidationBus: bus,
      clock: _now,
    ).createRuntime();
  }

  final DeterministicEnhancementProfileStore store;
  final StreamCacheInvalidationBus bus;
  late final VideoEnhancementPipelineRuntime runtime;

  Future<void> close() => bus.close();
}

Future<_RuntimeHarness> _harness() async {
  final DeterministicEnhancementProfileStore store =
      DeterministicEnhancementProfileStore(
    seedProfiles: <StoredEnhancementProfileRecord>[
      _storedProfile('anime-vivid', 'Anime Vivid'),
      _storedProfile(
        'anime-light',
        'Anime Light',
        scaler: VideoScalerIntent.sharp,
        hdrHandling: HdrHandlingIntent.adapterDefault,
        deband: DebandIntent.light,
        anime4kPreset: Anime4kPresetIntent.off,
      ),
    ],
    seedActiveProfiles: <StoredActiveEnhancementProfileRecord>[
      StoredActiveEnhancementProfileRecord(
        scopeId: 'adapter-1',
        profileId: 'anime-vivid',
        selectedAt: _now(),
      ),
    ],
    seedPipelineStates: <StoredEnhancementPipelineStateRecord>[
      StoredEnhancementPipelineStateRecord(
        scopeId: 'adapter-1',
        profileId: 'anime-vivid',
        state: StoredEnhancementPipelineStateKind.applied,
        supported: true,
        budgetPressure: 1.5,
        degradationTargetProfileId: 'anime-light',
        updatedAt: _now(),
      ),
    ],
  );

  return _RuntimeHarness(store: store, bus: StreamCacheInvalidationBus());
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

StoredEnhancementProfileRecord _storedProfile(
  String id,
  String label, {
  VideoScalerIntent scaler = VideoScalerIntent.animeOptimized,
  HdrHandlingIntent hdrHandling = HdrHandlingIntent.toneMapToSdr,
  DebandIntent deband = DebandIntent.medium,
  Anime4kPresetIntent anime4kPreset = Anime4kPresetIntent.restore,
}) {
  return StoredEnhancementProfileRecord(
    id: id,
    label: label,
    scalerIntent: scaler.name,
    hdrHandlingIntent: hdrHandling.name,
    debandIntent: deband.name,
    anime4kPresetIntent: anime4kPreset.name,
    isBuiltIn: true,
    createdAt: _now(),
    updatedAt: _now(),
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

DateTime _now() => DateTime.utc(2026, 6, 14, 12);

Stream<T> _eventsOfType<T extends CacheInvalidationEvent>(
    Stream<CacheInvalidationEvent> source) {
  return source.where((CacheInvalidationEvent event) => event is T).cast<T>();
}
