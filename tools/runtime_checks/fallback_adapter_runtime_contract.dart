import 'dart:io';

import '../../lib/elaina.dart';

void main() {
  verifyFallbackAdapterRuntimeContract();
}

void _expect(bool condition, String message) {
  if (!condition) throw StateError(message);
}

Future<void> verifyFallbackAdapterRuntimeContract() async {
  // --- Harness setup ---
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

  // Pre-register seeded candidate
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

  // 1. Initial snapshot replays stored state and restart projection
  final FallbackAdapterRuntimeActionResult<FallbackAdapterRuntimeProjection>
      snapshotResult = await runtime.snapshot('adapter-1');
  _expect(snapshotResult.isSuccess, 'Initial snapshot must succeed.');
  final FallbackAdapterRuntimeProjection proj = snapshotResult.value!;
  _expect(proj.scopeId == 'adapter-1', 'scopeId must be adapter-1.');
  _expect(proj.enabled == true, 'enabled must be true.');
  _expect(proj.strategyState == StoredFallbackStrategyStateKind.selected,
      'strategyState must be selected.');
  _expect(proj.selectedCandidateId == 'fallback-vlc-runtime',
      'selectedCandidateId must be fallback-vlc-runtime.');
  _expect(proj.restart.scopeId == 'adapter-1',
      'restart.scopeId must be adapter-1.');
  _expect(proj.restart.enabled == true, 'restart.enabled must be true.');
  _expect(proj.restart.selectedCandidateId == 'fallback-vlc-runtime',
      'restart.selectedCandidateId must be fallback-vlc-runtime.');
  _expect(
      proj.restart.strategyState == StoredFallbackStrategyStateKind.selected,
      'restart.strategyState must be selected.');

  // 2. registerCandidate succeeds
  final FallbackAdapterCandidate extraCandidate = _candidate(
    id: 'fallback-extra',
    capabilities: _fallbackCapabilities(),
  );
  final FallbackAdapterRuntimeActionResult<FallbackAdapterRuntimeProjection>
      regResult = await runtime.registerCandidate('adapter-1', extraCandidate);
  _expect(regResult.isSuccess, 'registerCandidate must succeed.');
  _expect(regResult.value!.latestRegistrationOutcome?.isSuccess == true,
      'registration outcome must succeed.');

  // 3. selectFallback succeeds
  final FallbackAdapterRuntimeActionResult<FallbackAdapterRuntimeProjection>
      selResult = await runtime.selectFallback(
    scopeId: 'adapter-1',
    source: LocalFilePlaybackSource(uri: Uri.file('D:/media/check.mkv')),
    failure: const FallbackFailure(
        kind: FallbackFailureKind.loadFailure, message: 'Primary failed.'),
  );
  _expect(selResult.isSuccess, 'selectFallback must succeed.');
  _expect(selResult.value!.latestSelectionCandidateId != null,
      'latestSelectionCandidateId must not be null after selectFallback.');

  // 4. disable succeeds
  final FallbackAdapterRuntimeActionResult<FallbackAdapterRuntimeProjection>
      disResult = await runtime.disable('adapter-1');
  _expect(disResult.isSuccess, 'disable must succeed.');
  _expect(
      disResult.value!.strategyState ==
          StoredFallbackStrategyStateKind.disabled,
      'strategyState must be disabled after disable.');

  // 5. Unsupported scope returns capabilityUnsupported
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
          PlaybackCapabilityMatrix.unsupported(reason: 'Unsupported.'),
    },
  ).createRuntime();
  final FallbackAdapterRuntimeActionResult<FallbackAdapterRuntimeProjection>
      unsupportedResult =
      await unsupportedRuntime.snapshot('adapter-unsupported');
  _expect(!unsupportedResult.isSuccess, 'Unsupported snapshot must fail.');
  _expect(
      unsupportedResult.failure?.kind ==
          FallbackAdapterRuntimeFailureKind.capabilityUnsupported,
      'Unsupported must be capabilityUnsupported.');

  // 6. Unavailable runtime rejects all operations
  final FallbackAdapterRuntime unavailable =
      FallbackAdapterRuntime.unavailable(reason: 'No fallback service.');
  final List<
      Future<
          FallbackAdapterRuntimeActionResult<
              FallbackAdapterRuntimeProjection>>> unavailableOps = <Future<
      FallbackAdapterRuntimeActionResult<FallbackAdapterRuntimeProjection>>>[
    unavailable.snapshot('any'),
    unavailable.registerCandidate('any',
        _candidate(id: 'unavail', capabilities: _fallbackCapabilities())),
    unavailable.deregisterCandidate('any', const FallbackAdapterId('x')),
    unavailable.selectFallback(
      scopeId: 'any',
      source: LocalFilePlaybackSource(uri: Uri.file('D:/media/u.mkv')),
      failure: const FallbackFailure(
          kind: FallbackFailureKind.loadFailure, message: 'f'),
    ),
    unavailable.disable('any'),
    unavailable.reevaluateCapabilities(
        scopeId: 'any', candidateId: const FallbackAdapterId('x')),
  ];
  for (final Future<
      FallbackAdapterRuntimeActionResult<
          FallbackAdapterRuntimeProjection>> op in unavailableOps) {
    final FallbackAdapterRuntimeActionResult<FallbackAdapterRuntimeProjection>
        r = await op;
    _expect(!r.isSuccess, 'Unavailable operation must fail.');
    _expect(r.failure?.kind == FallbackAdapterRuntimeFailureKind.unavailable,
        'Unavailable must be unavailable kind.');
  }

  // 7. Disposed runtime rejects snapshot
  final DeterministicFallbackAdapterStore disposeStore =
      DeterministicFallbackAdapterStore();
  final DeterministicPlaybackFallbackStrategy disposeStrategy =
      DeterministicPlaybackFallbackStrategy(
    store: disposeStore,
    scopeId: 'adapter-dispose',
  );
  final FallbackAdapterRuntime disposeRuntime = FallbackAdapterBootstrap(
    store: disposeStore,
    strategyByScope: <String, DeterministicPlaybackFallbackStrategy>{
      'adapter-dispose': disposeStrategy,
    },
    capabilitiesByScope: <String, PlaybackCapabilityMatrix>{
      'adapter-dispose': _supportedCapabilities(),
    },
  ).createRuntime();
  await disposeRuntime.dispose();
  final FallbackAdapterRuntimeActionResult<FallbackAdapterRuntimeProjection>
      disposedResult = await disposeRuntime.snapshot('adapter-dispose');
  _expect(!disposedResult.isSuccess, 'Disposed snapshot must fail.');
  _expect(
      disposedResult.failure?.kind ==
          FallbackAdapterRuntimeFailureKind.disposed,
      'Disposed must be disposed kind.');

  // 8. Domain failure kinds map from contract failures (noCandidate)
  final DeterministicPlaybackFallbackStrategy noCandStrategy =
      DeterministicPlaybackFallbackStrategy(
    store: DeterministicFallbackAdapterStore(),
    scopeId: 'adapter-nocand',
  );
  final FallbackAdapterRuntime noCandRuntime = FallbackAdapterBootstrap(
    store: noCandStrategy.store,
    strategyByScope: <String, DeterministicPlaybackFallbackStrategy>{
      'adapter-nocand': noCandStrategy,
    },
    capabilitiesByScope: <String, PlaybackCapabilityMatrix>{
      'adapter-nocand': _supportedCapabilities(),
    },
  ).createRuntime();
  final FallbackAdapterRuntimeActionResult<FallbackAdapterRuntimeProjection>
      noCandResult = await noCandRuntime.selectFallback(
    scopeId: 'adapter-nocand',
    source: LocalFilePlaybackSource(uri: Uri.file('D:/media/nocand.mkv')),
    failure: const FallbackFailure(
        kind: FallbackFailureKind.loadFailure, message: 'failed'),
  );
  _expect(!noCandResult.isSuccess, 'noCandidate selectFallback must fail.');
  _expect(
      noCandResult.failure?.kind ==
          FallbackAdapterRuntimeFailureKind.noCandidate,
      'Must be noCandidate kind.');

  stdout.writeln('All fallback adapter runtime contract checks passed.');
}

DateTime _now() => DateTime.utc(2026, 6, 15, 12);

FallbackAdapterCandidate _candidate({
  required String id,
  required PlaybackCapabilityMatrix capabilities,
}) {
  return FallbackAdapterCandidate(
    id: FallbackAdapterId(id),
    adapter: _TestFallbackAdapter(id: id, capabilities: capabilities),
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

final class _TestFallbackAdapter implements PlayerAdapter {
  const _TestFallbackAdapter({required this.id, required this.capabilities});

  @override
  final String id;

  @override
  String get displayName => 'Test Fallback Adapter';

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
