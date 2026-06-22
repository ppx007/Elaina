import '../foundation/cache_invalidation/cache_invalidation_bus.dart';
import '../foundation/storage/fallback_adapter_storage_contracts.dart';
import 'capability_matrix.dart';
import 'player_adapter.dart';

/// Identifies a playback adapter that can be selected after primary failure.
///
/// The id is persisted in fallback state, so it must remain stable across app
/// restarts instead of being derived from object identity.
final class FallbackAdapterId {
  const FallbackAdapterId(this.value)
      : assert(value != '', 'Fallback adapter id must not be empty.');

  final String value;
}

enum FallbackFailureKind {
  loadFailure,
  unsupportedCodec,
  unsupportedContainer,
  adapterCrashed,
  incompatibleFailure,
}

final class FallbackFailure {
  const FallbackFailure({required this.kind, required this.message});

  final FallbackFailureKind kind;
  final String message;
}

final class FallbackAdapterCandidate {
  const FallbackAdapterCandidate({
    required this.id,
    required this.adapter,
    required this.capabilities,
    this.priority = 0,
  }) : assert(
            priority >= 0, 'Fallback candidate priority must not be negative.');

  final FallbackAdapterId id;
  final PlayerAdapter adapter;
  final PlaybackCapabilityMatrix capabilities;
  final int priority;
}

final class FallbackSelection {
  FallbackSelection({
    required this.candidate,
    required Map<PlaybackCapability, CapabilityStatus> hiddenCapabilities,
    required this.reason,
  }) : hiddenCapabilities =
            Map<PlaybackCapability, CapabilityStatus>.unmodifiable(
                hiddenCapabilities);

  final FallbackAdapterCandidate candidate;
  final Map<PlaybackCapability, CapabilityStatus> hiddenCapabilities;
  final String reason;
}

final class FallbackCapabilityReadModel {
  FallbackCapabilityReadModel({
    required this.adapterId,
    required Map<PlaybackCapability, CapabilityStatus> hiddenCapabilities,
  }) : hiddenCapabilities =
            Map<PlaybackCapability, CapabilityStatus>.unmodifiable(
                hiddenCapabilities);

  final FallbackAdapterId adapterId;
  final Map<PlaybackCapability, CapabilityStatus> hiddenCapabilities;

  bool get hidesAnyCapability => hiddenCapabilities.isNotEmpty;

  List<String> hiddenCapabilityReasons() {
    return <String>[
      for (final CapabilityStatus status in hiddenCapabilities.values)
        status.reason ?? 'Fallback capability is unsupported.',
    ];
  }
}

enum FallbackRegistrationFailureKind {
  duplicateCandidate,
  capabilityUnsupported,
}

enum FallbackEvaluationFailureKind {
  disabled,
  incompatibleFailure,
  sourceUnsupported,
  noCandidate,
}

enum FallbackDisableFailureKind {
  persistenceRejected,
}

enum FallbackCapabilityFailureKind {
  candidateNotFound,
}

final class FallbackRegistrationFailure implements Exception {
  const FallbackRegistrationFailure(
      {required this.kind, required this.message});

  final FallbackRegistrationFailureKind kind;
  final String message;
}

final class FallbackEvaluationFailure implements Exception {
  const FallbackEvaluationFailure({required this.kind, required this.message});

  final FallbackEvaluationFailureKind kind;
  final String message;
}

final class FallbackDisableFailure implements Exception {
  const FallbackDisableFailure({required this.kind, required this.message});

  final FallbackDisableFailureKind kind;
  final String message;
}

final class FallbackCapabilityFailure implements Exception {
  const FallbackCapabilityFailure({required this.kind, required this.message});

  final FallbackCapabilityFailureKind kind;
  final String message;
}

final class FallbackRegistrationOutcome {
  const FallbackRegistrationOutcome._({this.candidate, this.failure});

  const FallbackRegistrationOutcome.registered(
      {required FallbackAdapterCandidate candidate})
      : this._(candidate: candidate);

  const FallbackRegistrationOutcome.rejected(
      {required FallbackRegistrationFailure failure})
      : this._(failure: failure);

  final FallbackAdapterCandidate? candidate;
  final FallbackRegistrationFailure? failure;

  bool get isSuccess => failure == null;
}

final class FallbackEvaluationOutcome {
  const FallbackEvaluationOutcome._({this.selection, this.failure});

  const FallbackEvaluationOutcome.selected(
      {required FallbackSelection selection})
      : this._(selection: selection);

  const FallbackEvaluationOutcome.rejected(
      {required FallbackEvaluationFailure failure})
      : this._(failure: failure);

  final FallbackSelection? selection;
  final FallbackEvaluationFailure? failure;

  bool get isSuccess => failure == null;
}

final class FallbackSelectionOutcome {
  const FallbackSelectionOutcome._({this.selection, this.failure});

  const FallbackSelectionOutcome.selected(
      {required FallbackSelection selection})
      : this._(selection: selection);

  const FallbackSelectionOutcome.rejected(
      {required FallbackEvaluationFailure failure})
      : this._(failure: failure);

  final FallbackSelection? selection;
  final FallbackEvaluationFailure? failure;

  bool get isSuccess => failure == null;
}

final class FallbackDisableOutcome {
  const FallbackDisableOutcome._({this.failure});

  const FallbackDisableOutcome.disabled() : this._();

  const FallbackDisableOutcome.rejected(
      {required FallbackDisableFailure failure})
      : this._(failure: failure);

  final FallbackDisableFailure? failure;

  bool get isSuccess => failure == null;
}

final class FallbackCapabilityReevaluationOutcome {
  const FallbackCapabilityReevaluationOutcome._({this.readModel, this.failure});

  const FallbackCapabilityReevaluationOutcome.evaluated(
      {required FallbackCapabilityReadModel readModel})
      : this._(readModel: readModel);

  const FallbackCapabilityReevaluationOutcome.rejected(
      {required FallbackCapabilityFailure failure})
      : this._(failure: failure);

  final FallbackCapabilityReadModel? readModel;
  final FallbackCapabilityFailure? failure;

  bool get isSuccess => failure == null;
}

abstract interface class PlaybackFallbackStrategy {
  Future<FallbackRegistrationOutcome> register(
      FallbackAdapterCandidate candidate);

  Future<bool> deregister(FallbackAdapterId candidateId);

  Future<FallbackEvaluationOutcome> selectFallback({
    required PlaybackSource source,
    required FallbackFailure failure,
  });

  Future<FallbackDisableOutcome> disable();

  Future<FallbackCapabilityReevaluationOutcome> reevaluateCapabilities(
      FallbackAdapterId candidateId);
}

/// Deterministic fallback strategy for capability-aware adapter selection.
///
/// Fallback is not a silent downgrade: the selected adapter carries hidden
/// capability reasons so UI and diagnostics can show what was sacrificed.
final class DeterministicPlaybackFallbackStrategy
    implements PlaybackFallbackStrategy {
  DeterministicPlaybackFallbackStrategy({
    required this.store,
    this.cacheInvalidationBus,
    this.scopeId = 'default',
    bool enabled = true,
    DateTime Function()? clock,
  })  : _enabled = enabled,
        _clock = clock ?? _defaultClock;

  final FallbackAdapterStore store;
  final CacheInvalidationBus? cacheInvalidationBus;
  final String scopeId;
  final DateTime Function() _clock;
  bool _enabled;
  final Map<String, FallbackAdapterCandidate> _candidates =
      <String, FallbackAdapterCandidate>{};
  StoredFallbackStrategyStateKind _state =
      StoredFallbackStrategyStateKind.disabled;

  @override
  Future<FallbackRegistrationOutcome> register(
      FallbackAdapterCandidate candidate) async {
    if (_candidates.containsKey(candidate.id.value) ||
        await store.findCandidateById(candidate.id.value) != null) {
      return const FallbackRegistrationOutcome.rejected(
        failure: FallbackRegistrationFailure(
          kind: FallbackRegistrationFailureKind.duplicateCandidate,
          message: 'Fallback adapter candidate is already registered.',
        ),
      );
    }
    final CapabilityStatus fallbackSupport =
        candidate.capabilities.statusOf(PlaybackCapability.fallbackAdapter);
    if (!fallbackSupport.isSupported) {
      return FallbackRegistrationOutcome.rejected(
        failure: FallbackRegistrationFailure(
          kind: FallbackRegistrationFailureKind.capabilityUnsupported,
          message: fallbackSupport.reason ??
              'Fallback adapter capability is unsupported.',
        ),
      );
    }
    _candidates[candidate.id.value] = candidate;
    await store.storeCandidate(_storedCandidate(candidate));
    cacheInvalidationBus?.publish(FallbackAdapterRegistrationChanged(
      occurredAt: _clock(),
      adapterId: candidate.id.value,
      changeKind: FallbackAdapterChangeKind.registered,
    ));
    return FallbackRegistrationOutcome.registered(candidate: candidate);
  }

  @override
  Future<bool> deregister(FallbackAdapterId candidateId) async {
    _candidates.remove(candidateId.value);
    final bool removed = await store.removeCandidate(candidateId.value);
    if (removed) {
      cacheInvalidationBus?.publish(FallbackAdapterRegistrationChanged(
        occurredAt: _clock(),
        adapterId: candidateId.value,
        changeKind: FallbackAdapterChangeKind.deregistered,
      ));
    }
    return removed;
  }

  @override
  Future<FallbackEvaluationOutcome> selectFallback({
    required PlaybackSource source,
    required FallbackFailure failure,
  }) async {
    if (!_enabled) {
      return _reject(
        FallbackEvaluationFailureKind.disabled,
        'Fallback selection is disabled.',
      );
    }
    if (!_isFallbackCompatible(failure)) {
      return _reject(
        FallbackEvaluationFailureKind.incompatibleFailure,
        'Primary failure is not compatible with fallback selection.',
      );
    }
    final List<FallbackAdapterCandidate> candidates =
        <FallbackAdapterCandidate>[..._candidates.values]..sort(
            (FallbackAdapterCandidate left, FallbackAdapterCandidate right) =>
                left.priority.compareTo(right.priority));
    for (final FallbackAdapterCandidate candidate in candidates) {
      final PlaybackCommandResult sourceSupport = playbackSourceSupportResult(
        source: source,
        capabilityMatrix: candidate.capabilities,
      );
      if (!sourceSupport.isSuccess) {
        continue;
      }
      final Map<PlaybackCapability, CapabilityStatus> hidden =
          _hiddenCapabilities(candidate.capabilities);
      final FallbackSelection selection = FallbackSelection(
        candidate: candidate,
        hiddenCapabilities: hidden,
        reason: 'Selected fallback adapter after ${failure.kind.name}.',
      );
      final DateTime now = _clock();
      await store
          .setActiveConfiguration(StoredActiveFallbackConfigurationRecord(
        scopeId: scopeId,
        enabled: true,
        selectedCandidateId: candidate.id.value,
        selectedAt: now,
        updatedAt: now,
      ));
      await store.recordSelection(StoredFallbackSelectionHistoryRecord(
        id: '$scopeId::${candidate.id.value}::${now.toIso8601String()}',
        scopeId: scopeId,
        candidateId: candidate.id.value,
        sourceKind: source.runtimeType.toString(),
        failureKind: failure.kind.name,
        reason: selection.reason,
        hiddenCapabilities: <String, String>{
          for (final MapEntry<PlaybackCapability, CapabilityStatus> entry
              in hidden.entries)
            entry.key.name: entry.value.reason ?? 'Capability unsupported.',
        },
        selectedAt: now,
      ));
      await _recordState(
        newState: StoredFallbackStrategyStateKind.selected,
        selectedCandidateId: candidate.id.value,
      );
      cacheInvalidationBus?.publish(FallbackSelectionChanged(
        occurredAt: now,
        scopeId: scopeId,
        adapterId: candidate.id.value,
        reason: selection.reason,
      ));
      return FallbackEvaluationOutcome.selected(selection: selection);
    }
    return _reject(
      FallbackEvaluationFailureKind.noCandidate,
      'No fallback adapter candidate supports the playback source.',
    );
  }

  @override
  Future<FallbackDisableOutcome> disable() async {
    _enabled = false;
    final DateTime now = _clock();
    await store.setActiveConfiguration(StoredActiveFallbackConfigurationRecord(
      scopeId: scopeId,
      enabled: false,
      updatedAt: now,
    ));
    await _recordState(newState: StoredFallbackStrategyStateKind.disabled);
    cacheInvalidationBus?.publish(FallbackDisabled(
      occurredAt: now,
      scopeId: scopeId,
    ));
    return const FallbackDisableOutcome.disabled();
  }

  @override
  Future<FallbackCapabilityReevaluationOutcome> reevaluateCapabilities(
      FallbackAdapterId candidateId) async {
    final FallbackAdapterCandidate? candidate = _candidates[candidateId.value];
    if (candidate == null) {
      return const FallbackCapabilityReevaluationOutcome.rejected(
        failure: FallbackCapabilityFailure(
          kind: FallbackCapabilityFailureKind.candidateNotFound,
          message: 'Fallback adapter candidate is not registered.',
        ),
      );
    }
    final FallbackCapabilityReadModel readModel = FallbackCapabilityReadModel(
      adapterId: candidateId,
      hiddenCapabilities: _hiddenCapabilities(candidate.capabilities),
    );
    cacheInvalidationBus?.publish(FallbackCapabilityReevaluated(
      occurredAt: _clock(),
      adapterId: candidateId.value,
      supported: !readModel.hidesAnyCapability,
      reason: readModel.hiddenCapabilityReasons().join(' '),
    ));
    return FallbackCapabilityReevaluationOutcome.evaluated(
        readModel: readModel);
  }

  Future<FallbackEvaluationOutcome> _reject(
      FallbackEvaluationFailureKind kind, String message) async {
    final FallbackEvaluationFailure failure = FallbackEvaluationFailure(
      kind: kind,
      message: message,
    );
    await _recordState(
      newState: kind == FallbackEvaluationFailureKind.noCandidate
          ? StoredFallbackStrategyStateKind.noCandidate
          : StoredFallbackStrategyStateKind.rejected,
      failureKind: kind.name,
      failureReason: message,
    );
    cacheInvalidationBus?.publish(FallbackRejected(
      occurredAt: _clock(),
      scopeId: scopeId,
      failureKind: kind.name,
      reason: message,
    ));
    return FallbackEvaluationOutcome.rejected(failure: failure);
  }

  Future<void> _recordState({
    required StoredFallbackStrategyStateKind newState,
    String? selectedCandidateId,
    String? failureKind,
    String? failureReason,
  }) async {
    final StoredFallbackStrategyStateKind previousState = _state;
    _state = newState;
    await store.recordStrategyState(StoredFallbackStrategyStateRecord(
      scopeId: scopeId,
      state: newState,
      supported: failureKind == null,
      selectedCandidateId: selectedCandidateId,
      failureKind: failureKind,
      failureReason: failureReason,
      updatedAt: _clock(),
    ));
    cacheInvalidationBus?.publish(FallbackStrategyStateChanged(
      occurredAt: _clock(),
      scopeId: scopeId,
      previousState: previousState.name,
      newState: newState.name,
      adapterId: selectedCandidateId,
      failureKind: failureKind,
    ));
  }

  StoredFallbackAdapterCandidateRecord _storedCandidate(
      FallbackAdapterCandidate candidate) {
    return StoredFallbackAdapterCandidateRecord(
      id: candidate.id.value,
      displayName: candidate.adapter.displayName,
      priority: candidate.priority,
      declaredCapabilities: <String, String>{
        for (final PlaybackCapability capability in PlaybackCapability.values)
          capability.name:
              candidate.capabilities.statusOf(capability).isSupported
                  ? 'supported'
                  : candidate.capabilities.statusOf(capability).reason ??
                      'unsupported',
      },
      registeredAt: _clock(),
    );
  }

  Map<PlaybackCapability, CapabilityStatus> _hiddenCapabilities(
      PlaybackCapabilityMatrix fallbackCapabilities) {
    return <PlaybackCapability, CapabilityStatus>{
      for (final PlaybackCapability capability in PlaybackCapability.values)
        if (!fallbackCapabilities.supports(capability))
          capability: fallbackCapabilities.statusOf(capability),
    };
  }

  static bool _isFallbackCompatible(FallbackFailure failure) {
    return switch (failure.kind) {
      FallbackFailureKind.loadFailure ||
      FallbackFailureKind.unsupportedCodec ||
      FallbackFailureKind.unsupportedContainer ||
      FallbackFailureKind.adapterCrashed =>
        true,
      FallbackFailureKind.incompatibleFailure => false,
    };
  }
}

DateTime _defaultClock() => DateTime.now().toUtc();
