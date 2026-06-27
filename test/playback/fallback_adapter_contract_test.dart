// Fallback adapter contract tests define capability-loss visibility before the
// runtime persists selections or UI renders fallback warnings.
import 'package:elaina/elaina.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fallback store persists candidates configuration history and state',
      () async {
    final DeterministicFallbackAdapterStore store =
        DeterministicFallbackAdapterStore();
    final DateTime observedAt = DateTime.utc(2026, 6, 7, 12);

    await store.storeCandidate(StoredFallbackAdapterCandidateRecord(
      id: 'fallback-vlc-contract',
      displayName: 'Contract Fallback Adapter',
      priority: 1,
      declaredCapabilities: const <String, String>{
        'fallbackAdapter': 'supported',
      },
      registeredAt: observedAt,
    ));
    await store.setActiveConfiguration(StoredActiveFallbackConfigurationRecord(
      scopeId: 'playback-scope',
      enabled: true,
      selectedCandidateId: 'fallback-vlc-contract',
      selectedAt: observedAt,
      updatedAt: observedAt,
    ));
    await store.recordSelection(StoredFallbackSelectionHistoryRecord(
      id: 'history-1',
      scopeId: 'playback-scope',
      candidateId: 'fallback-vlc-contract',
      sourceKind: 'LocalFilePlaybackSource',
      failureKind: FallbackFailureKind.loadFailure.name,
      reason: 'Runtime fallback selected.',
      hiddenCapabilities: const <String, String>{
        'anime4kPreset': 'Fallback lacks enhancement.',
      },
      selectedAt: observedAt,
    ));
    await store.recordStrategyState(StoredFallbackStrategyStateRecord(
      scopeId: 'playback-scope',
      state: StoredFallbackStrategyStateKind.selected,
      supported: true,
      selectedCandidateId: 'fallback-vlc-contract',
      updatedAt: observedAt,
    ));

    expect(
        (await store.findCandidateById('fallback-vlc-contract'))?.priority, 1);
    expect(
        (await store.activeConfiguration('playback-scope'))?.enabled, isTrue);
    expect((await store.selectionHistory('playback-scope')).single.candidateId,
        'fallback-vlc-contract');
    expect((await store.latestStrategyState('playback-scope'))?.state,
        StoredFallbackStrategyStateKind.selected);
  });

  test(
      'deterministic fallback selects compatible candidate and publishes events',
      () async {
    final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
    final DeterministicFallbackAdapterStore store =
        DeterministicFallbackAdapterStore();
    final DeterministicPlaybackFallbackStrategy strategy =
        DeterministicPlaybackFallbackStrategy(
      store: store,
      cacheInvalidationBus: bus,
      scopeId: 'playback-scope',
      clock: () => DateTime.utc(2026, 6, 7, 12),
    );
    final Future<List<CacheInvalidationEvent>> events =
        bus.events.take(3).toList();

    final FallbackRegistrationOutcome registered =
        await strategy.register(_candidate(
      id: 'fallback-vlc-contract',
      capabilities: _fallbackCapabilities(),
    ));
    final FallbackEvaluationOutcome selected = await strategy.selectFallback(
      source: LocalFilePlaybackSource(uri: Uri.file('D:/media/runtime.mkv')),
      failure: const FallbackFailure(
        kind: FallbackFailureKind.loadFailure,
        message: 'Primary adapter failed to load.',
      ),
    );
    final List<CacheInvalidationEvent> delivered = await events;

    expect(registered.isSuccess, isTrue);
    expect(selected.isSuccess, isTrue);
    expect(selected.selection?.candidate.id.value, 'fallback-vlc-contract');
    expect(selected.selection?.hiddenCapabilities,
        contains(PlaybackCapability.anime4kPreset));
    expect(
        (await store.activeConfiguration('playback-scope'))?.enabled, isTrue);
    expect((await store.selectionHistory('playback-scope')).single.failureKind,
        FallbackFailureKind.loadFailure.name);
    expect(
        delivered.whereType<FallbackAdapterRegistrationChanged>(), isNotEmpty);
    expect(delivered.whereType<FallbackStrategyStateChanged>(), isNotEmpty);
    expect(delivered.whereType<FallbackSelectionChanged>(), isNotEmpty);
    await bus.close();
  });

  test('fallback reports no candidate and disabled rejection explicitly',
      () async {
    final DeterministicPlaybackFallbackStrategy emptyStrategy =
        DeterministicPlaybackFallbackStrategy(
      store: DeterministicFallbackAdapterStore(),
    );
    final FallbackEvaluationOutcome noCandidate =
        await emptyStrategy.selectFallback(
      source: LocalFilePlaybackSource(uri: Uri.file('D:/media/runtime.mkv')),
      failure: const FallbackFailure(
        kind: FallbackFailureKind.loadFailure,
        message: 'Primary adapter failed to load.',
      ),
    );

    final DeterministicPlaybackFallbackStrategy disabledStrategy =
        DeterministicPlaybackFallbackStrategy(
      store: DeterministicFallbackAdapterStore(),
    );
    await disabledStrategy.register(_candidate(
      id: 'disabled-fallback',
      capabilities: _fallbackCapabilities(),
    ));
    final FallbackDisableOutcome disabled = await disabledStrategy.disable();
    final FallbackEvaluationOutcome disabledSelection =
        await disabledStrategy.selectFallback(
      source: LocalFilePlaybackSource(uri: Uri.file('D:/media/runtime.mkv')),
      failure: const FallbackFailure(
        kind: FallbackFailureKind.loadFailure,
        message: 'Primary adapter failed to load.',
      ),
    );

    expect(
        noCandidate.failure?.kind, FallbackEvaluationFailureKind.noCandidate);
    expect(disabled.isSuccess, isTrue);
    expect(disabledSelection.failure?.kind,
        FallbackEvaluationFailureKind.disabled);
  });

  test('fallback capability reevaluation exposes hidden capability reasons',
      () async {
    final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
    final DeterministicPlaybackFallbackStrategy strategy =
        DeterministicPlaybackFallbackStrategy(
      store: DeterministicFallbackAdapterStore(),
      cacheInvalidationBus: bus,
      clock: () => DateTime.utc(2026, 6, 7, 12),
    );
    await strategy.register(_candidate(
      id: 'fallback-capability-contract',
      capabilities: _fallbackCapabilities(),
    ));
    final Future<CacheInvalidationEvent> event = bus.events.first;

    final FallbackCapabilityReevaluationOutcome outcome =
        await strategy.reevaluateCapabilities(
            const FallbackAdapterId('fallback-capability-contract'));
    final CacheInvalidationEvent delivered = await event;

    expect(outcome.isSuccess, isTrue);
    expect(outcome.readModel?.hidesAnyCapability, isTrue);
    expect(outcome.readModel?.hiddenCapabilityReasons(),
        contains('Fallback Anime4K unavailable.'));
    expect(delivered, isA<FallbackCapabilityReevaluated>());
    await bus.close();
  });
}

FallbackAdapterCandidate _candidate({
  required String id,
  required PlaybackCapabilityMatrix capabilities,
}) {
  return FallbackAdapterCandidate(
    id: FallbackAdapterId(id),
    adapter: _FallbackTestAdapter(id: id, capabilities: capabilities),
    capabilities: capabilities,
  );
}

PlaybackCapabilityMatrix _fallbackCapabilities() {
  return PlaybackCapabilityMatrix(
    capabilities: <PlaybackCapability, CapabilityStatus>{
      PlaybackCapability.fallbackAdapter: const CapabilityStatus.supported(),
      PlaybackCapability.localFilePlayback: const CapabilityStatus.supported(),
      PlaybackCapability.anime4kPreset:
          const CapabilityStatus.unsupported('Fallback Anime4K unavailable.'),
    },
  );
}

final class _FallbackTestAdapter implements PlayerAdapter {
  const _FallbackTestAdapter({required this.id, required this.capabilities});

  @override
  final String id;

  @override
  String get displayName => 'Fallback Test Adapter';

  @override
  final PlaybackCapabilityMatrix capabilities;

  @override
  Future<PlaybackCommandResult> dispose() =>
      Future<PlaybackCommandResult>.value(
          const PlaybackCommandResult.success());

  @override
  Future<TrackDiscoveryResult> discoverTracks() =>
      Future<TrackDiscoveryResult>.value(
        TrackDiscoveryResult.unsupported(reason: 'Tracks unsupported.'),
      );

  @override
  Future<PlaybackCommandResult> load(PlaybackSource source) =>
      Future<PlaybackCommandResult>.value(
          const PlaybackCommandResult.success());

  @override
  Future<PlaybackCommandResult> pause() => Future<PlaybackCommandResult>.value(
      const PlaybackCommandResult.success());

  @override
  Future<PlaybackCommandResult> play() => Future<PlaybackCommandResult>.value(
      const PlaybackCommandResult.success());

  @override
  Future<PlaybackCommandResult> seek(Duration position) =>
      Future<PlaybackCommandResult>.value(
          const PlaybackCommandResult.success());

  @override
  Future<PlaybackCommandResult> stop() => Future<PlaybackCommandResult>.value(
      const PlaybackCommandResult.success());

  @override
  Future<TrackSwitchResult> switchTrack(MediaTrackId trackId) =>
      Future<TrackSwitchResult>.value(
          const TrackSwitchResult.unsupported('Tracks unsupported.'));

  @override
  Future<EnhancementApplyOutcome> applyEnhancement(
          VideoEnhancementProfile profile) =>
      Future<EnhancementApplyOutcome>.value(
        const EnhancementApplyOutcome.rejected(
          failure: EnhancementPipelineFailure(
            kind: EnhancementPipelineFailureKind.capabilityUnsupported,
            message: 'Enhancement unsupported.',
          ),
        ),
      );

  @override
  Future<EnhancementDisableOutcome> disableEnhancement() =>
      Future<EnhancementDisableOutcome>.value(
        const EnhancementDisableOutcome.rejected(
          failure: EnhancementPipelineFailure(
            kind: EnhancementPipelineFailureKind.capabilityUnsupported,
            message: 'Enhancement unsupported.',
          ),
        ),
      );
}
