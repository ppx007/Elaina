import '../foundation/storage/fallback_adapter_storage_contracts.dart';
import 'capability_matrix.dart';
import 'fallback_adapter.dart';
import 'player_adapter.dart';

final class FallbackAdapterBootstrap {
  FallbackAdapterBootstrap({
    required this.store,
    required Map<String, DeterministicPlaybackFallbackStrategy> strategyByScope,
    required Map<String, PlaybackCapabilityMatrix> capabilitiesByScope,
  })  : _strategyByScope = Map<String, DeterministicPlaybackFallbackStrategy>.unmodifiable(strategyByScope),
        _capabilitiesByScope = Map<String, PlaybackCapabilityMatrix>.unmodifiable(capabilitiesByScope);

  final FallbackAdapterStore store;
  final Map<String, DeterministicPlaybackFallbackStrategy> _strategyByScope;
  final Map<String, PlaybackCapabilityMatrix> _capabilitiesByScope;

  FallbackAdapterRuntime createRuntime() {
    return FallbackAdapterRuntime._(
      store: store,
      strategyByScope: _strategyByScope,
      capabilitiesByScope: _capabilitiesByScope,
    );
  }
}

enum FallbackAdapterRuntimeFailureKind {
  capabilityUnsupported,
  unavailable,
  disposed,
  duplicateCandidate,
  candidateNotFound,
  incompatibleFailure,
  noCandidate,
  persistenceRejected,
  sourceUnsupported,
  disabled,
  selectionRejected,
}

final class FallbackAdapterRuntimeFailure implements Exception {
  const FallbackAdapterRuntimeFailure({
    required this.kind,
    required this.message,
  });

  final FallbackAdapterRuntimeFailureKind kind;
  final String message;
}

enum FallbackAdapterRuntimeActionResultKind {
  success,
  failed,
  unavailable,
  disposed,
}

final class FallbackAdapterRuntimeActionResult<T> {
  const FallbackAdapterRuntimeActionResult.success(this.value)
      : failure = null,
        kind = FallbackAdapterRuntimeActionResultKind.success;

  const FallbackAdapterRuntimeActionResult.failed(this.failure)
      : value = null,
        kind = FallbackAdapterRuntimeActionResultKind.failed;

  const FallbackAdapterRuntimeActionResult.unavailable(this.failure)
      : value = null,
        kind = FallbackAdapterRuntimeActionResultKind.unavailable;

  const FallbackAdapterRuntimeActionResult.disposed(this.failure)
      : value = null,
        kind = FallbackAdapterRuntimeActionResultKind.disposed;

  final T? value;
  final FallbackAdapterRuntimeFailure? failure;
  final FallbackAdapterRuntimeActionResultKind kind;

  bool get isSuccess => kind == FallbackAdapterRuntimeActionResultKind.success;
}

final class FallbackAdapterRuntimeRestartProjection {
  FallbackAdapterRuntimeRestartProjection({
    required this.scopeId,
    this.enabled,
    this.selectedCandidateId,
    this.strategyState,
  });

  final String scopeId;
  final bool? enabled;
  final String? selectedCandidateId;
  final StoredFallbackStrategyStateKind? strategyState;
}

final class FallbackAdapterRuntimeProjection {
  FallbackAdapterRuntimeProjection._({
    required this.scopeId,
    this.enabled,
    this.strategyState,
    this.selectedCandidateId,
    this.latestRegistrationOutcome,
    this.latestSelectionCandidateId,
    this.latestCapabilityReadModel,
    this.latestFailure,
    required this.restart,
  });

  final String scopeId;
  final bool? enabled;
  final StoredFallbackStrategyStateKind? strategyState;
  final String? selectedCandidateId;
  final FallbackRegistrationOutcome? latestRegistrationOutcome;
  final String? latestSelectionCandidateId;
  final FallbackCapabilityReadModel? latestCapabilityReadModel;
  final FallbackAdapterRuntimeFailure? latestFailure;
  final FallbackAdapterRuntimeRestartProjection restart;
}

final class FallbackAdapterRuntime {
  FallbackAdapterRuntime._({
    required FallbackAdapterStore store,
    required Map<String, DeterministicPlaybackFallbackStrategy> strategyByScope,
    required Map<String, PlaybackCapabilityMatrix> capabilitiesByScope,
  })  : _store = store,
        _strategyByScope = strategyByScope,
        _capabilitiesByScope = capabilitiesByScope,
        _unavailableReason = null;

  FallbackAdapterRuntime.unavailable({required String reason})
      : _store = DeterministicFallbackAdapterStore(),
        _strategyByScope = const <String, DeterministicPlaybackFallbackStrategy>{},
        _capabilitiesByScope = const <String, PlaybackCapabilityMatrix>{},
        _unavailableReason = reason;

  final FallbackAdapterStore _store;
  final Map<String, DeterministicPlaybackFallbackStrategy> _strategyByScope;
  final Map<String, PlaybackCapabilityMatrix> _capabilitiesByScope;
  final String? _unavailableReason;
  bool _disposed = false;
  FallbackRegistrationOutcome? _latestRegistrationOutcome;
  String? _latestSelectionCandidateId;
  FallbackCapabilityReadModel? _latestCapabilityReadModel;
  FallbackAdapterRuntimeFailure? _latestFailure;

  Future<FallbackAdapterRuntimeActionResult<FallbackAdapterRuntimeProjection>>
      snapshot(String scopeId) async {
    final FallbackAdapterRuntimeFailure? gate = _gate(scopeId);
    if (gate != null) {
      return FallbackAdapterRuntimeActionResult<FallbackAdapterRuntimeProjection>.failed(gate);
    }
    final FallbackAdapterRuntimeProjection projection =
        await _buildProjection(scopeId);
    return FallbackAdapterRuntimeActionResult<FallbackAdapterRuntimeProjection>.success(projection);
  }

  Future<FallbackAdapterRuntimeActionResult<FallbackAdapterRuntimeProjection>>
      registerCandidate(String scopeId, FallbackAdapterCandidate candidate) async {
    final FallbackAdapterRuntimeFailure? gate = _gate(scopeId);
    if (gate != null) {
      return FallbackAdapterRuntimeActionResult<FallbackAdapterRuntimeProjection>.failed(gate);
    }
    final DeterministicPlaybackFallbackStrategy strategy =
        _strategyByScope[scopeId]!;
    final FallbackRegistrationOutcome outcome =
        await strategy.register(candidate);
    _latestRegistrationOutcome = outcome;
    if (!outcome.isSuccess) {
      _latestFailure = FallbackAdapterRuntimeFailure(
        kind: _mapRegistrationFailureKind(outcome.failure!.kind),
        message: outcome.failure!.message,
      );
      return FallbackAdapterRuntimeActionResult<FallbackAdapterRuntimeProjection>.failed(_latestFailure!);
    }
    final FallbackAdapterRuntimeProjection projection =
        await _buildProjection(scopeId);
    return FallbackAdapterRuntimeActionResult<FallbackAdapterRuntimeProjection>.success(projection);
  }

  Future<FallbackAdapterRuntimeActionResult<FallbackAdapterRuntimeProjection>>
      deregisterCandidate(String scopeId, FallbackAdapterId candidateId) async {
    final FallbackAdapterRuntimeFailure? gate = _gate(scopeId);
    if (gate != null) {
      return FallbackAdapterRuntimeActionResult<FallbackAdapterRuntimeProjection>.failed(gate);
    }
    final DeterministicPlaybackFallbackStrategy strategy =
        _strategyByScope[scopeId]!;
    final bool removed = await strategy.deregister(candidateId);
    if (!removed) {
      _latestFailure = const FallbackAdapterRuntimeFailure(
        kind: FallbackAdapterRuntimeFailureKind.candidateNotFound,
        message: 'Fallback adapter candidate not found for deregistration.',
      );
      return FallbackAdapterRuntimeActionResult<FallbackAdapterRuntimeProjection>.failed(_latestFailure!);
    }
    final FallbackAdapterRuntimeProjection projection =
        await _buildProjection(scopeId);
    return FallbackAdapterRuntimeActionResult<FallbackAdapterRuntimeProjection>.success(projection);
  }

  Future<FallbackAdapterRuntimeActionResult<FallbackAdapterRuntimeProjection>>
      selectFallback({
    required String scopeId,
    required PlaybackSource source,
    required FallbackFailure failure,
  }) async {
    final FallbackAdapterRuntimeFailure? gate = _gate(scopeId);
    if (gate != null) {
      return FallbackAdapterRuntimeActionResult<FallbackAdapterRuntimeProjection>.failed(gate);
    }
    final DeterministicPlaybackFallbackStrategy strategy =
        _strategyByScope[scopeId]!;
    final FallbackEvaluationOutcome outcome =
        await strategy.selectFallback(source: source, failure: failure);
    if (!outcome.isSuccess) {
      _latestFailure = FallbackAdapterRuntimeFailure(
        kind: _mapEvaluationFailureKind(outcome.failure!.kind),
        message: outcome.failure!.message,
      );
      return FallbackAdapterRuntimeActionResult<FallbackAdapterRuntimeProjection>.failed(_latestFailure!);
    }
    _latestSelectionCandidateId = outcome.selection!.candidate.id.value;
    final FallbackAdapterRuntimeProjection projection =
        await _buildProjection(scopeId);
    return FallbackAdapterRuntimeActionResult<FallbackAdapterRuntimeProjection>.success(projection);
  }

  Future<FallbackAdapterRuntimeActionResult<FallbackAdapterRuntimeProjection>>
      disable(String scopeId) async {
    final FallbackAdapterRuntimeFailure? gate = _gate(scopeId);
    if (gate != null) {
      return FallbackAdapterRuntimeActionResult<FallbackAdapterRuntimeProjection>.failed(gate);
    }
    final DeterministicPlaybackFallbackStrategy strategy =
        _strategyByScope[scopeId]!;
    final FallbackDisableOutcome outcome = await strategy.disable();
    if (!outcome.isSuccess) {
      _latestFailure = FallbackAdapterRuntimeFailure(
        kind: _mapDisableFailureKind(outcome.failure!.kind),
        message: outcome.failure!.message,
      );
      return FallbackAdapterRuntimeActionResult<FallbackAdapterRuntimeProjection>.failed(_latestFailure!);
    }
    final FallbackAdapterRuntimeProjection projection =
        await _buildProjection(scopeId);
    return FallbackAdapterRuntimeActionResult<FallbackAdapterRuntimeProjection>.success(projection);
  }

  Future<FallbackAdapterRuntimeActionResult<FallbackAdapterRuntimeProjection>>
      reevaluateCapabilities({
    required String scopeId,
    required FallbackAdapterId candidateId,
  }) async {
    final FallbackAdapterRuntimeFailure? gate = _gate(scopeId);
    if (gate != null) {
      return FallbackAdapterRuntimeActionResult<FallbackAdapterRuntimeProjection>.failed(gate);
    }
    final DeterministicPlaybackFallbackStrategy strategy =
        _strategyByScope[scopeId]!;
    final FallbackCapabilityReevaluationOutcome outcome =
        await strategy.reevaluateCapabilities(candidateId);
    if (!outcome.isSuccess) {
      _latestFailure = FallbackAdapterRuntimeFailure(
        kind: _mapCapabilityFailureKind(outcome.failure!.kind),
        message: outcome.failure!.message,
      );
      return FallbackAdapterRuntimeActionResult<FallbackAdapterRuntimeProjection>.failed(_latestFailure!);
    }
    _latestCapabilityReadModel = outcome.readModel;
    final FallbackAdapterRuntimeProjection projection =
        await _buildProjection(scopeId);
    return FallbackAdapterRuntimeActionResult<FallbackAdapterRuntimeProjection>.success(projection);
  }

  Future<void> dispose() async {
    _disposed = true;
  }

  FallbackAdapterRuntimeFailure? _gate(String scopeId) {
    if (_disposed) {
      return const FallbackAdapterRuntimeFailure(
        kind: FallbackAdapterRuntimeFailureKind.disposed,
        message: 'FallbackAdapterRuntime is disposed.',
      );
    }
    if (_unavailableReason != null) {
      return FallbackAdapterRuntimeFailure(
        kind: FallbackAdapterRuntimeFailureKind.unavailable,
        message: _unavailableReason,
      );
    }
    if (!_strategyByScope.containsKey(scopeId)) {
      return FallbackAdapterRuntimeFailure(
        kind: FallbackAdapterRuntimeFailureKind.capabilityUnsupported,
        message: 'No fallback strategy for scope $scopeId.',
      );
    }
    final PlaybackCapabilityMatrix? capabilities =
        _capabilitiesByScope[scopeId];
    if (capabilities == null ||
        !capabilities.statusOf(PlaybackCapability.fallbackAdapter).isSupported) {
      return FallbackAdapterRuntimeFailure(
        kind: FallbackAdapterRuntimeFailureKind.capabilityUnsupported,
        message: 'Fallback adapter capability unsupported for scope $scopeId.',
      );
    }
    return null;
  }

  Future<FallbackAdapterRuntimeProjection> _buildProjection(
      String scopeId) async {
    final StoredActiveFallbackConfigurationRecord? active =
        await _store.activeConfiguration(scopeId);
    final StoredFallbackStrategyStateRecord? state =
        await _store.latestStrategyState(scopeId);
    final FallbackAdapterRuntimeRestartProjection restart =
        FallbackAdapterRuntimeRestartProjection(
      scopeId: scopeId,
      enabled: active?.enabled,
      selectedCandidateId: active?.selectedCandidateId,
      strategyState: state?.state,
    );
    return FallbackAdapterRuntimeProjection._(
      scopeId: scopeId,
      enabled: active?.enabled,
      strategyState: state?.state,
      selectedCandidateId: active?.selectedCandidateId,
      latestRegistrationOutcome: _latestRegistrationOutcome,
      latestSelectionCandidateId: _latestSelectionCandidateId,
      latestCapabilityReadModel: _latestCapabilityReadModel,
      latestFailure: _latestFailure,
      restart: restart,
    );
  }

  FallbackAdapterRuntimeFailureKind _mapRegistrationFailureKind(
      FallbackRegistrationFailureKind kind) {
    return switch (kind) {
      FallbackRegistrationFailureKind.duplicateCandidate =>
        FallbackAdapterRuntimeFailureKind.duplicateCandidate,
      FallbackRegistrationFailureKind.capabilityUnsupported =>
        FallbackAdapterRuntimeFailureKind.capabilityUnsupported,
    };
  }

  FallbackAdapterRuntimeFailureKind _mapEvaluationFailureKind(
      FallbackEvaluationFailureKind kind) {
    return switch (kind) {
      FallbackEvaluationFailureKind.disabled =>
        FallbackAdapterRuntimeFailureKind.disabled,
      FallbackEvaluationFailureKind.incompatibleFailure =>
        FallbackAdapterRuntimeFailureKind.incompatibleFailure,
      FallbackEvaluationFailureKind.sourceUnsupported =>
        FallbackAdapterRuntimeFailureKind.sourceUnsupported,
      FallbackEvaluationFailureKind.noCandidate =>
        FallbackAdapterRuntimeFailureKind.noCandidate,
    };
  }

  FallbackAdapterRuntimeFailureKind _mapDisableFailureKind(
      FallbackDisableFailureKind kind) {
    return switch (kind) {
      FallbackDisableFailureKind.persistenceRejected =>
        FallbackAdapterRuntimeFailureKind.persistenceRejected,
    };
  }

  FallbackAdapterRuntimeFailureKind _mapCapabilityFailureKind(
      FallbackCapabilityFailureKind kind) {
    return switch (kind) {
      FallbackCapabilityFailureKind.candidateNotFound =>
        FallbackAdapterRuntimeFailureKind.candidateNotFound,
    };
  }
}
