import 'package:elaina/elaina.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('initial snapshot replays stored fallback state with restart projection',
      () async {
    final _RuntimeHarness harness = await _createHarness();
    final FallbackAdapterRuntimeActionResult<FallbackAdapterRuntimeProjection>
        result = await harness.runtime.snapshot('adapter-1');

    expect(result.isSuccess, isTrue);
    final FallbackAdapterRuntimeProjection proj = result.value!;
    expect(proj.scopeId, 'adapter-1');
    expect(proj.enabled, isTrue);
    expect(proj.strategyState, StoredFallbackStrategyStateKind.selected);
    expect(proj.selectedCandidateId, 'fallback-vlc-runtime');
    expect(proj.latestSelectionCandidateId, isNull);
    expect(proj.restart.scopeId, 'adapter-1');
    expect(proj.restart.enabled, isTrue);
    expect(proj.restart.selectedCandidateId, 'fallback-vlc-runtime');
    expect(
        proj.restart.strategyState, StoredFallbackStrategyStateKind.selected);
  });

  test('registerCandidate succeeds and publishes invalidation', () async {
    final _RuntimeHarness harness = await _createHarness();
    final Future<List<CacheInvalidationEvent>> regEvents =
        harness.eventsOfType<FallbackAdapterRegistrationChanged>();
    final FallbackAdapterCandidate candidate = _candidate(
      id: 'fallback-extra',
      capabilities: _fallbackCapabilities(),
    );
    final FallbackAdapterRuntimeActionResult<FallbackAdapterRuntimeProjection>
        result =
        await harness.runtime.registerCandidate('adapter-1', candidate);

    expect(result.isSuccess, isTrue);
    expect(result.value!.latestRegistrationOutcome?.isSuccess, isTrue);
    final List<CacheInvalidationEvent> delivered = await regEvents;
    expect(delivered, isNotEmpty);
  });

  test('deregisterCandidate succeeds', () async {
    final _RuntimeHarness harness = await _createHarness();
    final FallbackAdapterRuntimeActionResult<FallbackAdapterRuntimeProjection>
        result = await harness.runtime.deregisterCandidate(
            'adapter-1', const FallbackAdapterId('fallback-vlc-runtime'));

    expect(result.isSuccess, isTrue);
  });

  test('selectFallback succeeds with typed projection and invalidation',
      () async {
    final _RuntimeHarness harness = await _createHarness();
    final Future<List<CacheInvalidationEvent>> stateEvents =
        harness.eventsOfType<FallbackStrategyStateChanged>();
    final Future<List<CacheInvalidationEvent>> selEvents =
        harness.eventsOfType<FallbackSelectionChanged>();
    final FallbackAdapterRuntimeActionResult<FallbackAdapterRuntimeProjection>
        result = await harness.runtime.selectFallback(
      scopeId: 'adapter-1',
      source: LocalFilePlaybackSource(uri: Uri.file('D:/media/runtime.mkv')),
      failure: const FallbackFailure(
        kind: FallbackFailureKind.loadFailure,
        message: 'Primary adapter failed to load.',
      ),
    );

    expect(result.isSuccess, isTrue);
    final FallbackAdapterRuntimeProjection proj = result.value!;
    expect(proj.latestSelectionCandidateId, isNotNull);
    expect(proj.strategyState, StoredFallbackStrategyStateKind.selected);
    expect(await stateEvents, isNotEmpty);
    expect(await selEvents, isNotEmpty);
  });

  test('disable succeeds with disabled strategy state and invalidation',
      () async {
    final _RuntimeHarness harness = await _createHarness();
    final Future<List<CacheInvalidationEvent>> disabledEvents =
        harness.eventsOfType<FallbackDisabled>();
    final FallbackAdapterRuntimeActionResult<FallbackAdapterRuntimeProjection>
        result = await harness.runtime.disable('adapter-1');

    expect(result.isSuccess, isTrue);
    expect(
        result.value!.strategyState, StoredFallbackStrategyStateKind.disabled);
    expect(await disabledEvents, isNotEmpty);
  });

  test('reevaluateCapabilities succeeds with hidden capabilities read model',
      () async {
    final _RuntimeHarness harness = await _createHarness();
    final Future<List<CacheInvalidationEvent>> capEvents =
        harness.eventsOfType<FallbackCapabilityReevaluated>();
    final FallbackAdapterRuntimeActionResult<FallbackAdapterRuntimeProjection>
        result = await harness.runtime.reevaluateCapabilities(
      scopeId: 'adapter-1',
      candidateId: const FallbackAdapterId('fallback-vlc-runtime'),
    );

    expect(result.isSuccess, isTrue);
    expect(result.value!.latestCapabilityReadModel, isNotNull);
    expect(result.value!.latestCapabilityReadModel!.hidesAnyCapability, isTrue);
    expect(await capEvents, isNotEmpty);
  });

  test('unsupported scope returns capabilityUnsupported', () async {
    final _RuntimeHarness harness = await _createHarness();
    final FallbackAdapterRuntimeActionResult<FallbackAdapterRuntimeProjection>
        result =
        await harness.unsupportedRuntime.snapshot('adapter-unsupported');

    expect(result.isSuccess, isFalse);
    expect(result.failure?.kind,
        FallbackAdapterRuntimeFailureKind.capabilityUnsupported);
  });

  test('unavailable runtime rejects all six operations', () async {
    final FallbackAdapterRuntime unavailable =
        FallbackAdapterRuntime.unavailable(reason: 'No fallback service.');
    final FallbackAdapterCandidate candidate = _candidate(
      id: 'fallback-unavailable',
      capabilities: _fallbackCapabilities(),
    );

    final List<
        Future<
            FallbackAdapterRuntimeActionResult<
                FallbackAdapterRuntimeProjection>>> ops = <Future<
        FallbackAdapterRuntimeActionResult<FallbackAdapterRuntimeProjection>>>[
      unavailable.snapshot('any'),
      unavailable.registerCandidate('any', candidate),
      unavailable.deregisterCandidate('any', const FallbackAdapterId('x')),
      unavailable.selectFallback(
        scopeId: 'any',
        source:
            LocalFilePlaybackSource(uri: Uri.file('D:/media/unavailable.mkv')),
        failure: const FallbackFailure(
            kind: FallbackFailureKind.loadFailure, message: 'failed'),
      ),
      unavailable.disable('any'),
      unavailable.reevaluateCapabilities(
          scopeId: 'any', candidateId: const FallbackAdapterId('x')),
    ];

    for (final Future<
        FallbackAdapterRuntimeActionResult<
            FallbackAdapterRuntimeProjection>> op in ops) {
      final FallbackAdapterRuntimeActionResult<FallbackAdapterRuntimeProjection>
          r = await op;
      expect(r.isSuccess, isFalse);
      expect(r.failure?.kind, FallbackAdapterRuntimeFailureKind.unavailable);
    }
  });

  test('disposed runtime rejects snapshot', () async {
    final _RuntimeHarness harness = await _createHarness();
    await harness.runtime.dispose();
    final FallbackAdapterRuntimeActionResult<FallbackAdapterRuntimeProjection>
        result = await harness.runtime.snapshot('adapter-1');

    expect(result.isSuccess, isFalse);
    expect(result.failure?.kind, FallbackAdapterRuntimeFailureKind.disposed);
  });

  test('invalidation events arrive after store visibility', () async {
    final _RuntimeHarness harness = await _createHarness();
    final Future<List<CacheInvalidationEvent>> regEvents =
        harness.eventsOfType<FallbackAdapterRegistrationChanged>();
    final FallbackAdapterCandidate candidate = _candidate(
      id: 'fallback-invalidation',
      capabilities: _fallbackCapabilities(),
    );
    await harness.runtime.registerCandidate('adapter-1', candidate);
    final List<CacheInvalidationEvent> delivered = await regEvents;
    expect(delivered, isNotEmpty);
  });

  test('domain failure kinds map from contract failures', () async {
    final DeterministicPlaybackFallbackStrategy noCandidateStrategy =
        DeterministicPlaybackFallbackStrategy(
      store: DeterministicFallbackAdapterStore(),
      scopeId: 'adapter-nocand',
    );
    final FallbackAdapterRuntime noCandidateRuntime = FallbackAdapterBootstrap(
      store: noCandidateStrategy.store,
      strategyByScope: <String, DeterministicPlaybackFallbackStrategy>{
        'adapter-nocand': noCandidateStrategy,
      },
      capabilitiesByScope: <String, PlaybackCapabilityMatrix>{
        'adapter-nocand': _supportedCapabilities(),
      },
    ).createRuntime();

    final FallbackAdapterRuntimeActionResult<FallbackAdapterRuntimeProjection>
        result = await noCandidateRuntime.selectFallback(
      scopeId: 'adapter-nocand',
      source: LocalFilePlaybackSource(uri: Uri.file('D:/media/nocand.mkv')),
      failure: const FallbackFailure(
          kind: FallbackFailureKind.loadFailure, message: 'failed'),
    );

    expect(result.isSuccess, isFalse);
    expect(result.failure?.kind, FallbackAdapterRuntimeFailureKind.noCandidate);
  });
}

// --- Harness ---

Future<_RuntimeHarness> _createHarness() async {
  final DeterministicFallbackAdapterStore store =
      DeterministicFallbackAdapterStore(
    seedConfigurations: <StoredActiveFallbackConfigurationRecord>[
      StoredActiveFallbackConfigurationRecord(
        scopeId: 'adapter-1',
        enabled: true,
        selectedCandidateId: 'fallback-vlc-runtime',
        selectedAt: _now(),
        updatedAt: _now(),
      ),
    ],
    seedStrategyStates: <StoredFallbackStrategyStateRecord>[
      StoredFallbackStrategyStateRecord(
        scopeId: 'adapter-1',
        state: StoredFallbackStrategyStateKind.selected,
        supported: true,
        selectedCandidateId: 'fallback-vlc-runtime',
        updatedAt: _now(),
      ),
    ],
  );

  final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();

  final DeterministicPlaybackFallbackStrategy strategy =
      DeterministicPlaybackFallbackStrategy(
    store: store,
    cacheInvalidationBus: bus,
    scopeId: 'adapter-1',
    clock: _now,
  );

  // Pre-register the seeded candidate so strategy has it in memory
  await strategy.register(_candidate(
    id: 'fallback-vlc-runtime',
    capabilities: _fallbackCapabilities(),
  ));

  final FallbackAdapterRuntime runtime = FallbackAdapterBootstrap(
    store: store,
    strategyByScope: <String, DeterministicPlaybackFallbackStrategy>{
      'adapter-1': strategy,
    },
    capabilitiesByScope: <String, PlaybackCapabilityMatrix>{
      'adapter-1': _supportedCapabilities(),
    },
  ).createRuntime();

  final FallbackAdapterRuntime unsupportedRuntime = FallbackAdapterBootstrap(
    store: DeterministicFallbackAdapterStore(),
    strategyByScope: <String, DeterministicPlaybackFallbackStrategy>{
      'adapter-unsupported': DeterministicPlaybackFallbackStrategy(
        store: DeterministicFallbackAdapterStore(),
        scopeId: 'adapter-unsupported',
      ),
    },
    capabilitiesByScope: <String, PlaybackCapabilityMatrix>{
      'adapter-unsupported':
          PlaybackCapabilityMatrix.unsupported(reason: 'All unsupported.'),
    },
  ).createRuntime();

  return _RuntimeHarness._(
    runtime: runtime,
    unsupportedRuntime: unsupportedRuntime,
    bus: bus,
  );
}

final class _RuntimeHarness {
  _RuntimeHarness._({
    required this.runtime,
    required this.unsupportedRuntime,
    required StreamCacheInvalidationBus bus,
  }) : _bus = bus;

  final FallbackAdapterRuntime runtime;
  final FallbackAdapterRuntime unsupportedRuntime;
  final StreamCacheInvalidationBus _bus;

  Future<List<T>> eventsOfType<T extends CacheInvalidationEvent>() async {
    return _bus.events
        .where((CacheInvalidationEvent e) => e is T)
        .cast<T>()
        .take(1)
        .toList();
  }
}

DateTime _now() => DateTime.utc(2026, 6, 15, 12);

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

PlaybackCapabilityMatrix _supportedCapabilities() {
  return PlaybackCapabilityMatrix(
    capabilities: <PlaybackCapability, CapabilityStatus>{
      PlaybackCapability.fallbackAdapter: const CapabilityStatus.supported(),
      PlaybackCapability.localFilePlayback: const CapabilityStatus.supported(),
      PlaybackCapability.anime4kPreset: const CapabilityStatus.supported(),
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
}
