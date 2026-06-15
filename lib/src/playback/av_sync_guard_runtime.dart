import '../foundation/cache_invalidation/cache_invalidation_bus.dart';
import '../foundation/storage/av_sync_guard_storage_contracts.dart';
import 'av_sync_guard.dart';
import 'capability_matrix.dart';

final class AVSyncGuardBootstrap {
  AVSyncGuardBootstrap({
    required this.guardStore,
    required Map<String, DeterministicAVSyncGuard> guardByScope,
    required Map<String, PlaybackCapabilityMatrix> capabilitiesByScope,
    this.cacheInvalidationBus,
  })  : guardByScope =
            Map<String, DeterministicAVSyncGuard>.unmodifiable(guardByScope),
        capabilitiesByScope =
            Map<String, PlaybackCapabilityMatrix>.unmodifiable(
                capabilitiesByScope);

  final AVSyncGuardStore guardStore;
  final Map<String, DeterministicAVSyncGuard> guardByScope;
  final Map<String, PlaybackCapabilityMatrix> capabilitiesByScope;
  final CacheInvalidationBus? cacheInvalidationBus;

  AVSyncGuardRuntime createRuntime() {
    return AVSyncGuardRuntime(
      guardStore: guardStore,
      guardByScope: guardByScope,
      capabilitiesByScope: capabilitiesByScope,
      cacheInvalidationBus: cacheInvalidationBus,
    );
  }
}

enum AVSyncGuardRuntimeFailureKind {
  capabilityUnsupported,
  unavailable,
  disposed,
  policyNotConfigured,
  insufficientSamples,
}

final class AVSyncGuardRuntimeFailure implements Exception {
  const AVSyncGuardRuntimeFailure({
    required this.kind,
    required this.message,
  });

  final AVSyncGuardRuntimeFailureKind kind;
  final String message;
}

enum AVSyncGuardRuntimeActionResultKind {
  success,
  failed,
  unavailable,
  disposed,
}

final class AVSyncGuardRuntimeActionResult<T> {
  const AVSyncGuardRuntimeActionResult._({
    required this.kind,
    this.value,
    this.failure,
  });

  const AVSyncGuardRuntimeActionResult.success(T value)
      : this._(
          kind: AVSyncGuardRuntimeActionResultKind.success,
          value: value,
        );

  const AVSyncGuardRuntimeActionResult.failed(
    AVSyncGuardRuntimeFailure failure,
  ) : this._(
          kind: AVSyncGuardRuntimeActionResultKind.failed,
          failure: failure,
        );

  const AVSyncGuardRuntimeActionResult.unavailable(
    AVSyncGuardRuntimeFailure failure,
  ) : this._(
          kind: AVSyncGuardRuntimeActionResultKind.unavailable,
          failure: failure,
        );

  const AVSyncGuardRuntimeActionResult.disposed(
    AVSyncGuardRuntimeFailure failure,
  ) : this._(
          kind: AVSyncGuardRuntimeActionResultKind.disposed,
          failure: failure,
        );

  final AVSyncGuardRuntimeActionResultKind kind;
  final T? value;
  final AVSyncGuardRuntimeFailure? failure;

  bool get isSuccess =>
      kind == AVSyncGuardRuntimeActionResultKind.success;
}

final class AVSyncGuardRuntimeRestartProjection {
  const AVSyncGuardRuntimeRestartProjection({
    required this.scopeId,
    this.health,
    this.latestDegradationAction,
  });

  final String scopeId;
  final StoredAVSyncHealthKind? health;
  final String? latestDegradationAction;
}

final class AVSyncGuardRuntimeProjection {
  const AVSyncGuardRuntimeProjection({
    required this.scopeId,
    required this.restart,
    this.health,
    this.latestDriftMillis,
    this.latestDegradationAction,
    this.sampleCount,
    this.latestDecision,
    this.latestFailure,
  });

  final String scopeId;
  final AVSyncHealth? health;
  final int? latestDriftMillis;
  final String? latestDegradationAction;
  final int? sampleCount;
  final AVSyncDecision? latestDecision;
  final AVSyncGuardRuntimeFailure? latestFailure;
  final AVSyncGuardRuntimeRestartProjection restart;
}

final class AVSyncGuardRuntime {
  AVSyncGuardRuntime({
    required AVSyncGuardStore guardStore,
    required Map<String, DeterministicAVSyncGuard> guardByScope,
    required Map<String, PlaybackCapabilityMatrix> capabilitiesByScope,
    CacheInvalidationBus? cacheInvalidationBus,
  })  : _guardStore = guardStore,
        _guardByScope =
            Map<String, DeterministicAVSyncGuard>.unmodifiable(guardByScope),
        _capabilitiesByScope =
            Map<String, PlaybackCapabilityMatrix>.unmodifiable(
                capabilitiesByScope),
        _unavailableReason = null;

  AVSyncGuardRuntime.unavailable({required String reason})
      : _guardStore = DeterministicAVSyncGuardStore(),
        _guardByScope = const <String, DeterministicAVSyncGuard>{},
        _capabilitiesByScope = const <String, PlaybackCapabilityMatrix>{},
        _unavailableReason = reason;

  final AVSyncGuardStore _guardStore;
  final Map<String, DeterministicAVSyncGuard> _guardByScope;
  final Map<String, PlaybackCapabilityMatrix> _capabilitiesByScope;
  final String? _unavailableReason;
  final Map<String, AVSyncDecision> _latestDecisionsByScope =
      <String, AVSyncDecision>{};
  final Map<String, AVSyncGuardRuntimeFailure> _latestFailuresByScope =
      <String, AVSyncGuardRuntimeFailure>{};
  bool _disposed = false;

  Future<AVSyncGuardRuntimeActionResult<AVSyncGuardRuntimeProjection>>
      snapshot(String scopeId) async {
    final AVSyncGuardRuntimeActionResult<AVSyncGuardRuntimeProjection>? gated =
        _gate(scopeId);
    if (gated != null) return gated;
    return AVSyncGuardRuntimeActionResult<AVSyncGuardRuntimeProjection>.success(
      await _projection(scopeId),
    );
  }

  Future<AVSyncGuardRuntimeActionResult<AVSyncGuardRuntimeProjection>>
      ingestSample(String scopeId, AVSyncSample sample) async {
    final AVSyncGuardRuntimeActionResult<AVSyncGuardRuntimeProjection>? gated =
        _gate(scopeId);
    if (gated != null) return gated;

    final DeterministicAVSyncGuard guard = _guardByScope[scopeId]!;
    final AVSyncEvaluationOutcome outcome =
        await guard.ingestSample(sample);
    if (!outcome.isSuccess) {
      return _failed(scopeId, _failureFromGuard(outcome.failure!));
    }
    _latestDecisionsByScope[scopeId] = outcome.decision!;
    _latestFailuresByScope.remove(scopeId);
    return AVSyncGuardRuntimeActionResult<AVSyncGuardRuntimeProjection>.success(
      await _projection(scopeId),
    );
  }

  Future<AVSyncGuardRuntimeActionResult<AVSyncGuardRuntimeProjection>>
      requestDegradation(String scopeId, AVSyncSample sample) async {
    final AVSyncGuardRuntimeActionResult<AVSyncGuardRuntimeProjection>? gated =
        _gate(scopeId);
    if (gated != null) return gated;

    final DeterministicAVSyncGuard guard = _guardByScope[scopeId]!;
    final AVSyncDegradationRequestOutcome outcome =
        await guard.requestDegradation(sample);
    if (!outcome.isSuccess) {
      return _failed(scopeId, _failureFromGuard(outcome.failure!));
    }
    _latestDecisionsByScope[scopeId] = outcome.decision!;
    _latestFailuresByScope.remove(scopeId);
    return AVSyncGuardRuntimeActionResult<AVSyncGuardRuntimeProjection>.success(
      await _projection(scopeId),
    );
  }

  Future<AVSyncGuardRuntimeActionResult<AVSyncGuardRuntimeProjection>>
      checkRecovery(String scopeId) async {
    final AVSyncGuardRuntimeActionResult<AVSyncGuardRuntimeProjection>? gated =
        _gate(scopeId);
    if (gated != null) return gated;

    final DeterministicAVSyncGuard guard = _guardByScope[scopeId]!;
    final AVSyncRecoveryOutcome outcome = await guard.checkRecovery();
    if (!outcome.isSuccess) {
      return _failed(scopeId, _failureFromGuard(outcome.failure!));
    }
    _latestDecisionsByScope[scopeId] = outcome.decision!;
    _latestFailuresByScope.remove(scopeId);
    return AVSyncGuardRuntimeActionResult<AVSyncGuardRuntimeProjection>.success(
      await _projection(scopeId),
    );
  }

  Future<void> dispose() async {
    _disposed = true;
  }

  AVSyncGuardRuntimeActionResult<AVSyncGuardRuntimeProjection>? _gate(
      String scopeId) {
    if (_disposed) {
      return AVSyncGuardRuntimeActionResult<AVSyncGuardRuntimeProjection>
          .disposed(
        const AVSyncGuardRuntimeFailure(
          kind: AVSyncGuardRuntimeFailureKind.disposed,
          message: 'AV sync guard runtime is disposed.',
        ),
      );
    }
    if (_unavailableReason != null) {
      return AVSyncGuardRuntimeActionResult<AVSyncGuardRuntimeProjection>
          .unavailable(
        AVSyncGuardRuntimeFailure(
          kind: AVSyncGuardRuntimeFailureKind.unavailable,
          message: _unavailableReason,
        ),
      );
    }
    if (!_guardByScope.containsKey(scopeId) ||
        !_capabilitiesByScope.containsKey(scopeId)) {
      return AVSyncGuardRuntimeActionResult<AVSyncGuardRuntimeProjection>
          .unavailable(
        AVSyncGuardRuntimeFailure(
          kind: AVSyncGuardRuntimeFailureKind.unavailable,
          message: 'AV sync guard runtime is unavailable for $scopeId.',
        ),
      );
    }
    if (!_capabilitiesByScope[scopeId]!
        .supports(PlaybackCapability.avSyncGuard)) {
      return AVSyncGuardRuntimeActionResult<AVSyncGuardRuntimeProjection>
          .failed(
        const AVSyncGuardRuntimeFailure(
          kind: AVSyncGuardRuntimeFailureKind.capabilityUnsupported,
          message: 'AVSyncGuard capability is unsupported for this scope.',
        ),
      );
    }
    return null;
  }

  Future<AVSyncGuardRuntimeActionResult<AVSyncGuardRuntimeProjection>> _failed(
    String scopeId,
    AVSyncGuardRuntimeFailure failure,
  ) async {
    _latestFailuresByScope[scopeId] = failure;
    return AVSyncGuardRuntimeActionResult<AVSyncGuardRuntimeProjection>.failed(
        failure);
  }

  AVSyncGuardRuntimeFailure _failureFromGuard(AVSyncGuardFailure failure) {
    return AVSyncGuardRuntimeFailure(
      kind: switch (failure.kind) {
        AVSyncGuardFailureKind.capabilityUnsupported =>
          AVSyncGuardRuntimeFailureKind.capabilityUnsupported,
        AVSyncGuardFailureKind.insufficientSamples =>
          AVSyncGuardRuntimeFailureKind.insufficientSamples,
        AVSyncGuardFailureKind.policyNotConfigured =>
          AVSyncGuardRuntimeFailureKind.policyNotConfigured,
      },
      message: failure.message,
    );
  }

  Future<AVSyncGuardRuntimeProjection> _projection(String scopeId) async {
    final StoredAVSyncHealthRecord? storedHealth =
        await _guardStore.latestHealth(scopeId);
    final List<StoredAVSyncDegradationDecisionRecord> storedDecisions =
        await _guardStore.degradationHistory(scopeId, limit: 1);
    final String? latestDegradationAction =
        storedDecisions.isNotEmpty ? storedDecisions.first.action : null;

    final AVSyncDecision? latestDecision =
        _latestDecisionsByScope[scopeId];
    final AVSyncHealth? health = latestDecision?.health ??
        _healthFromStored(storedHealth?.health);

    return AVSyncGuardRuntimeProjection(
      scopeId: scopeId,
      health: health,
      latestDriftMillis: storedHealth?.lastDriftMillis,
      latestDegradationAction: latestDecision?.action.name ??
          latestDegradationAction,
      sampleCount: storedHealth?.sampleCount,
      latestDecision: latestDecision,
      latestFailure: _latestFailuresByScope[scopeId],
      restart: AVSyncGuardRuntimeRestartProjection(
        scopeId: scopeId,
        health: storedHealth?.health,
        latestDegradationAction: latestDegradationAction,
      ),
    );
  }

  AVSyncHealth? _healthFromStored(StoredAVSyncHealthKind? kind) {
    if (kind == null) return null;
    return switch (kind) {
      StoredAVSyncHealthKind.target => AVSyncHealth.target,
      StoredAVSyncHealthKind.warning => AVSyncHealth.warning,
      StoredAVSyncHealthKind.degraded => AVSyncHealth.degraded,
    };
  }
}
