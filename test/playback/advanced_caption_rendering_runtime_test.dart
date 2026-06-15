import 'package:celesteria/celesteria.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AdvancedCaptionRuntime initial', () {
    test('snapshot for supported scope returns projection with seeded state',
        () async {
      final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
      final DeterministicAdvancedCaptionStore store =
          DeterministicAdvancedCaptionStore(
        seedProfiles: <StoredAdvancedCaptionProfileRecord>[
          _storedProfile('ac-vivid'),
        ],
        seedActiveProfiles: <StoredActiveAdvancedCaptionProfileRecord>[
          StoredActiveAdvancedCaptionProfileRecord(
            scopeId: 'adapter-1',
            profileId: 'ac-vivid',
            selectedAt: DateTime.utc(2026, 6, 15, 12),
          ),
        ],
        seedRendererStates: <StoredAdvancedCaptionRendererStateRecord>[
          StoredAdvancedCaptionRendererStateRecord(
            scopeId: 'adapter-1',
            state: StoredAdvancedCaptionRendererStateKind.applied,
            supported: true,
            updatedAt: DateTime.utc(2026, 6, 15, 12),
            profileId: 'ac-vivid',
          ),
        ],
      );
      final AdvancedCaptionRuntime runtime = _bootstrap(
        store: store,
        bus: bus,
      ).createRuntime();

      final AdvancedCaptionRuntimeActionResult<AdvancedCaptionRuntimeProjection>
          result = await runtime.snapshot('adapter-1');

      expect(result.isSuccess, isTrue);
      expect(result.value!.activeProfileId, 'ac-vivid');
      expect(result.value!.latestRendererState,
          StoredAdvancedCaptionRendererStateKind.applied);
      // Restart projection replays stored state
      expect(
          result.value!.restart.activeProfileId, 'ac-vivid');
      expect(result.value!.restart.latestRendererState,
          StoredAdvancedCaptionRendererStateKind.applied);
      await runtime.dispose();
      await bus.close();
    });
  });

  group('AdvancedCaptionRuntime evaluate', () {
    test('returns typed success with evaluation report', () async {
      final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
      final AdvancedCaptionRuntime runtime = _bootstrap(
        bus: bus,
      ).createRuntime();

      final AdvancedCaptionRuntimeActionResult<CaptionEvaluationOutcome>
          result = await runtime.evaluate('adapter-1', _profile());

      expect(result.isSuccess, isTrue);
      expect(result.value!.report, isNotNull);
      await runtime.dispose();
      await bus.close();
    });
  });

  group('AdvancedCaptionRuntime renderMatrixDanmaku', () {
    test('returns typed success with rendered outcome', () async {
      final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
      final AdvancedCaptionRuntime runtime = _bootstrap(
        bus: bus,
      ).createRuntime();

      await runtime.evaluate('adapter-1', _profile());
      final AdvancedCaptionRuntimeActionResult<CaptionRenderOutcome>
          result = await runtime.renderMatrixDanmaku(
        'adapter-1',
        MatrixDanmakuRequest(
          comments: <DanmakuComment>[],
          transform: CaptionTransform4(values: <double>[
            1, 0, 0, 0, //
            0, 1, 0, 0, //
            0, 0, 1, 0, //
            0, 0, 0, 1, //
          ]),
        ),
      );

      expect(result.isSuccess, isTrue);
      expect(result.value!.isSuccess, isTrue);
      await runtime.dispose();
      await bus.close();
    });
  });

  group('AdvancedCaptionRuntime renderDualSubtitles', () {
    test('returns typed success with rendered outcome', () async {
      final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
      final AdvancedCaptionRuntime runtime = _bootstrap(
        bus: bus,
      ).createRuntime();

      await runtime.evaluate('adapter-1', _profile());
      final AdvancedCaptionRuntimeActionResult<CaptionRenderOutcome>
          result = await runtime.renderDualSubtitles(
        'adapter-1',
        DualSubtitleRequest(
          primary: _subtitleSource('sub-en'),
          secondary: _subtitleSource('sub-jp'),
        ),
      );

      expect(result.isSuccess, isTrue);
      expect(result.value!.isSuccess, isTrue);
      await runtime.dispose();
      await bus.close();
    });
  });

  group('AdvancedCaptionRuntime disable', () {
    test('returns typed success with disabled outcome', () async {
      final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
      final AdvancedCaptionRuntime runtime = _bootstrap(
        bus: bus,
      ).createRuntime();

      await runtime.evaluate('adapter-1', _profile());
      final AdvancedCaptionRuntimeActionResult<CaptionDisableOutcome>
          result = await runtime.disable('adapter-1');

      expect(result.isSuccess, isTrue);
      expect(result.value!.isSuccess, isTrue);
      await runtime.dispose();
      await bus.close();
    });
  });

  group('AdvancedCaptionRuntime acceptDegradation', () {
    test('returns typed success with degraded outcome', () async {
      final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
      final AdvancedCaptionRuntime runtime = _bootstrap(
        bus: bus,
      ).createRuntime();

      await runtime.evaluate('adapter-1', _profile());
      final AdvancedCaptionRuntimeActionResult<CaptionDegradationOutcome>
          result = await runtime.acceptDegradation(
        'adapter-1',
        AVSyncDegradationAction.disableAdvancedCaptions,
        reason: 'AV sync drift exceeded threshold',
      );

      expect(result.isSuccess, isTrue);
      expect(result.value!.isSuccess, isTrue);
      await runtime.dispose();
      await bus.close();
    });
  });

  group('AdvancedCaptionRuntime unsupported', () {
    test('unsupported scope evaluate returns capabilityUnsupported',
        () async {
      final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
      final AdvancedCaptionRuntime runtime = _unsupportedBootstrap(bus: bus)
          .createRuntime();

      final AdvancedCaptionRuntimeActionResult<CaptionEvaluationOutcome>
          result =
          await runtime.evaluate('adapter-unsupported', _profile());

      expect(result.isSuccess, isFalse);
      expect(result.failure!.kind,
          AdvancedCaptionRuntimeFailureKind.capabilityUnsupported);
      await runtime.dispose();
      await bus.close();
    });
  });

  group('AdvancedCaptionRuntime unavailable', () {
    test('unavailable runtime rejects all operations', () async {
      final AdvancedCaptionRuntime runtime =
          AdvancedCaptionRuntime.unavailable(
              reason: 'No caption renderer available.');

      final AdvancedCaptionRuntimeActionResult<AdvancedCaptionRuntimeProjection>
          snapshot = await runtime.snapshot('any');
      final AdvancedCaptionRuntimeActionResult<CaptionEvaluationOutcome>
          evaluate = await runtime.evaluate('any', _profile());
      final AdvancedCaptionRuntimeActionResult<CaptionRenderOutcome>
          render = await runtime.renderMatrixDanmaku('any', _matrixRequest());
      final AdvancedCaptionRuntimeActionResult<CaptionDisableOutcome>
          disable = await runtime.disable('any');

      expect(snapshot.isSuccess, isFalse);
      expect(snapshot.failure!.kind,
          AdvancedCaptionRuntimeFailureKind.unavailable);
      expect(evaluate.isSuccess, isFalse);
      expect(evaluate.failure!.kind,
          AdvancedCaptionRuntimeFailureKind.unavailable);
      expect(render.isSuccess, isFalse);
      expect(render.failure!.kind,
          AdvancedCaptionRuntimeFailureKind.unavailable);
      expect(disable.isSuccess, isFalse);
      expect(disable.failure!.kind,
          AdvancedCaptionRuntimeFailureKind.unavailable);
    });
  });

  group('AdvancedCaptionRuntime disposed', () {
    test('disposed runtime rejects snapshot', () async {
      final AdvancedCaptionRuntime runtime = _bootstrap().createRuntime();
      await runtime.dispose();

      final AdvancedCaptionRuntimeActionResult<AdvancedCaptionRuntimeProjection>
          result = await runtime.snapshot('adapter-1');

      expect(result.isSuccess, isFalse);
      expect(
          result.failure!.kind, AdvancedCaptionRuntimeFailureKind.disposed);
    });
  });

  group('AdvancedCaptionRuntime invalidations', () {
    test('storage-visible invalidation events after evaluation and render',
        () async {
      final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
      final AdvancedCaptionRuntime runtime = _bootstrap(
        bus: bus,
      ).createRuntime();
      final Future<List<CacheInvalidationEvent>> events =
          bus.events.take(3).toList();

      await runtime.evaluate('adapter-1', _profile());
      await runtime.renderMatrixDanmaku('adapter-1', _matrixRequest());
      final List<CacheInvalidationEvent> delivered = await events;

      expect(
          delivered
              .whereType<AdvancedCaptionCapabilityReevaluated>()
              .length,
          greaterThanOrEqualTo(1));
      expect(
          delivered
              .whereType<AdvancedCaptionRendererStateChanged>()
              .length,
          greaterThanOrEqualTo(1));
      await runtime.dispose();
      await bus.close();
    });
  });

  group('AdvancedCaptionRuntime restart projection', () {
    test('restart projection replays stored renderer state and dual subtitle',
        () async {
      final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
      final DeterministicAdvancedCaptionStore store =
          DeterministicAdvancedCaptionStore(
        seedProfiles: <StoredAdvancedCaptionProfileRecord>[
          _storedProfile('ac-vivid'),
        ],
        seedActiveProfiles: <StoredActiveAdvancedCaptionProfileRecord>[
          StoredActiveAdvancedCaptionProfileRecord(
            scopeId: 'adapter-1',
            profileId: 'ac-vivid',
            selectedAt: DateTime.utc(2026, 6, 15, 12),
          ),
        ],
        seedRendererStates: <StoredAdvancedCaptionRendererStateRecord>[
          StoredAdvancedCaptionRendererStateRecord(
            scopeId: 'adapter-1',
            state: StoredAdvancedCaptionRendererStateKind.applied,
            supported: true,
            updatedAt: DateTime.utc(2026, 6, 15, 12),
            profileId: 'ac-vivid',
          ),
        ],
      );
      final AdvancedCaptionRuntimeBootstrap bootstrap = _bootstrap(
        store: store,
        bus: bus,
      );
      final AdvancedCaptionRuntime first = bootstrap.createRuntime();

      await first.evaluate('adapter-1', _profile());
      await first.renderDualSubtitles(
        'adapter-1',
        DualSubtitleRequest(
          primary: _subtitleSource('sub-en'),
          secondary: _subtitleSource('sub-jp'),
        ),
      );
      await first.dispose();

      // Restart: new runtime with same store
      final AdvancedCaptionRuntime second = bootstrap.createRuntime();
      final AdvancedCaptionRuntimeActionResult<AdvancedCaptionRuntimeProjection>
          result = await second.snapshot('adapter-1');

      expect(result.isSuccess, isTrue);
      expect(result.value!.restart.activeProfileId, 'ac-vivid');
      expect(result.value!.restart.latestRendererState,
          isNotNull);
      await second.dispose();
      await bus.close();
    });
  });
}

AdvancedCaptionRuntimeBootstrap _bootstrap({
  DeterministicAdvancedCaptionStore? store,
  StreamCacheInvalidationBus? bus,
}) {
  final DeterministicAdvancedCaptionStore captionStore =
      store ?? DeterministicAdvancedCaptionStore(
        seedProfiles: <StoredAdvancedCaptionProfileRecord>[
          _storedProfile('ac-vivid'),
        ],
      );
  return AdvancedCaptionRuntimeBootstrap(
    captionStore: captionStore,
    rendererByScope: <String, DeterministicAdvancedCaptionRenderer>{
      'adapter-1': DeterministicAdvancedCaptionRenderer(
        captionStore: captionStore,
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
  );
}

AdvancedCaptionRuntimeBootstrap _unsupportedBootstrap({
  StreamCacheInvalidationBus? bus,
}) {
  final DeterministicAdvancedCaptionStore captionStore =
      DeterministicAdvancedCaptionStore();
  return AdvancedCaptionRuntimeBootstrap(
    captionStore: captionStore,
    rendererByScope: <String, DeterministicAdvancedCaptionRenderer>{
      'adapter-unsupported': DeterministicAdvancedCaptionRenderer(
        captionStore: captionStore,
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
  );
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
    createdAt: DateTime.utc(2026, 6, 15, 12),
    updatedAt: DateTime.utc(2026, 6, 15, 12),
  );
}

PlaybackCapabilityMatrix _supportedCapabilities() {
  return PlaybackCapabilityMatrix(
    capabilities: <PlaybackCapability, CapabilityStatus>{
      PlaybackCapability.matrixDanmaku:
          const CapabilityStatus.supported(),
      PlaybackCapability.dualSubtitles:
          const CapabilityStatus.supported(),
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

SubtitleSource _subtitleSource(String id) {
  return EmbeddedSubtitleSource(
    id: id,
    format: SubtitleFormat.srt,
    languageCode: 'en',
    trackId: 'track-$id',
  );
}

MatrixDanmakuRequest _matrixRequest() {
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

DateTime _now() => DateTime.utc(2026, 6, 15, 12);
