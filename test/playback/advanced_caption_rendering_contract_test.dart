import 'package:celesteria/celesteria.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'advanced caption store persists profile active selection dual subtitles and state',
      () async {
    final DeterministicAdvancedCaptionStore store =
        DeterministicAdvancedCaptionStore();
    final DateTime observedAt = DateTime.utc(2026, 6, 7, 12);

    await store.storeProfile(_storedProfile(observedAt));
    await store.setActiveProfile(StoredActiveAdvancedCaptionProfileRecord(
      scopeId: 'adapter-1',
      profileId: 'anime-captions',
      selectedAt: observedAt,
    ));
    await store.setDualSubtitleSelection(
      StoredAdvancedCaptionDualSubtitleSelectionRecord(
        scopeId: 'adapter-1',
        profileId: 'anime-captions',
        primarySubtitleId: 'subtitle-ja',
        secondarySubtitleId: 'subtitle-en',
        primaryLanguageCode: 'ja',
        secondaryLanguageCode: 'en',
        selectedAt: observedAt,
      ),
    );
    await store.recordRendererState(StoredAdvancedCaptionRendererStateRecord(
      scopeId: 'adapter-1',
      profileId: 'anime-captions',
      feature: AdvancedCaptionFeature.dualSubtitles.name,
      state: StoredAdvancedCaptionRendererStateKind.applied,
      supported: true,
      updatedAt: observedAt,
    ));

    expect((await store.findProfileById('anime-captions'))?.label,
        'Anime Captions');
    expect(
        (await store.activeProfile('adapter-1'))?.profileId, 'anime-captions');
    expect((await store.dualSubtitleSelection('adapter-1'))?.primarySubtitleId,
        'subtitle-ja');
    expect((await store.latestRendererState('adapter-1'))?.state,
        StoredAdvancedCaptionRendererStateKind.applied);
  });

  test('deterministic renderer evaluates unsupported capabilities with reasons',
      () async {
    final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
    final DeterministicAdvancedCaptionRenderer renderer =
        DeterministicAdvancedCaptionRenderer(
      captionStore: DeterministicAdvancedCaptionStore(),
      capabilityMatrix: PlaybackCapabilityMatrix(
        capabilities: <PlaybackCapability, CapabilityStatus>{
          PlaybackCapability.matrixDanmaku: const CapabilityStatus.supported(),
          PlaybackCapability.dualSubtitles: const CapabilityStatus.supported(),
          PlaybackCapability.pgsSubtitleRendering:
              const CapabilityStatus.unsupported('PGS unavailable.'),
          PlaybackCapability.assSubtitleEnhancement:
              const CapabilityStatus.unsupported(
                  'ASS enhancement unavailable.'),
        },
      ),
      profile: _profile(),
      cacheInvalidationBus: bus,
      clock: () => DateTime.utc(2026, 6, 7, 12),
    );
    final Future<List<CacheInvalidationEvent>> events =
        bus.events.take(2).toList();

    final CaptionEvaluationOutcome outcome =
        await renderer.evaluate(_profile());
    final List<CacheInvalidationEvent> delivered = await events;

    expect(outcome.isSuccess, isTrue);
    expect(outcome.report?.supported, isFalse);
    expect(outcome.report?.reason, contains('PGS unavailable.'));
    expect(
        delivered.whereType<AdvancedCaptionRendererStateChanged>(), isNotEmpty);
    expect(delivered.whereType<AdvancedCaptionCapabilityReevaluated>(),
        isNotEmpty);
    await bus.close();
  });

  test('deterministic renderer renders disables and publishes invalidation',
      () async {
    final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
    final DeterministicAdvancedCaptionStore store =
        DeterministicAdvancedCaptionStore();
    final DeterministicAdvancedCaptionRenderer renderer =
        DeterministicAdvancedCaptionRenderer(
      captionStore: store,
      capabilityMatrix: _supportedCapabilities(),
      profile: _profile(),
      cacheInvalidationBus: bus,
      scopeId: 'adapter-1',
      clock: () => DateTime.utc(2026, 6, 7, 12),
    );
    final Future<List<CacheInvalidationEvent>> renderEvents =
        bus.events.take(4).toList();

    final CaptionRenderOutcome rendered = await renderer.renderMatrixDanmaku(
      MatrixDanmakuRequest(
        comments: const <DanmakuComment>[
          DanmakuComment(
            id: DanmakuCommentId('comment-1'),
            timestamp: Duration(seconds: 1),
            text: 'runtime danmaku',
            mode: DanmakuMode.scrolling,
          ),
        ],
        transform: CaptionTransform4(values: List<double>.filled(16, 1)),
      ),
    );
    final List<CacheInvalidationEvent> deliveredRender = await renderEvents;
    final StoredAdvancedCaptionRendererStateRecord? appliedState =
        await store.latestRendererState('adapter-1');
    final Future<CacheInvalidationEvent> disabledEvent = bus.events.first;
    final CaptionDisableOutcome disabled = await renderer.disable();
    final CacheInvalidationEvent deliveredDisabled = await disabledEvent;

    expect(rendered.isSuccess, isTrue);
    expect(
        (await store.activeProfile('adapter-1'))?.profileId, 'anime-captions');
    expect(appliedState?.state, StoredAdvancedCaptionRendererStateKind.applied);
    expect(
        deliveredRender.whereType<AdvancedCaptionProfileChanged>(), isNotEmpty);
    expect(deliveredRender.whereType<AdvancedCaptionRendererStateChanged>(),
        isNotEmpty);
    expect(disabled.isSuccess, isTrue);
    expect(deliveredDisabled, isA<AdvancedCaptionRendererStateChanged>());
    await bus.close();
  });

  test('dual subtitles preserve order and reject duplicate tracks', () async {
    final DeterministicAdvancedCaptionStore store =
        DeterministicAdvancedCaptionStore();
    final DeterministicAdvancedCaptionRenderer renderer =
        DeterministicAdvancedCaptionRenderer(
      captionStore: store,
      capabilityMatrix: _supportedCapabilities(),
      profile: _profile(),
      scopeId: 'adapter-1',
      clock: () => DateTime.utc(2026, 6, 7, 12),
    );

    final CaptionRenderOutcome rendered = await renderer.renderDualSubtitles(
      DualSubtitleRequest(
          primary: _subtitle('subtitle-ja', 'ja'),
          secondary: _subtitle('subtitle-en', 'en')),
    );
    final CaptionRenderOutcome rejected = await renderer.renderDualSubtitles(
      DualSubtitleRequest(
          primary: _subtitle('subtitle-ja', 'ja'),
          secondary: _subtitle('subtitle-ja', 'ja')),
    );

    expect(rendered.isSuccess, isTrue);
    expect((await store.dualSubtitleSelection('adapter-1'))?.primarySubtitleId,
        'subtitle-ja');
    expect(
        (await store.dualSubtitleSelection('adapter-1'))?.secondarySubtitleId,
        'subtitle-en');
    expect(rejected.isSuccess, isFalse);
    expect(rejected.failure?.kind,
        AdvancedCaptionFailureKind.dualSubtitleOrderRejected);
  });

  test('unsupported PGS render returns typed capability failure', () async {
    final DeterministicAdvancedCaptionRenderer renderer =
        DeterministicAdvancedCaptionRenderer(
      captionStore: DeterministicAdvancedCaptionStore(),
      capabilityMatrix: PlaybackCapabilityMatrix(
        capabilities: <PlaybackCapability, CapabilityStatus>{
          PlaybackCapability.matrixDanmaku: const CapabilityStatus.supported(),
          PlaybackCapability.dualSubtitles: const CapabilityStatus.supported(),
          PlaybackCapability.pgsSubtitleRendering:
              const CapabilityStatus.unsupported('PGS unavailable.'),
          PlaybackCapability.assSubtitleEnhancement:
              const CapabilityStatus.supported(),
        },
      ),
      profile: _profile(),
    );

    final CaptionRenderOutcome outcome = await renderer.renderAdvancedSubtitle(
      AdvancedSubtitleRequest(
        source: _subtitle('subtitle-pgs', 'ja'),
        intent: AdvancedSubtitleRenderIntent.pgsImageSubtitle,
      ),
    );

    expect(outcome.isSuccess, isFalse);
    expect(outcome.failure?.kind,
        AdvancedCaptionFailureKind.capabilityUnsupported);
    expect(outcome.failure?.message, contains('PGS unavailable.'));
  });

  test('AVSyncGuard disableAdvancedCaptions is accepted declaratively',
      () async {
    final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
    final DeterministicAdvancedCaptionStore store =
        DeterministicAdvancedCaptionStore();
    final DeterministicAdvancedCaptionRenderer renderer =
        DeterministicAdvancedCaptionRenderer(
      captionStore: store,
      capabilityMatrix: _supportedCapabilities(),
      profile: _profile(),
      cacheInvalidationBus: bus,
      scopeId: 'adapter-1',
      clock: () => DateTime.utc(2026, 6, 7, 12),
    );
    final Future<List<CacheInvalidationEvent>> events =
        bus.events.take(2).toList();

    final CaptionDegradationOutcome outcome = await renderer.acceptDegradation(
      AVSyncDegradationAction.disableAdvancedCaptions,
      reason: 'A/V drift exceeded 120ms.',
    );
    final List<CacheInvalidationEvent> delivered = await events;

    expect(outcome.isSuccess, isTrue);
    expect((await store.latestRendererState('adapter-1'))?.state,
        StoredAdvancedCaptionRendererStateKind.degraded);
    expect(
        delivered.whereType<AdvancedCaptionRendererStateChanged>(), isNotEmpty);
    expect(delivered.whereType<AdvancedCaptionDegradationStateChanged>(),
        isNotEmpty);
    await bus.close();
  });
}

StoredAdvancedCaptionProfileRecord _storedProfile(DateTime observedAt) {
  return StoredAdvancedCaptionProfileRecord(
    id: 'anime-captions',
    label: 'Anime Captions',
    matrixDanmakuEnabled: true,
    dualSubtitlesEnabled: true,
    pgsRenderingEnabled: true,
    assEnhancementEnabled: true,
    primarySubtitleLanguageCode: 'ja',
    secondarySubtitleLanguageCode: 'en',
    isBuiltIn: true,
    createdAt: observedAt,
    updatedAt: observedAt,
  );
}

AdvancedCaptionProfile _profile() {
  return const AdvancedCaptionProfile(
    id: AdvancedCaptionProfileId('anime-captions'),
    label: 'Anime Captions',
    matrixDanmakuEnabled: true,
    dualSubtitlesEnabled: true,
    pgsRenderingEnabled: true,
    assEnhancementEnabled: true,
    primarySubtitleLanguageCode: 'ja',
    secondarySubtitleLanguageCode: 'en',
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

ExternalSubtitleSource _subtitle(String id, String languageCode) {
  return ExternalSubtitleSource(
    id: id,
    format: SubtitleFormat.ass,
    languageCode: languageCode,
    uri: Uri.file('D:/media/$id.ass'),
  );
}
