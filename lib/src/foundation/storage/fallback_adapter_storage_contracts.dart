enum StoredFallbackStrategyStateKind {
  disabled,
  evaluating,
  selected,
  rejected,
  noCandidate,
}

final class StoredFallbackAdapterCandidateRecord {
  StoredFallbackAdapterCandidateRecord({
    required this.id,
    required this.displayName,
    required this.priority,
    required Map<String, String> declaredCapabilities,
    required this.registeredAt,
  })  : assert(id != '', 'Fallback adapter id must not be empty.'),
        assert(displayName != '',
            'Fallback adapter display name must not be empty.'),
        assert(priority >= 0, 'Fallback adapter priority must not be negative.'),
        declaredCapabilities =
            Map<String, String>.unmodifiable(declaredCapabilities);

  final String id;
  final String displayName;
  final int priority;
  final Map<String, String> declaredCapabilities;
  final DateTime registeredAt;
}

final class StoredActiveFallbackConfigurationRecord {
  const StoredActiveFallbackConfigurationRecord({
    required this.scopeId,
    required this.enabled,
    required this.updatedAt,
    this.selectedCandidateId,
    this.selectedAt,
  })  : assert(scopeId != '', 'Fallback scope id must not be empty.'),
        assert(selectedCandidateId == null || selectedCandidateId != '',
            'Selected fallback candidate id must not be empty.');

  final String scopeId;
  final bool enabled;
  final String? selectedCandidateId;
  final DateTime? selectedAt;
  final DateTime updatedAt;
}

final class StoredFallbackSelectionHistoryRecord {
  StoredFallbackSelectionHistoryRecord({
    required this.id,
    required this.scopeId,
    required this.candidateId,
    required this.sourceKind,
    required this.failureKind,
    required this.reason,
    required Map<String, String> hiddenCapabilities,
    required this.selectedAt,
  })  : assert(id != '', 'Fallback selection history id must not be empty.'),
        assert(scopeId != '', 'Fallback selection scope id must not be empty.'),
        assert(candidateId != '', 'Fallback candidate id must not be empty.'),
        assert(sourceKind != '', 'Fallback source kind must not be empty.'),
        assert(failureKind != '', 'Fallback failure kind must not be empty.'),
        assert(reason != '', 'Fallback selection reason must not be empty.'),
        hiddenCapabilities = Map<String, String>.unmodifiable(hiddenCapabilities);

  final String id;
  final String scopeId;
  final String candidateId;
  final String sourceKind;
  final String failureKind;
  final String reason;
  final Map<String, String> hiddenCapabilities;
  final DateTime selectedAt;
}

final class StoredFallbackStrategyStateRecord {
  const StoredFallbackStrategyStateRecord({
    required this.scopeId,
    required this.state,
    required this.supported,
    required this.updatedAt,
    this.selectedCandidateId,
    this.failureKind,
    this.failureReason,
  })  : assert(scopeId != '', 'Fallback strategy scope id must not be empty.'),
        assert(selectedCandidateId == null || selectedCandidateId != '',
            'Selected fallback candidate id must not be empty.'),
        assert(failureKind == null || failureKind != '',
            'Fallback failure kind must not be empty.'),
        assert(failureReason == null || failureReason != '',
            'Fallback failure reason must not be empty.');

  final String scopeId;
  final StoredFallbackStrategyStateKind state;
  final bool supported;
  final String? selectedCandidateId;
  final String? failureKind;
  final String? failureReason;
  final DateTime updatedAt;
}

abstract interface class FallbackAdapterStore {
  Future<StoredFallbackAdapterCandidateRecord> storeCandidate(
      StoredFallbackAdapterCandidateRecord candidate);

  Future<StoredFallbackAdapterCandidateRecord?> findCandidateById(
      String candidateId);

  Future<List<StoredFallbackAdapterCandidateRecord>> listCandidates();

  Future<bool> removeCandidate(String candidateId);

  Future<void> setActiveConfiguration(
      StoredActiveFallbackConfigurationRecord configuration);

  Future<StoredActiveFallbackConfigurationRecord?> activeConfiguration(
      String scopeId);

  Future<void> recordSelection(StoredFallbackSelectionHistoryRecord selection);

  Future<List<StoredFallbackSelectionHistoryRecord>> selectionHistory(
      String scopeId,
      {int limit = 20});

  Future<void> recordStrategyState(StoredFallbackStrategyStateRecord state);

  Future<StoredFallbackStrategyStateRecord?> latestStrategyState(String scopeId);
}

final class DeterministicFallbackAdapterStore implements FallbackAdapterStore {
  DeterministicFallbackAdapterStore({
    Iterable<StoredFallbackAdapterCandidateRecord> seedCandidates =
        const <StoredFallbackAdapterCandidateRecord>[],
    Iterable<StoredActiveFallbackConfigurationRecord> seedConfigurations =
        const <StoredActiveFallbackConfigurationRecord>[],
    Iterable<StoredFallbackSelectionHistoryRecord> seedSelectionHistory =
        const <StoredFallbackSelectionHistoryRecord>[],
    Iterable<StoredFallbackStrategyStateRecord> seedStrategyStates =
        const <StoredFallbackStrategyStateRecord>[],
  }) {
    for (final StoredFallbackAdapterCandidateRecord candidate
        in seedCandidates) {
      _candidatesById[candidate.id] = candidate;
    }
    for (final StoredActiveFallbackConfigurationRecord configuration
        in seedConfigurations) {
      _configurationsByScope[configuration.scopeId] = configuration;
    }
    for (final StoredFallbackSelectionHistoryRecord selection
        in seedSelectionHistory) {
      _historyById[selection.id] = selection;
    }
    for (final StoredFallbackStrategyStateRecord state in seedStrategyStates) {
      _latestStateByScope[state.scopeId] = state;
    }
  }

  final Map<String, StoredFallbackAdapterCandidateRecord> _candidatesById =
      <String, StoredFallbackAdapterCandidateRecord>{};
  final Map<String, StoredActiveFallbackConfigurationRecord>
      _configurationsByScope =
      <String, StoredActiveFallbackConfigurationRecord>{};
  final Map<String, StoredFallbackSelectionHistoryRecord> _historyById =
      <String, StoredFallbackSelectionHistoryRecord>{};
  final Map<String, StoredFallbackStrategyStateRecord> _latestStateByScope =
      <String, StoredFallbackStrategyStateRecord>{};

  @override
  Future<StoredActiveFallbackConfigurationRecord?> activeConfiguration(
      String scopeId) {
    return Future<StoredActiveFallbackConfigurationRecord?>.value(
        _configurationsByScope[scopeId]);
  }

  @override
  Future<StoredFallbackAdapterCandidateRecord?> findCandidateById(
      String candidateId) {
    return Future<StoredFallbackAdapterCandidateRecord?>.value(
        _candidatesById[candidateId]);
  }

  @override
  Future<StoredFallbackStrategyStateRecord?> latestStrategyState(
      String scopeId) {
    return Future<StoredFallbackStrategyStateRecord?>.value(
        _latestStateByScope[scopeId]);
  }

  @override
  Future<List<StoredFallbackAdapterCandidateRecord>> listCandidates() {
    return Future<List<StoredFallbackAdapterCandidateRecord>>.value(
      <StoredFallbackAdapterCandidateRecord>[..._candidatesById.values]
        ..sort((StoredFallbackAdapterCandidateRecord left,
                StoredFallbackAdapterCandidateRecord right) =>
            left.priority.compareTo(right.priority)),
    );
  }

  @override
  Future<void> recordSelection(StoredFallbackSelectionHistoryRecord selection) {
    _historyById[selection.id] = selection;
    return Future<void>.value();
  }

  @override
  Future<void> recordStrategyState(StoredFallbackStrategyStateRecord state) {
    _latestStateByScope[state.scopeId] = state;
    return Future<void>.value();
  }

  @override
  Future<bool> removeCandidate(String candidateId) {
    final bool removed = _candidatesById.remove(candidateId) != null;
    _configurationsByScope.removeWhere(
        (String scopeId, StoredActiveFallbackConfigurationRecord configuration) =>
            configuration.selectedCandidateId == candidateId);
    _latestStateByScope.removeWhere(
        (String scopeId, StoredFallbackStrategyStateRecord state) =>
            state.selectedCandidateId == candidateId);
    return Future<bool>.value(removed);
  }

  @override
  Future<List<StoredFallbackSelectionHistoryRecord>> selectionHistory(
      String scopeId,
      {int limit = 20}) {
    final List<StoredFallbackSelectionHistoryRecord> history =
        <StoredFallbackSelectionHistoryRecord>[
      for (final StoredFallbackSelectionHistoryRecord selection
          in _historyById.values)
        if (selection.scopeId == scopeId) selection,
    ]..sort((StoredFallbackSelectionHistoryRecord left,
            StoredFallbackSelectionHistoryRecord right) =>
        right.selectedAt.compareTo(left.selectedAt));
    return Future<List<StoredFallbackSelectionHistoryRecord>>.value(
        history.take(limit).toList(growable: false));
  }

  @override
  Future<void> setActiveConfiguration(
      StoredActiveFallbackConfigurationRecord configuration) {
    _configurationsByScope[configuration.scopeId] = configuration;
    return Future<void>.value();
  }

  @override
  Future<StoredFallbackAdapterCandidateRecord> storeCandidate(
      StoredFallbackAdapterCandidateRecord candidate) {
    _candidatesById[candidate.id] = candidate;
    return Future<StoredFallbackAdapterCandidateRecord>.value(candidate);
  }
}
