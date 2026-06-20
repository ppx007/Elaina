import 'package:elaina/elaina.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Task 1.1 - runtime bootstrap and replay', () {
    test(
        'bootstraps supported evaluation apply replay latest state budget pressure and degradation target',
        () async {
      final _RuntimeHarness h = await _harness();

      final VideoEnhancementPipelineRuntimeActionResult<
              VideoEnhancementPipelineRuntimeProjection> initial =
          await h.runtime.snapshot('adapter-1');
      final VideoEnhancementPipelineRuntimeActionResult<
              VideoEnhancementPipelineRuntimeProjection> evaluated =
          await h.runtime.evaluate(
        scopeId: 'adapter-1',
        profile: _profile(),
      );
      final VideoEnhancementPipelineRuntimeActionResult<
              VideoEnhancementPipelineRuntimeProjection> applied =
          await h.runtime.apply(
        scopeId: 'adapter-1',
        profileId: 'anime-vivid',
      );
      final VideoEnhancementPipelineRuntimeActionResult<
              VideoEnhancementPipelineRuntimeProjection> degraded =
          await h.runtime.requestDegradation(
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

      expect(initial.isSuccess, isTrue, reason: initial.failure?.message);
      expect(initial.value?.activeProfileId, 'anime-vivid');
      expect(initial.value?.latestPipelineState?.state,
          EnhancementPipelineState.applied);
      expect(initial.value?.latestPipelineState?.supported, isTrue);
      expect(initial.value?.restart.activeProfileId, 'anime-vivid');
      expect(initial.value?.restart.latestPipelineState?.state,
          StoredEnhancementPipelineStateKind.applied);
      expect(initial.value?.restart.latestPipelineState?.budgetPressure, 1.5);
      expect(
          initial
              .value?.restart.latestPipelineState?.degradationTargetProfileId,
          'anime-light');

      expect(evaluated.isSuccess, isTrue, reason: evaluated.failure?.message);
      expect(evaluated.value?.latestCapabilityReport?.profile.id.value,
          'anime-vivid');
      expect(evaluated.value?.latestCapabilityReport?.supported, isTrue);

      expect(applied.isSuccess, isTrue, reason: applied.failure?.message);
      expect(applied.value?.activeProfileId, 'anime-vivid');
      expect(applied.value?.latestPipelineState?.state,
          EnhancementPipelineState.applied);

      expect(degraded.isSuccess, isTrue, reason: degraded.failure?.message);
      expect(degraded.value?.latestBudgetPressure?.isOverBudget, isTrue);
      expect(degraded.value?.latestBudgetPressure?.pressureRatio, 1.5);
      expect(degraded.value?.degradationTargetProfileId, 'anime-light');
      expect(degraded.value?.restart.degradationTargetProfileId, 'anime-light');

      await h.close();
    });
  });

  group(
      'Task 1.2 - typed unsupported missing rejected unavailable disposed outcomes',
      () {
    test('returns typed failures without mutating storage or native behavior',
        () async {
      final _RuntimeHarness h = await _harness();

      final VideoEnhancementPipelineRuntimeActionResult<
              VideoEnhancementPipelineRuntimeProjection> unsupported =
          await h.runtime.evaluate(
        scopeId: 'adapter-unsupported',
        profile: _profile(),
      );
      final VideoEnhancementPipelineRuntimeActionResult<
              VideoEnhancementPipelineRuntimeProjection> missingProfile =
          await h.runtime.apply(
        scopeId: 'adapter-1',
        profileId: 'missing-profile',
      );
      final VideoEnhancementPipelineRuntimeActionResult<
              VideoEnhancementPipelineRuntimeProjection> rejectedProfile =
          await h.runtime.apply(
        scopeId: 'adapter-unsupported',
        profileId: 'anime-vivid',
      );

      await h.runtime.dispose();

      final VideoEnhancementPipelineRuntimeActionResult<
              VideoEnhancementPipelineRuntimeProjection> disposed =
          await h.runtime.snapshot('adapter-1');
      final VideoEnhancementPipelineRuntime unavailable =
          VideoEnhancementPipelineRuntime.unavailable(
        reason: 'Runtime dependencies are unavailable.',
      );
      final VideoEnhancementPipelineRuntimeActionResult<
              VideoEnhancementPipelineRuntimeProjection> unavailableResult =
          await unavailable.snapshot('adapter-1');

      expect(unsupported.failure?.kind,
          VideoEnhancementPipelineRuntimeFailureKind.unsupportedCapabilities);
      expect(unsupported.value, isNull);

      expect(missingProfile.failure?.kind,
          VideoEnhancementPipelineRuntimeFailureKind.missingProfile);
      expect(
          (await h.store.activeProfile('adapter-1'))?.profileId, 'anime-vivid');

      expect(rejectedProfile.failure?.kind,
          VideoEnhancementPipelineRuntimeFailureKind.rejectedProfile);
      expect((await h.store.latestPipelineState('adapter-unsupported'))?.state,
          StoredEnhancementPipelineStateKind.rejected);

      expect(disposed.failure?.kind,
          VideoEnhancementPipelineRuntimeFailureKind.disposed);
      expect(unavailableResult.failure?.kind,
          VideoEnhancementPipelineRuntimeFailureKind.unavailable);

      await h.close();
    });
  });

  group('Task 1.3 - invalidations after storage-visible state', () {
    test(
        'publishes capability profile and pipeline invalidations after storage',
        () async {
      final _RuntimeHarness h = await _harness();

      final Future<bool?> capabilityVisible =
          _eventsOfType<EnhancementCapabilityReevaluated>(h.bus.events)
              .first
              .then((EnhancementCapabilityReevaluated _) async =>
                  (await h.store.latestPipelineState('adapter-1'))?.supported);
      final Future<String?> activeProfileVisible =
          _eventsOfType<EnhancementProfileChanged>(h.bus.events).first.then(
              (EnhancementProfileChanged _) async =>
                  (await h.store.activeProfile('adapter-1'))?.profileId);
      final Future<StoredEnhancementPipelineStateKind?> pipelineVisible =
          _eventsOfType<EnhancementPipelineStateChanged>(h.bus.events)
              .first
              .then((EnhancementPipelineStateChanged _) async =>
                  (await h.store.latestPipelineState('adapter-1'))?.state);

      await h.runtime.evaluate(
        scopeId: 'adapter-1',
        profile: _profile(),
      );
      await h.runtime.apply(
        scopeId: 'adapter-1',
        profileId: 'anime-vivid',
      );

      expect(await capabilityVisible, isTrue);
      expect(await activeProfileVisible, 'anime-vivid');
      expect(await pipelineVisible, StoredEnhancementPipelineStateKind.applied);

      await h.close();
    });
  });
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
      _storedProfile('anime-light', 'Anime Light',
          scaler: VideoScalerIntent.sharp,
          hdrHandling: HdrHandlingIntent.adapterDefault,
          deband: DebandIntent.light,
          anime4kPreset: Anime4kPresetIntent.off),
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
