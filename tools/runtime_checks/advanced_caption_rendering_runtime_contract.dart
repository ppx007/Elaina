import '../../lib/elaina.dart';

Future<void> main() async {
  await verifyAdvancedCaptionRenderingRuntimeContract();
}

Future<void> verifyAdvancedCaptionRenderingRuntimeContract() async {
  final _RuntimeHarness harness = await _harness();

  // Initial snapshot from seeded store.
  final AdvancedCaptionRuntimeActionResult<AdvancedCaptionRuntimeProjection>
      initial = await harness.runtime.snapshot('adapter-1');
  _expect(initial.isSuccess, 'Initial runtime snapshot must pass.');
  _expect(initial.value?.activeProfileId == 'ac-vivid',
      'Runtime snapshot must replay stored active profile.');
  _expect(
      initial.value?.latestRendererState ==
          StoredAdvancedCaptionRendererStateKind.applied,
      'Runtime snapshot must replay stored applied renderer state.');
  _expect(initial.value?.restart.activeProfileId == 'ac-vivid',
      'Runtime restart projection must replay stored active profile.');
  _expect(
      initial.value?.restart.latestRendererState ==
          StoredAdvancedCaptionRendererStateKind.applied,
      'Runtime restart projection must replay stored renderer state.');

  // Evaluate returns typed success with evaluation report.
  final AdvancedCaptionRuntimeActionResult<CaptionEvaluationOutcome> evaluated =
      await harness.runtime.evaluate('adapter-1', _profile());
  _expect(evaluated.isSuccess, 'Evaluate must return typed success.');
  _expect(evaluated.value?.report != null,
      'Evaluate must produce a caption evaluation report.');

  // RenderMatrixDanmaku returns typed success.
  final AdvancedCaptionRuntimeActionResult<CaptionRenderOutcome> matrixResult =
      await harness.runtime
          .renderMatrixDanmaku('adapter-1', _matrixDanmakuRequest());
  _expect(
      matrixResult.isSuccess, 'RenderMatrixDanmaku must return typed success.');

  // RenderDualSubtitles returns typed success.
  final AdvancedCaptionRuntimeActionResult<CaptionRenderOutcome> dualResult =
      await harness.runtime
          .renderDualSubtitles('adapter-1', _dualSubtitleRequest());
  _expect(
      dualResult.isSuccess, 'RenderDualSubtitles must return typed success.');

  // Disable returns typed success.
  final AdvancedCaptionRuntimeActionResult<CaptionDisableOutcome> disabled =
      await harness.runtime.disable('adapter-1');
  _expect(disabled.isSuccess, 'Disable must return typed success.');

  // Accept degradation returns typed success with degraded outcome.
  final AdvancedCaptionRuntimeActionResult<CaptionDegradationOutcome> degraded =
      await harness.runtime.acceptDegradation(
    'adapter-1',
    AVSyncDegradationAction.disableAdvancedCaptions,
    reason: 'AV sync drift exceeded threshold.',
  );
  _expect(degraded.isSuccess, 'Accept degradation must return typed success.');

  // Unsupported capability returns typed failure.
  final AdvancedCaptionRuntimeActionResult<AdvancedCaptionRuntimeProjection>
      unsupported =
      await harness.unsupportedRuntime.snapshot('adapter-unsupported');
  _expect(
      unsupported.failure?.kind ==
          AdvancedCaptionRuntimeFailureKind.capabilityUnsupported,
      'Unsupported scope must return capabilityUnsupported failure.');

  // Unavailable runtime rejects all operations.
  final AdvancedCaptionRuntime unavailable = AdvancedCaptionRuntime.unavailable(
      reason: 'No caption runtime available.');
  final AdvancedCaptionRuntimeActionResult<AdvancedCaptionRuntimeProjection>
      unavailSnapshot = await unavailable.snapshot('any');
  _expect(
      !unavailSnapshot.isSuccess, 'Unavailable runtime must reject snapshot.');
  _expect(
      unavailSnapshot.failure?.kind ==
          AdvancedCaptionRuntimeFailureKind.unavailable,
      'Unavailable runtime snapshot must return unavailable failure.');

  final AdvancedCaptionRuntimeActionResult<CaptionEvaluationOutcome>
      unavailEval = await unavailable.evaluate('any', _profile());
  _expect(!unavailEval.isSuccess, 'Unavailable runtime must reject evaluate.');
  _expect(
      unavailEval.failure?.kind ==
          AdvancedCaptionRuntimeFailureKind.unavailable,
      'Unavailable runtime evaluate must return unavailable failure.');

  final AdvancedCaptionRuntimeActionResult<CaptionRenderOutcome> unavailMatrix =
      await unavailable.renderMatrixDanmaku('any', _matrixDanmakuRequest());
  _expect(!unavailMatrix.isSuccess,
      'Unavailable runtime must reject renderMatrixDanmaku.');

  final AdvancedCaptionRuntimeActionResult<CaptionDisableOutcome>
      unavailDisable = await unavailable.disable('any');
  _expect(
      !unavailDisable.isSuccess, 'Unavailable runtime must reject disable.');

  final AdvancedCaptionRuntimeActionResult<CaptionDegradationOutcome>
      unavailDegradation = await unavailable.acceptDegradation(
    'any',
    AVSyncDegradationAction.disableAdvancedCaptions,
    reason: 'test',
  );
  _expect(!unavailDegradation.isSuccess,
      'Unavailable runtime must reject acceptDegradation.');

  // Disposed runtime rejects snapshot.
  await harness.runtime.dispose();
  final AdvancedCaptionRuntimeActionResult<AdvancedCaptionRuntimeProjection>
      disposedSnapshot = await harness.runtime.snapshot('adapter-1');
  _expect(
      !disposedSnapshot.isSuccess, 'Disposed runtime must reject snapshot.');
  _expect(
      disposedSnapshot.failure?.kind ==
          AdvancedCaptionRuntimeFailureKind.disposed,
      'Disposed runtime snapshot must return disposed failure.');

  // Restart projection replays stored dual subtitle and degradation.
  final _RuntimeHarness restartHarness = await _restartHarness();
  final AdvancedCaptionRuntimeActionResult<AdvancedCaptionRuntimeProjection>
      restartSnapshot = await restartHarness.runtime.snapshot('adapter-1');
  _expect(restartSnapshot.isSuccess, 'Restart snapshot must pass.');
  _expect(restartSnapshot.value?.restart.dualSubtitlePrimaryId == 'sub-en',
      'Restart projection must replay stored dual subtitle primary.');
  _expect(restartSnapshot.value?.restart.dualSubtitleSecondaryId == 'sub-jp',
      'Restart projection must replay stored dual subtitle secondary.');

  await restartHarness.close();
  await harness.close();
}

void _expect(bool condition, String message) {
  if (!condition) throw StateError(message);
}

final class _RuntimeHarness {
  _RuntimeHarness({required this.store, required this.bus}) {
    runtime = AdvancedCaptionRuntimeBootstrap(
      captionStore: store,
      rendererByScope: <String, DeterministicAdvancedCaptionRenderer>{
        'adapter-1': DeterministicAdvancedCaptionRenderer(
          captionStore: store,
          capabilityMatrix: _supportedCapabilities(),
          profile: _profile(),
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

    unsupportedRuntime = AdvancedCaptionRuntimeBootstrap(
      captionStore: DeterministicAdvancedCaptionStore(),
      rendererByScope: <String, DeterministicAdvancedCaptionRenderer>{
        'adapter-unsupported': DeterministicAdvancedCaptionRenderer(
          captionStore: DeterministicAdvancedCaptionStore(),
          capabilityMatrix: _unsupportedCapabilities(),
          profile: _profile(),
          cacheInvalidationBus: bus,
          scopeId: 'adapter-unsupported',
          clock: _now,
        ),
      },
      capabilitiesByScope: <String, PlaybackCapabilityMatrix>{
        'adapter-unsupported': _unsupportedCapabilities(),
      },
      cacheInvalidationBus: bus,
    ).createRuntime();
  }

  final DeterministicAdvancedCaptionStore store;
  final StreamCacheInvalidationBus bus;
  late final AdvancedCaptionRuntime runtime;
  late final AdvancedCaptionRuntime unsupportedRuntime;

  Future<void> close() => bus.close();
}

Future<_RuntimeHarness> _harness() async {
  final DeterministicAdvancedCaptionStore store =
      DeterministicAdvancedCaptionStore(
    seedProfiles: <StoredAdvancedCaptionProfileRecord>[
      _storedProfile('ac-vivid'),
    ],
    seedActiveProfiles: <StoredActiveAdvancedCaptionProfileRecord>[
      StoredActiveAdvancedCaptionProfileRecord(
        scopeId: 'adapter-1',
        profileId: 'ac-vivid',
        selectedAt: _now(),
      ),
    ],
    seedRendererStates: <StoredAdvancedCaptionRendererStateRecord>[
      StoredAdvancedCaptionRendererStateRecord(
        scopeId: 'adapter-1',
        state: StoredAdvancedCaptionRendererStateKind.applied,
        supported: true,
        updatedAt: _now(),
        profileId: 'ac-vivid',
      ),
    ],
  );
  return _RuntimeHarness(store: store, bus: StreamCacheInvalidationBus());
}

Future<_RuntimeHarness> _restartHarness() async {
  final DeterministicAdvancedCaptionStore store =
      DeterministicAdvancedCaptionStore(
    seedProfiles: <StoredAdvancedCaptionProfileRecord>[
      _storedProfile('ac-vivid'),
    ],
    seedActiveProfiles: <StoredActiveAdvancedCaptionProfileRecord>[
      StoredActiveAdvancedCaptionProfileRecord(
        scopeId: 'adapter-1',
        profileId: 'ac-vivid',
        selectedAt: _now(),
      ),
    ],
    seedRendererStates: <StoredAdvancedCaptionRendererStateRecord>[
      StoredAdvancedCaptionRendererStateRecord(
        scopeId: 'adapter-1',
        state: StoredAdvancedCaptionRendererStateKind.applied,
        supported: true,
        updatedAt: _now(),
        profileId: 'ac-vivid',
        degradationReason: 'AV sync drift exceeded.',
      ),
    ],
    seedDualSubtitleSelections: <StoredAdvancedCaptionDualSubtitleSelectionRecord>[
      StoredAdvancedCaptionDualSubtitleSelectionRecord(
        scopeId: 'adapter-1',
        profileId: 'ac-vivid',
        primarySubtitleId: 'sub-en',
        secondarySubtitleId: 'sub-jp',
        selectedAt: _now(),
      ),
    ],
  );
  return _RuntimeHarness(store: store, bus: StreamCacheInvalidationBus());
}

AdvancedCaptionProfile _profile() {
  return const AdvancedCaptionProfile(
    id: AdvancedCaptionProfileId('ac-vivid'),
    label: 'AC Vivid',
    matrixDanmakuEnabled: true,
    dualSubtitlesEnabled: true,
    pgsRenderingEnabled: true,
    assEnhancementEnabled: true,
  );
}

StoredAdvancedCaptionProfileRecord _storedProfile(String id) {
  return StoredAdvancedCaptionProfileRecord(
    id: id,
    label: 'AC Vivid',
    matrixDanmakuEnabled: true,
    dualSubtitlesEnabled: true,
    pgsRenderingEnabled: true,
    assEnhancementEnabled: true,
    createdAt: _now(),
    updatedAt: _now(),
  );
}

MatrixDanmakuRequest _matrixDanmakuRequest() {
  return MatrixDanmakuRequest(
    comments: <DanmakuComment>[],
    transform: CaptionTransform4(values: <double>[
      1, 0, 0, 0, //
      0, 1, 0, 0, //
      0, 0, 1, 0, //
      0, 0, 0, 1, //
    ]),
  );
}

DualSubtitleRequest _dualSubtitleRequest() {
  return DualSubtitleRequest(
    primary: EmbeddedSubtitleSource(
      id: 'sub-en',
      format: SubtitleFormat.srt,
      languageCode: 'en',
      trackId: 'track-sub-en',
    ),
    secondary: EmbeddedSubtitleSource(
      id: 'sub-jp',
      format: SubtitleFormat.srt,
      languageCode: 'ja',
      trackId: 'track-sub-jp',
    ),
  );
}

PlaybackCapabilityMatrix _supportedCapabilities() {
  return PlaybackCapabilityMatrix(
    capabilities: <PlaybackCapability, CapabilityStatus>{
      PlaybackCapability.matrixDanmaku: const CapabilityStatus.supported(),
      PlaybackCapability.dualSubtitles: const CapabilityStatus.supported(),
      PlaybackCapability.pgsSubtitleRendering:
          const CapabilityStatus.supported(),
      PlaybackCapability.assSubtitleEnhancement:
          const CapabilityStatus.supported(),
    },
  );
}

PlaybackCapabilityMatrix _unsupportedCapabilities() {
  return PlaybackCapabilityMatrix(
    capabilities: <PlaybackCapability, CapabilityStatus>{
      PlaybackCapability.matrixDanmaku:
          const CapabilityStatus.unsupported('No caption support.'),
      PlaybackCapability.dualSubtitles:
          const CapabilityStatus.unsupported('No caption support.'),
      PlaybackCapability.pgsSubtitleRendering:
          const CapabilityStatus.unsupported('No caption support.'),
      PlaybackCapability.assSubtitleEnhancement:
          const CapabilityStatus.unsupported('No caption support.'),
    },
  );
}

DateTime _now() => DateTime.utc(2026, 6, 15, 12);
